-- Etapa 6: comunidade, favoritos, equipe e recrutamento com moderacao auditada.

create type public.public_comment_status as enum ('visible', 'hidden', 'removed');
create type public.comment_moderation_action as enum ('hide', 'restore', 'remove');
create type public.comment_report_status as enum ('pending', 'reviewed', 'dismissed');
create type public.recruitment_opening_status as enum ('draft', 'published', 'closed');
create type public.recruitment_application_status as enum (
  'received', 'in_review', 'shortlisted', 'rejected', 'withdrawn'
);

create table public.public_comments (
  id uuid primary key default gen_random_uuid(),
  content_id uuid not null references public.content_items (id) on delete restrict,
  author_id uuid not null references public.profiles (id) on delete restrict,
  body text not null check (char_length(trim(body)) between 3 and 2000),
  status public.public_comment_status not null default 'visible',
  idempotency_key uuid not null,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  moderated_at timestamptz,
  moderated_by uuid references public.profiles (id) on delete restrict,
  moderation_reason text,
  removed_at timestamptz,
  constraint public_comments_idempotency unique (author_id, idempotency_key),
  constraint public_comments_moderation_together check (
    (moderated_at is null and moderated_by is null and moderation_reason is null)
    or
    (moderated_at is not null and moderated_by is not null
      and char_length(trim(moderation_reason)) between 3 and 1000)
  ),
  constraint public_comments_removed_consistent check (
    (status = 'removed') = (removed_at is not null)
  )
);

create index public_comments_listing_idx
  on public.public_comments (content_id, created_at desc, id desc)
  where status = 'visible';
create index public_comments_author_rate_idx
  on public.public_comments (author_id, created_at desc);

create trigger public_comments_set_updated_at
before update on public.public_comments
for each row execute function public.set_updated_at();

create table public.comment_moderation_history (
  id bigint generated always as identity primary key,
  comment_id uuid not null references public.public_comments (id) on delete restrict,
  action public.comment_moderation_action not null,
  from_status public.public_comment_status not null,
  to_status public.public_comment_status not null,
  moderator_id uuid not null references public.profiles (id) on delete restrict,
  reason text not null check (char_length(trim(reason)) between 3 and 1000),
  created_at timestamptz not null default statement_timestamp(),
  constraint comment_moderation_status_changed check (from_status <> to_status)
);
create index comment_moderation_history_comment_idx
  on public.comment_moderation_history (comment_id, created_at desc, id desc);

create trigger comment_moderation_history_immutable
before update or delete on public.comment_moderation_history
for each row execute function public.reject_immutable_change();

create table public.comment_reports (
  id uuid primary key default gen_random_uuid(),
  comment_id uuid not null references public.public_comments (id) on delete restrict,
  reporter_id uuid not null references public.profiles (id) on delete restrict,
  reason text not null check (char_length(trim(reason)) between 3 and 1000),
  status public.comment_report_status not null default 'pending',
  created_at timestamptz not null default statement_timestamp(),
  resolved_at timestamptz,
  resolved_by uuid references public.profiles (id) on delete restrict,
  resolution_note text,
  unique (comment_id, reporter_id),
  constraint comment_reports_resolution_together check (
    (status = 'pending' and resolved_at is null and resolved_by is null and resolution_note is null)
    or
    (status <> 'pending' and resolved_at is not null and resolved_by is not null
      and char_length(trim(resolution_note)) between 3 and 1000)
  )
);
create index comment_reports_queue_idx
  on public.comment_reports (status, created_at, id);

create table public.content_favorites (
  user_id uuid not null references public.profiles (id) on delete cascade,
  content_id uuid not null references public.content_items (id) on delete cascade,
  created_at timestamptz not null default statement_timestamp(),
  primary key (user_id, content_id)
);
create index content_favorites_user_idx
  on public.content_favorites (user_id, created_at desc, content_id);

create table public.team_areas (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 2 and 80),
  slug text not null unique check (
    slug = lower(slug) and slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'
  ),
  description text check (description is null or char_length(trim(description)) <= 500),
  position smallint not null check (position > 0),
  active boolean not null default true,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  unique (position)
);
create trigger team_areas_set_updated_at
before update on public.team_areas
for each row execute function public.set_updated_at();

