-- Etapa 2: modelo relacional do nucleo editorial e trilhas imutaveis.
-- Autorizacao, RPCs e policies ficam na migration seguinte para manter a revisao legivel.

create type public.content_type as enum (
  'news',
  'weekly_article',
  'column',
  'poem',
  'essay',
  'short_story',
  'artwork',
  'notice'
);

create type public.editorial_status as enum (
  'draft',
  'submitted',
  'under_review',
  'changes_requested',
  'approved',
  'in_editing',
  'scheduled',
  'published',
  'rejected',
  'archived'
);

create type public.content_visibility as enum ('public', 'unlisted');
create type public.version_reason as enum (
  'submission',
  'resubmission',
  'review',
  'editing',
  'publication',
  'restoration'
);
create type public.asset_purpose as enum ('cover', 'inline_image', 'attachment', 'avatar');
create type public.outbox_status as enum ('pending', 'processing', 'succeeded', 'failed');

alter table public.profiles
  add column avatar_path text,
  add column course text check (course is null or char_length(trim(course)) between 2 and 120),
  add column affiliation text check (
    affiliation is null or char_length(trim(affiliation)) between 2 and 120
  );

create function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = statement_timestamp();
  return new;
end;
$$;

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 2 and 80),
  slug text not null check (slug = lower(slug) and slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  description text,
  archived_at timestamptz,
  created_by uuid not null references public.profiles (id) on delete restrict,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  unique (slug)
);

create trigger categories_set_updated_at
before update on public.categories
for each row execute function public.set_updated_at();

create table public.tags (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 2 and 60),
  slug text not null check (slug = lower(slug) and slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  archived_at timestamptz,
  created_by uuid not null references public.profiles (id) on delete restrict,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  unique (slug)
);

create trigger tags_set_updated_at
before update on public.tags
for each row execute function public.set_updated_at();

create table public.editions (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(trim(title)) between 2 and 160),
  slug text not null check (slug = lower(slug) and slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  summary text,
  issue_number integer check (issue_number is null or issue_number > 0),
  starts_on date,
  ends_on date,
  published_at timestamptz,
  archived_at timestamptz,
  created_by uuid not null references public.profiles (id) on delete restrict,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint editions_period_is_valid check (
    starts_on is null or ends_on is null or starts_on <= ends_on
  ),
  unique (slug),
  unique (issue_number)
);

create trigger editions_set_updated_at
before update on public.editions
for each row execute function public.set_updated_at();

create table public.media_assets (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles (id) on delete restrict,
  bucket_id text not null check (bucket_id in ('content-drafts', 'content-public')),
  object_path text not null,
  purpose public.asset_purpose not null,
  mime_type text not null,
  byte_size bigint not null check (byte_size > 0 and byte_size <= 10485760),
  title text,
  alt_text text,
  credit text,
  license text,
  created_at timestamptz not null default statement_timestamp(),
  archived_at timestamptz,
  constraint media_assets_path_owned check (
    split_part(object_path, '/', 1) = owner_id::text
  ),
  constraint media_assets_image_alt check (
    mime_type not like 'image/%' or nullif(trim(alt_text), '') is not null
  ),
  unique (bucket_id, object_path)
);