create table public.team_members (
  id uuid primary key default gen_random_uuid(),
  area_id uuid not null references public.team_areas (id) on delete restrict,
  profile_id uuid references public.profiles (id) on delete set null,
  display_name text not null check (char_length(trim(display_name)) between 2 and 120),
  role_title text not null check (char_length(trim(role_title)) between 2 and 120),
  bio text check (bio is null or char_length(trim(bio)) <= 1000),
  photo_asset_id uuid references public.media_assets (id) on delete set null,
  public_contact text check (public_contact is null or char_length(trim(public_contact)) <= 200),
  position smallint not null check (position > 0),
  active boolean not null default true,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  archived_at timestamptz,
  unique (area_id, position),
  constraint team_members_active_consistent check (active = (archived_at is null))
);
create index team_members_public_idx
  on public.team_members (area_id, position) where active;
create trigger team_members_set_updated_at
before update on public.team_members
for each row execute function public.set_updated_at();

create table public.recruitment_openings (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(trim(title)) between 3 and 160),
  slug text not null unique check (
    slug = lower(slug) and slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'
  ),
  summary text not null check (char_length(trim(summary)) between 10 and 500),
  description text not null check (char_length(trim(description)) between 10 and 5000),
  requirements text not null check (char_length(trim(requirements)) between 10 and 5000),
  process text not null check (char_length(trim(process)) between 10 and 5000),
  contact_email text not null check (contact_email ~* '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'),
  status public.recruitment_opening_status not null default 'draft',
  applications_enabled boolean not null default false,
  retention_days integer not null default 180 check (retention_days between 30 and 730),
  published_at timestamptz,
  closes_at timestamptz,
  created_by uuid not null references public.profiles (id) on delete restrict,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint recruitment_opening_publication_consistent check (
    status <> 'published' or published_at is not null
  ),
  constraint recruitment_opening_period_valid check (
    closes_at is null or published_at is null or closes_at > published_at
  )
);
create index recruitment_openings_public_idx
  on public.recruitment_openings (published_at desc, id) where status = 'published';
create trigger recruitment_openings_set_updated_at
before update on public.recruitment_openings
for each row execute function public.set_updated_at();