create table public.content_items (
  id uuid primary key default gen_random_uuid(),
  slug text not null check (slug = lower(slug) and slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  type public.content_type not null,
  title text not null check (char_length(trim(title)) between 3 and 180),
  subtitle text,
  summary text,
  body jsonb not null default '{}'::jsonb check (jsonb_typeof(body) = 'object'),
  status public.editorial_status not null default 'draft',
  visibility public.content_visibility not null default 'public',
  submitted_by uuid not null references public.profiles (id) on delete restrict,
  reviewer_id uuid references public.profiles (id) on delete restrict,
  editor_id uuid references public.profiles (id) on delete restrict,
  cover_asset_id uuid references public.media_assets (id) on delete set null,
  seo_title text check (seo_title is null or char_length(seo_title) <= 70),
  seo_description text check (seo_description is null or char_length(seo_description) <= 170),
  comments_enabled boolean not null default true,
  terms_version text,
  terms_accepted_at timestamptz,
  lock_version integer not null default 1 check (lock_version > 0),
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  submitted_at timestamptz,
  approved_at timestamptz,
  scheduled_at timestamptz,
  published_at timestamptz,
  archived_at timestamptz,
  deleted_at timestamptz,
  constraint content_submission_terms_together check (
    (terms_version is null) = (terms_accepted_at is null)
  ),
  constraint content_schedule_timestamp check (
    status <> 'scheduled' or scheduled_at is not null
  ),
  constraint content_publication_timestamp check (
    status <> 'published' or published_at is not null
  )
);

create unique index content_items_active_slug_uidx
  on public.content_items (slug)
  where deleted_at is null;
create index content_items_public_listing_idx
  on public.content_items (published_at desc, id)
  where status = 'published' and deleted_at is null;
create index content_items_submission_queue_idx
  on public.content_items (status, submitted_at, id)
  where status in ('submitted', 'under_review', 'changes_requested');
create index content_items_editor_queue_idx
  on public.content_items (status, updated_at, id)
  where status in ('approved', 'in_editing', 'scheduled', 'published');
create index content_items_submitted_by_idx on public.content_items (submitted_by, updated_at desc);
create index content_items_reviewer_id_idx on public.content_items (reviewer_id) where reviewer_id is not null;
create index content_items_editor_id_idx on public.content_items (editor_id) where editor_id is not null;

create function public.bump_content_lock_version()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = statement_timestamp();
  new.lock_version = old.lock_version + 1;
  return new;
end;
$$;

create trigger content_items_bump_lock_version
before update on public.content_items
for each row execute function public.bump_content_lock_version();

create table public.content_authors (
  content_id uuid not null references public.content_items (id) on delete cascade,
  position smallint not null check (position > 0),
  profile_id uuid references public.profiles (id) on delete restrict,
  display_name text,
  created_at timestamptz not null default statement_timestamp(),
  primary key (content_id, position),
  constraint content_authors_identity check (
    profile_id is not null or char_length(trim(display_name)) between 2 and 120
  )
);
create unique index content_authors_profile_uidx
  on public.content_authors (content_id, profile_id)
  where profile_id is not null;
create index content_authors_profile_idx on public.content_authors (profile_id) where profile_id is not null;

create table public.content_categories (
  content_id uuid not null references public.content_items (id) on delete cascade,
  category_id uuid not null references public.categories (id) on delete restrict,
  is_primary boolean not null default false,
  created_at timestamptz not null default statement_timestamp(),
  primary key (content_id, category_id)
);
create unique index content_categories_one_primary_uidx
  on public.content_categories (content_id)
  where is_primary;
create index content_categories_category_idx on public.content_categories (category_id, content_id);

create table public.content_tags (
  content_id uuid not null references public.content_items (id) on delete cascade,
  tag_id uuid not null references public.tags (id) on delete restrict,
  created_at timestamptz not null default statement_timestamp(),
  primary key (content_id, tag_id)
);
create index content_tags_tag_idx on public.content_tags (tag_id, content_id);

create table public.edition_items (
  edition_id uuid not null references public.editions (id) on delete cascade,
  content_id uuid not null references public.content_items (id) on delete cascade,
  position integer not null check (position > 0),
  created_at timestamptz not null default statement_timestamp(),
  primary key (edition_id, content_id),
  unique (edition_id, position)
);
create index edition_items_content_idx on public.edition_items (content_id);

create table public.content_slug_redirects (
  old_slug text primary key check (
    old_slug = lower(old_slug) and old_slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'
  ),
  content_id uuid not null references public.content_items (id) on delete cascade,
  created_at timestamptz not null default statement_timestamp()
);
create index content_slug_redirects_content_idx on public.content_slug_redirects (content_id);

create table public.content_versions (
  id uuid primary key default gen_random_uuid(),
  content_id uuid not null references public.content_items (id) on delete restrict,
  version_number integer not null check (version_number > 0),
  reason public.version_reason not null,
  snapshot jsonb not null check (jsonb_typeof(snapshot) = 'object'),
  created_by uuid not null references public.profiles (id) on delete restrict,
  created_at timestamptz not null default statement_timestamp(),
  unique (content_id, version_number)
);
create index content_versions_content_idx on public.content_versions (content_id, version_number desc);

create table public.editorial_status_history (
  id bigint generated always as identity primary key,
  content_id uuid not null references public.content_items (id) on delete restrict,
  from_status public.editorial_status not null,
  to_status public.editorial_status not null,
  changed_by uuid not null references public.profiles (id) on delete restrict,
  reason text not null check (char_length(trim(reason)) between 3 and 2000),
  created_at timestamptz not null default statement_timestamp(),
  constraint editorial_status_changed check (from_status <> to_status)
);
create index editorial_status_history_content_idx
  on public.editorial_status_history (content_id, created_at desc, id desc);

create table public.audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid references public.profiles (id) on delete restrict,
  action text not null check (action ~ '^[a-z]+(?:\.[a-z_]+)+$'),
  target_table text not null,
  target_id text not null,
  reason text,
  before_state jsonb,
  after_state jsonb,
  request_id text,
  created_at timestamptz not null default statement_timestamp()
);
create index audit_logs_actor_idx on public.audit_logs (actor_id, created_at desc);
create index audit_logs_target_idx on public.audit_logs (target_table, target_id, created_at desc);

create table public.outbox_events (
  id uuid primary key default gen_random_uuid(),
  event_type text not null check (event_type ~ '^[a-z]+(?:\.[a-z_]+)+$'),
  aggregate_type text not null,
  aggregate_id uuid not null,
  payload jsonb not null default '{}'::jsonb check (jsonb_typeof(payload) = 'object'),
  idempotency_key text not null unique,
  status public.outbox_status not null default 'pending',
  attempts integer not null default 0 check (attempts >= 0),
  next_attempt_at timestamptz not null default statement_timestamp(),
  last_error text,
  created_at timestamptz not null default statement_timestamp(),
  processed_at timestamptz
);
create index outbox_events_worker_idx
  on public.outbox_events (next_attempt_at, created_at)
  where status in ('pending', 'failed');

create function public.reject_immutable_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception using
    errcode = '55000',
    message = format('%I is append-only', tg_table_name);
end;
$$;

create trigger content_versions_immutable
before update or delete on public.content_versions
for each row execute function public.reject_immutable_change();
create trigger editorial_status_history_immutable
before update or delete on public.editorial_status_history
for each row execute function public.reject_immutable_change();
create trigger audit_logs_immutable
before update or delete on public.audit_logs
for each row execute function public.reject_immutable_change();

comment on table public.content_items is 'Raiz unificada do agregado editorial do Canarinho.';
comment on column public.content_items.lock_version is 'Controle otimista; toda alteracao incrementa este valor.';
comment on table public.content_versions is 'Snapshots editoriais imutaveis criados por comandos transacionais.';
comment on table public.editorial_status_history is 'Historico imutavel de toda transicao editorial.';
comment on table public.audit_logs is 'Auditoria append-only, restrita a Diretores para leitura.';
comment on table public.outbox_events is 'Eventos assincronos idempotentes, fora do caminho critico.';

alter table public.categories enable row level security;
alter table public.tags enable row level security;
alter table public.editions enable row level security;
alter table public.media_assets enable row level security;
alter table public.content_items enable row level security;
alter table public.content_authors enable row level security;
alter table public.content_categories enable row level security;
alter table public.content_tags enable row level security;
alter table public.edition_items enable row level security;
alter table public.content_slug_redirects enable row level security;
alter table public.content_versions enable row level security;
alter table public.editorial_status_history enable row level security;
alter table public.audit_logs enable row level security;
alter table public.outbox_events enable row level security;

revoke all on function public.set_updated_at() from public, anon, authenticated;
revoke all on function public.bump_content_lock_version() from public, anon, authenticated;
revoke all on function public.reject_immutable_change() from public, anon, authenticated;