create table public.recruitment_applications (
  id uuid primary key default gen_random_uuid(),
  opening_id uuid not null references public.recruitment_openings (id) on delete restrict,
  applicant_name text not null check (char_length(trim(applicant_name)) between 2 and 120),
  email text not null check (email = lower(trim(email)) and email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'),
  affiliation text not null check (char_length(trim(affiliation)) between 2 and 200),
  message text not null check (char_length(trim(message)) between 20 and 4000),
  consent_version text not null check (char_length(trim(consent_version)) between 3 and 40),
  consented_at timestamptz not null default statement_timestamp(),
  status public.recruitment_application_status not null default 'received',
  retention_expires_at timestamptz not null,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  reviewed_by uuid references public.profiles (id) on delete restrict,
  reviewed_at timestamptz,
  internal_note text check (internal_note is null or char_length(trim(internal_note)) <= 2000),
  constraint recruitment_application_review_together check (
    (reviewed_by is null) = (reviewed_at is null)
  )
);
create index recruitment_applications_private_queue_idx
  on public.recruitment_applications (status, created_at, id);
create index recruitment_applications_retention_idx
  on public.recruitment_applications (retention_expires_at);
create index recruitment_applications_email_rate_idx
  on public.recruitment_applications (email, created_at desc);
create trigger recruitment_applications_set_updated_at
before update on public.recruitment_applications
for each row execute function public.set_updated_at();

alter table public.public_comments enable row level security;
alter table public.comment_moderation_history enable row level security;
alter table public.comment_reports enable row level security;
alter table public.content_favorites enable row level security;
alter table public.team_areas enable row level security;
alter table public.team_members enable row level security;
alter table public.recruitment_openings enable row level security;
alter table public.recruitment_applications enable row level security;

-- Producoes visuais publicadas exigem, alem do texto alternativo, autoria/credito e licenca.
create or replace function public.assert_content_ready_for_publication(requested_content_id uuid)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  selected_content public.content_items;
begin
  perform public.assert_content_ready_for_submission(requested_content_id);
  select * into selected_content from public.content_items where id = requested_content_id;

  if nullif(trim(selected_content.seo_title), '') is null
    or nullif(trim(selected_content.seo_description), '') is null
    or selected_content.cover_asset_id is null
    or not exists (
      select 1 from public.media_assets ma
      where ma.id = selected_content.cover_asset_id
        and ma.bucket_id = 'content-public'
        and ma.purpose = 'cover'
        and ma.mime_type like 'image/%'
        and nullif(trim(ma.alt_text), '') is not null
        and ma.archived_at is null
    )
    or (
      selected_content.type = 'artwork'
      and not exists (
        select 1 from public.media_assets ma
        where ma.id = selected_content.cover_asset_id
          and nullif(trim(ma.title), '') is not null
          and nullif(trim(ma.credit), '') is not null
          and nullif(trim(ma.license), '') is not null
      )
    )
  then
    raise exception using errcode = '23514', message = 'content_missing_publication_requirements';
  end if;
end;
$$;

create function public.add_public_comment(
  requested_content_id uuid,
  requested_body text,
  requested_idempotency_key uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  existing_id uuid;
  created_id uuid;
begin
  if actor is null then
    raise exception using errcode = '42501', message = 'authentication_required';
  end if;
  if requested_idempotency_key is null
    or char_length(trim(requested_body)) not between 3 and 2000
  then
    raise exception using errcode = '22023', message = 'invalid_comment';
  end if;

  select pc.id into existing_id
  from public.public_comments pc
  where pc.author_id = actor and pc.idempotency_key = requested_idempotency_key;
  if existing_id is not null then
    return existing_id;
  end if;

  if not exists (
    select 1 from public.content_items ci
    where ci.id = requested_content_id
      and ci.status = 'published'
      and ci.visibility = 'public'
      and ci.deleted_at is null
      and ci.comments_enabled
  ) then
    raise exception using errcode = '42501', message = 'comments_not_available';
  end if;
  if (select count(*) from public.public_comments pc
      where pc.author_id = actor and pc.created_at >= statement_timestamp() - interval '10 minutes') >= 5
    or (select count(*) from public.public_comments pc
      where pc.author_id = actor and pc.created_at >= statement_timestamp() - interval '1 day') >= 30
  then
    raise exception using errcode = 'P0001', message = 'comment_rate_limit_exceeded';
  end if;
  if exists (
    select 1 from public.public_comments pc
    where pc.author_id = actor
      and pc.created_at >= statement_timestamp() - interval '1 hour'
      and lower(trim(pc.body)) = lower(trim(requested_body))
  ) then
    raise exception using errcode = '23505', message = 'duplicate_comment';
  end if;

  insert into public.public_comments (content_id, author_id, body, idempotency_key)
  values (requested_content_id, actor, trim(requested_body), requested_idempotency_key)
  returning id into created_id;
  return created_id;
end;
$$;

create function public.list_public_comments(
  requested_content_id uuid,
  before_created_at timestamptz default null,
  before_id uuid default null,
  page_size integer default 20
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with selected as (
    select pc.id, pc.body, pc.created_at, p.display_name as author_name
    from public.public_comments pc
    join public.profiles p on p.id = pc.author_id
    join public.content_items ci on ci.id = pc.content_id
    where pc.content_id = requested_content_id
      and pc.status = 'visible'
      and ci.status = 'published'
      and ci.visibility = 'public'
      and ci.deleted_at is null
      and (before_created_at is null or (pc.created_at, pc.id) < (before_created_at, before_id))
    order by pc.created_at desc, pc.id desc
    limit least(greatest(page_size, 1), 50) + 1
  ), paged as (
    select * from selected order by created_at desc, id desc
    limit least(greatest(page_size, 1), 50)
  )
  select jsonb_build_object(
    'items', coalesce((select jsonb_agg(jsonb_build_object(
      'id', id, 'body', body, 'createdAt', created_at, 'authorName', author_name
    ) order by created_at desc, id desc) from paged), '[]'::jsonb),
    'hasMore', (select count(*) from selected) > least(greatest(page_size, 1), 50)
  );
$$;

create function public.report_public_comment(requested_comment_id uuid, requested_reason text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  report_id uuid;
begin
  if actor is null then
    raise exception using errcode = '42501', message = 'authentication_required';
  end if;
  if char_length(trim(requested_reason)) not between 3 and 1000 then
    raise exception using errcode = '22023', message = 'report_reason_required';
  end if;
  if (select count(*) from public.comment_reports cr
      where cr.reporter_id = actor and cr.created_at >= statement_timestamp() - interval '1 hour') >= 5
  then
    raise exception using errcode = 'P0001', message = 'report_rate_limit_exceeded';
  end if;
  if not exists (
    select 1 from public.public_comments pc
    join public.content_items ci on ci.id = pc.content_id
    where pc.id = requested_comment_id and pc.status = 'visible'
      and ci.status = 'published' and ci.visibility = 'public' and ci.deleted_at is null
  ) then
    raise exception using errcode = 'P0002', message = 'comment_not_available';
  end if;

  insert into public.comment_reports (comment_id, reporter_id, reason)
  values (requested_comment_id, actor, trim(requested_reason))
  on conflict (comment_id, reporter_id) do update
    set reason = excluded.reason
  returning id into report_id;
  return report_id;
end;
$$;

create function public.moderate_public_comment(
  requested_comment_id uuid,
  requested_action public.comment_moderation_action,
  requested_reason text
)
returns public.public_comment_status
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  selected_comment public.public_comments;
  target_status public.public_comment_status;
begin
  if actor is null or not public.has_any_role(array['editor', 'diretor']::public.app_role[]) then
    raise exception using errcode = '42501', message = 'insufficient_privilege';
  end if;
  if char_length(trim(requested_reason)) not between 3 and 1000 then
    raise exception using errcode = '22023', message = 'moderation_reason_required';
  end if;
  select * into selected_comment from public.public_comments
  where id = requested_comment_id for update;
  if selected_comment.id is null then
    raise exception using errcode = 'P0002', message = 'comment_not_found';
  end if;

  target_status := case requested_action
    when 'hide' then 'hidden'::public.public_comment_status
    when 'restore' then 'visible'::public.public_comment_status
    else 'removed'::public.public_comment_status
  end;
  if selected_comment.status = target_status
    or (requested_action = 'hide' and selected_comment.status <> 'visible')
    or (requested_action = 'restore' and selected_comment.status = 'visible')
  then
    raise exception using errcode = '23514', message = 'invalid_moderation_transition';
  end if;

  update public.public_comments
  set status = target_status,
      moderated_at = statement_timestamp(),
      moderated_by = actor,
      moderation_reason = trim(requested_reason),
      removed_at = case when target_status = 'removed' then statement_timestamp() else null end
  where id = requested_comment_id;

  insert into public.comment_moderation_history (
    comment_id, action, from_status, to_status, moderator_id, reason
  ) values (
    requested_comment_id, requested_action, selected_comment.status, target_status, actor,
    trim(requested_reason)
  );
  update public.comment_reports
  set status = 'reviewed', resolved_at = statement_timestamp(), resolved_by = actor,
      resolution_note = trim(requested_reason)
  where comment_id = requested_comment_id and status = 'pending';
  perform public.write_audit_log(
    actor, 'community.comment_moderated', 'public_comments', requested_comment_id::text,
    trim(requested_reason), jsonb_build_object('status', selected_comment.status),
    jsonb_build_object('status', target_status, 'action', requested_action)
  );
  return target_status;
end;
$$;

create function public.set_content_favorite(requested_content_id uuid, requested_favorite boolean)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare actor uuid := auth.uid();
begin
  if actor is null then
    raise exception using errcode = '42501', message = 'authentication_required';
  end if;
  if not exists (
    select 1 from public.content_items ci where ci.id = requested_content_id
      and ci.status = 'published' and ci.visibility = 'public' and ci.deleted_at is null
  ) then
    raise exception using errcode = 'P0002', message = 'content_not_available';
  end if;
  if requested_favorite then
    insert into public.content_favorites (user_id, content_id)
    values (actor, requested_content_id) on conflict do nothing;
  else
    delete from public.content_favorites
    where user_id = actor and content_id = requested_content_id;
  end if;
  return requested_favorite;
end;
$$;

create function public.list_own_favorites()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(public.public_content_card(ci) order by cf.created_at desc), '[]'::jsonb)
  from public.content_favorites cf
  join public.content_items ci on ci.id = cf.content_id
  where cf.user_id = auth.uid() and ci.status = 'published'
    and ci.visibility = 'public' and ci.deleted_at is null;
$$;

create function public.list_public_team()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', ta.id, 'name', ta.name, 'slug', ta.slug, 'description', ta.description,
    'members', coalesce((select jsonb_agg(jsonb_build_object(
      'id', tm.id, 'name', tm.display_name, 'roleTitle', tm.role_title,
      'bio', tm.bio, 'publicContact', tm.public_contact,
      'photo', case when ma.id is null then null else jsonb_build_object(
        'objectPath', ma.object_path, 'alt', ma.alt_text, 'credit', ma.credit
      ) end
    ) order by tm.position)
    from public.team_members tm
    left join public.media_assets ma on ma.id = tm.photo_asset_id
      and ma.bucket_id = 'content-public' and ma.archived_at is null
    where tm.area_id = ta.id and tm.active), '[]'::jsonb)
  ) order by ta.position), '[]'::jsonb)
  from public.team_areas ta where ta.active;
$$;

create function public.save_team_member(
  requested_member_id uuid,
  requested_area_id uuid,
  requested_name text,
  requested_role_title text,
  requested_bio text,
  requested_public_contact text,
  requested_position smallint
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  member_id uuid := coalesce(requested_member_id, gen_random_uuid());
  before_state jsonb;
begin
  if actor is null or not public.has_role('diretor') then
    raise exception using errcode = '42501', message = 'insufficient_privilege';
  end if;
  if char_length(trim(requested_name)) not between 2 and 120
    or char_length(trim(requested_role_title)) not between 2 and 120
    or requested_position is null or requested_position < 1
    or not exists (select 1 from public.team_areas where id = requested_area_id and active)
  then
    raise exception using errcode = '22023', message = 'invalid_team_member';
  end if;
  select to_jsonb(tm) into before_state from public.team_members tm where tm.id = member_id;
  update public.team_members set position = position + 1000
  where area_id = requested_area_id and position = requested_position and id <> member_id;
  insert into public.team_members (
    id, area_id, display_name, role_title, bio, public_contact, position, active, archived_at
  ) values (
    member_id, requested_area_id, trim(requested_name), trim(requested_role_title),
    nullif(trim(requested_bio), ''), nullif(trim(requested_public_contact), ''),
    requested_position, true, null
  ) on conflict (id) do update set
    area_id = excluded.area_id, display_name = excluded.display_name,
    role_title = excluded.role_title, bio = excluded.bio,
    public_contact = excluded.public_contact, position = excluded.position,
    active = true, archived_at = null;
  perform public.write_audit_log(
    actor, 'organization.team_member_saved', 'team_members', member_id::text,
    'Gestao da equipe', before_state,
    (select to_jsonb(tm) from public.team_members tm where tm.id = member_id)
  );
  return member_id;
end;
$$;

create function public.archive_team_member(requested_member_id uuid, requested_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare actor uuid := auth.uid(); before_state jsonb;
begin
  if actor is null or not public.has_role('diretor') then
    raise exception using errcode = '42501', message = 'insufficient_privilege';
  end if;
  if char_length(trim(requested_reason)) < 3 then
    raise exception using errcode = '22023', message = 'reason_required';
  end if;
  select to_jsonb(tm) into before_state from public.team_members tm
  where tm.id = requested_member_id and tm.active for update;
  if before_state is null then
    raise exception using errcode = 'P0002', message = 'active_team_member_not_found';
  end if;
  update public.team_members set active = false, archived_at = statement_timestamp()
  where id = requested_member_id;
  perform public.write_audit_log(
    actor, 'organization.team_member_archived', 'team_members', requested_member_id::text,
    trim(requested_reason), before_state,
    (select to_jsonb(tm) from public.team_members tm where tm.id = requested_member_id)
  );
end;
$$;

create function public.submit_recruitment_application(
  requested_opening_id uuid,
  requested_name text,
  requested_email text,
  requested_affiliation text,
  requested_message text,
  requested_consent_version text,
  anti_spam_field text default ''
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  selected_opening public.recruitment_openings;
  normalized_email text := lower(trim(requested_email));
  application_id uuid;
begin
  if nullif(trim(anti_spam_field), '') is not null then
    raise exception using errcode = '22023', message = 'invalid_application';
  end if;
  select * into selected_opening from public.recruitment_openings
  where id = requested_opening_id and status = 'published' and applications_enabled
    and (closes_at is null or closes_at > statement_timestamp());
  if selected_opening.id is null then
    raise exception using errcode = 'P0002', message = 'opening_not_available';
  end if;
  if char_length(trim(requested_name)) not between 2 and 120
    or normalized_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
    or char_length(trim(requested_affiliation)) not between 2 and 200
    or char_length(trim(requested_message)) not between 20 and 4000
    or char_length(trim(requested_consent_version)) not between 3 and 40
  then
    raise exception using errcode = '22023', message = 'invalid_application';
  end if;
  if (select count(*) from public.recruitment_applications ra
      where ra.email = normalized_email and ra.created_at >= statement_timestamp() - interval '1 day') >= 3
  then
    raise exception using errcode = 'P0001', message = 'application_rate_limit_exceeded';
  end if;
  insert into public.recruitment_applications (
    opening_id, applicant_name, email, affiliation, message, consent_version,
    retention_expires_at
  ) values (
    requested_opening_id, trim(requested_name), normalized_email,
    trim(requested_affiliation), trim(requested_message), trim(requested_consent_version),
    statement_timestamp() + make_interval(days => selected_opening.retention_days)
  ) returning id into application_id;
  return application_id;
end;
$$;

create function public.update_recruitment_application(
  requested_application_id uuid,
  requested_status public.recruitment_application_status,
  requested_note text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare actor uuid := auth.uid(); before_state jsonb;
begin
  if actor is null or not public.has_role('diretor') then
    raise exception using errcode = '42501', message = 'insufficient_privilege';
  end if;
  if char_length(trim(requested_note)) < 3 then
    raise exception using errcode = '22023', message = 'note_required';
  end if;
  select jsonb_build_object('status', ra.status, 'reviewed_by', ra.reviewed_by)
  into before_state from public.recruitment_applications ra
  where ra.id = requested_application_id for update;
  if before_state is null then
    raise exception using errcode = 'P0002', message = 'application_not_found';
  end if;
  update public.recruitment_applications
  set status = requested_status, internal_note = trim(requested_note),
      reviewed_by = actor, reviewed_at = statement_timestamp()
  where id = requested_application_id;
  perform public.write_audit_log(
    actor, 'organization.application_reviewed', 'recruitment_applications',
    requested_application_id::text, 'Revisao de candidatura', before_state,
    jsonb_build_object('status', requested_status, 'reviewed_by', actor)
  );
end;
$$;

create function public.purge_expired_recruitment_applications(batch_size integer default 100)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare removed_count integer;
begin
  if current_user not in ('postgres', 'service_role') then
    raise exception using errcode = '42501', message = 'insufficient_privilege';
  end if;
  with expired as (
    select id from public.recruitment_applications
    where retention_expires_at <= statement_timestamp()
    order by retention_expires_at limit least(greatest(batch_size, 1), 500)
    for update skip locked
  )
  delete from public.recruitment_applications ra using expired
  where ra.id = expired.id;
  get diagnostics removed_count = row_count;
  return removed_count;
end;
$$;

revoke all on public.public_comments, public.comment_moderation_history, public.comment_reports,
  public.content_favorites, public.team_areas, public.team_members,
  public.recruitment_openings, public.recruitment_applications from anon, authenticated;
grant select on public.public_comments to anon, authenticated;
grant select on public.comment_moderation_history, public.comment_reports to authenticated;
grant select on public.content_favorites to authenticated;
grant select on public.team_areas, public.team_members, public.recruitment_openings to anon, authenticated;
grant select on public.recruitment_applications to authenticated;

create policy public_comments_select_allowed on public.public_comments for select to anon, authenticated
using (
  (status = 'visible' and public.can_read_content(content_id))
  or author_id = auth.uid()
  or public.has_any_role(array['editor', 'diretor']::public.app_role[])
);
create policy comment_moderation_history_select_moderators
on public.comment_moderation_history for select to authenticated
using (public.has_any_role(array['editor', 'diretor']::public.app_role[]));
create policy comment_reports_select_moderators on public.comment_reports for select to authenticated
using (public.has_any_role(array['editor', 'diretor']::public.app_role[]));
create policy content_favorites_select_own on public.content_favorites for select to authenticated
using (user_id = auth.uid());
create policy team_areas_select_public on public.team_areas for select to anon, authenticated
using (active);
create policy team_areas_select_director on public.team_areas for select to authenticated
using (public.has_role('diretor'));
create policy team_members_select_public on public.team_members for select to anon, authenticated
using (active);
create policy team_members_select_director on public.team_members for select to authenticated
using (public.has_role('diretor'));
create policy recruitment_openings_select_public
on public.recruitment_openings for select to anon, authenticated
using (status = 'published');
create policy recruitment_openings_select_director
on public.recruitment_openings for select to authenticated
using (public.has_role('diretor'));
create policy recruitment_applications_select_director
on public.recruitment_applications for select to authenticated
using (public.has_role('diretor'));

revoke all on function public.add_public_comment(uuid, text, uuid) from public, anon;
revoke all on function public.list_public_comments(uuid, timestamptz, uuid, integer) from public;
revoke all on function public.report_public_comment(uuid, text) from public, anon;
revoke all on function public.moderate_public_comment(uuid, public.comment_moderation_action, text) from public, anon;
revoke all on function public.set_content_favorite(uuid, boolean) from public, anon;
revoke all on function public.list_own_favorites() from public, anon;
revoke all on function public.list_public_team() from public;
revoke all on function public.save_team_member(uuid, uuid, text, text, text, text, smallint) from public, anon;
revoke all on function public.archive_team_member(uuid, text) from public, anon;
revoke all on function public.submit_recruitment_application(uuid, text, text, text, text, text, text) from public;
revoke all on function public.update_recruitment_application(uuid, public.recruitment_application_status, text) from public, anon;
revoke all on function public.purge_expired_recruitment_applications(integer) from public, anon, authenticated;

grant execute on function public.add_public_comment(uuid, text, uuid) to authenticated;
grant execute on function public.list_public_comments(uuid, timestamptz, uuid, integer) to anon, authenticated;
grant execute on function public.report_public_comment(uuid, text) to authenticated;
grant execute on function public.moderate_public_comment(uuid, public.comment_moderation_action, text) to authenticated;
grant execute on function public.set_content_favorite(uuid, boolean) to authenticated;
grant execute on function public.list_own_favorites() to authenticated;
grant execute on function public.list_public_team() to anon, authenticated;
grant execute on function public.save_team_member(uuid, uuid, text, text, text, text, smallint) to authenticated;
grant execute on function public.archive_team_member(uuid, text) to authenticated;
grant execute on function public.submit_recruitment_application(uuid, text, text, text, text, text, text) to anon, authenticated;
grant execute on function public.update_recruitment_application(uuid, public.recruitment_application_status, text) to authenticated;
grant execute on function public.purge_expired_recruitment_applications(integer) to service_role;

comment on table public.public_comments is 'Comentarios publicos; escrita apenas por comandos protegidos.';
comment on table public.comment_moderation_history is 'Trilha append-only de toda acao de moderacao.';
comment on table public.recruitment_applications is 'Dados pessoais privados, sujeitos a expiracao por retencao.';
