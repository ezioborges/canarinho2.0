-- Etapa 7: informes, notificacoes e newsletter resiliente e consentida.

create type public.notice_status as enum ('draft', 'published', 'archived');
create type public.notice_audience as enum (
  'general', 'students', 'team', 'authors', 'visitors'
);
create type public.newsletter_subscriber_status as enum (
  'pending', 'active', 'inactive', 'unsubscribed', 'bounced'
);
create type public.newsletter_campaign_status as enum (
  'draft', 'scheduled', 'sending', 'sent', 'failed', 'cancelled'
);
create type public.newsletter_segment as enum ('all', 'students', 'authors');
create type public.newsletter_delivery_status as enum (
  'queued', 'processing', 'sent', 'failed', 'skipped'
);
create type public.newsletter_export_status as enum (
  'pending', 'processing', 'ready', 'failed', 'expired'
);

create table public.communication_notices (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(trim(title)) between 3 and 180),
  slug text not null unique check (
    slug = lower(slug) and slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'
  ),
  summary text not null check (char_length(trim(summary)) between 10 and 500),
  body text not null check (char_length(trim(body)) between 10 and 10000),
  audience public.notice_audience not null default 'general',
  status public.notice_status not null default 'draft',
  comments_enabled boolean not null default false,
  pinned boolean not null default false,
  published_at timestamptz,
  expires_at timestamptz,
  archived_at timestamptz,
  created_by uuid not null references public.profiles (id) on delete restrict,
  updated_by uuid not null references public.profiles (id) on delete restrict,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint communication_notices_publication_consistent check (
    status <> 'published' or published_at is not null
  ),
  constraint communication_notices_archive_consistent check (
    (status = 'archived') = (archived_at is not null)
  ),
  constraint communication_notices_pin_consistent check (
    not pinned or status = 'published'
  ),
  constraint communication_notices_expiration_valid check (
    expires_at is null or published_at is null or expires_at > published_at
  )
);
create index communication_notices_public_idx
  on public.communication_notices (pinned desc, published_at desc, id)
  where status = 'published';
create index communication_notices_expiration_idx
  on public.communication_notices (expires_at)
  where status = 'published' and pinned and expires_at is not null;
create trigger communication_notices_set_updated_at
before update on public.communication_notices
for each row execute function public.set_updated_at();

create table public.notice_comments (
  id uuid primary key default gen_random_uuid(),
  notice_id uuid not null references public.communication_notices (id) on delete restrict,
  author_id uuid not null references public.profiles (id) on delete restrict,
  body text not null check (char_length(trim(body)) between 3 and 2000),
  idempotency_key uuid not null,
  created_at timestamptz not null default statement_timestamp(),
  unique (author_id, idempotency_key)
);
create index notice_comments_public_idx
  on public.notice_comments (notice_id, created_at desc, id desc);

create table public.user_notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles (id) on delete cascade,
  outbox_event_id uuid not null references public.outbox_events (id) on delete restrict,
  title text not null check (char_length(trim(title)) between 3 and 160),
  body text not null check (char_length(trim(body)) between 3 and 500),
  href text check (href is null or (href like '/%' and char_length(href) <= 500)),
  read_at timestamptz,
  created_at timestamptz not null default statement_timestamp(),
  unique (recipient_id, outbox_event_id)
);
create index user_notifications_inbox_idx
  on public.user_notifications (recipient_id, read_at, created_at desc, id);

create table public.newsletter_subscribers (
  id uuid primary key default gen_random_uuid(),
  email text not null unique check (
    email = lower(trim(email))
    and email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
  ),
  status public.newsletter_subscriber_status not null default 'pending',
  segment public.newsletter_segment not null default 'all',
  consent_version text not null check (char_length(trim(consent_version)) between 3 and 40),
  consented_at timestamptz not null default statement_timestamp(),
  consent_source text not null check (char_length(trim(consent_source)) between 2 and 80),
  confirmation_token_hash bytea,
  confirmation_expires_at timestamptz,
  confirmed_at timestamptz,
  unsubscribed_at timestamptz,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint newsletter_confirmation_together check (
    (confirmation_token_hash is null) = (confirmation_expires_at is null)
  ),
  constraint newsletter_active_confirmed check (
    status <> 'active' or confirmed_at is not null
  ),
  constraint newsletter_unsubscribed_consistent check (
    (status = 'unsubscribed') = (unsubscribed_at is not null)
  )
);
create index newsletter_subscribers_admin_idx
  on public.newsletter_subscribers (status, segment, created_at desc, id);
create trigger newsletter_subscribers_set_updated_at
before update on public.newsletter_subscribers
for each row execute function public.set_updated_at();

create table public.newsletter_campaigns (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 3 and 120),
  subject text not null check (char_length(trim(subject)) between 3 and 180),
  preview_text text check (preview_text is null or char_length(trim(preview_text)) <= 240),
  body_text text not null check (char_length(trim(body_text)) between 10 and 20000),
  segment public.newsletter_segment not null default 'all',
  status public.newsletter_campaign_status not null default 'draft',
  scheduled_at timestamptz,
  sending_started_at timestamptz,
  sent_at timestamptz,
  cancelled_at timestamptz,
  last_error text check (last_error is null or char_length(last_error) <= 500),
  created_by uuid not null references public.profiles (id) on delete restrict,
  updated_by uuid not null references public.profiles (id) on delete restrict,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint newsletter_campaign_schedule_consistent check (
    status <> 'scheduled' or scheduled_at is not null
  ),
  constraint newsletter_campaign_sent_consistent check (
    (status = 'sent') = (sent_at is not null)
  ),
  constraint newsletter_campaign_cancelled_consistent check (
    (status = 'cancelled') = (cancelled_at is not null)
  )
);
create index newsletter_campaigns_worker_idx
  on public.newsletter_campaigns (scheduled_at, created_at)
  where status in ('scheduled', 'sending', 'failed');
create trigger newsletter_campaigns_set_updated_at
before update on public.newsletter_campaigns
for each row execute function public.set_updated_at();

create table public.newsletter_deliveries (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.newsletter_campaigns (id) on delete restrict,
  subscriber_id uuid not null references public.newsletter_subscribers (id) on delete restrict,
  status public.newsletter_delivery_status not null default 'queued',
  attempts integer not null default 0 check (attempts between 0 and 10),
  next_attempt_at timestamptz not null default statement_timestamp(),
  idempotency_key text not null unique,
  unsubscribe_token_hash bytea,
  provider_message_id text,
  last_error text check (last_error is null or char_length(last_error) <= 500),
  sent_at timestamptz,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  unique (campaign_id, subscriber_id)
);
create index newsletter_deliveries_worker_idx
  on public.newsletter_deliveries (campaign_id, next_attempt_at, created_at)
  where status in ('queued', 'failed');
create trigger newsletter_deliveries_set_updated_at
before update on public.newsletter_deliveries
for each row execute function public.set_updated_at();

create table public.newsletter_exports (
  id uuid primary key default gen_random_uuid(),
  requested_by uuid not null references public.profiles (id) on delete restrict,
  status public.newsletter_export_status not null default 'pending',
  object_path text,
  row_count integer check (row_count is null or row_count >= 0),
  expires_at timestamptz,
  last_error text check (last_error is null or char_length(last_error) <= 500),
  created_at timestamptz not null default statement_timestamp(),
  completed_at timestamptz,
  constraint newsletter_export_ready_consistent check (
    status <> 'ready' or (object_path is not null and expires_at is not null and completed_at is not null)
  )
);
create index newsletter_exports_worker_idx
  on public.newsletter_exports (created_at, id) where status = 'pending';
create index newsletter_exports_expiration_idx
  on public.newsletter_exports (expires_at) where status = 'ready';

alter table public.communication_notices enable row level security;
alter table public.notice_comments enable row level security;
alter table public.user_notifications enable row level security;
alter table public.newsletter_subscribers enable row level security;
alter table public.newsletter_campaigns enable row level security;
alter table public.newsletter_deliveries enable row level security;
alter table public.newsletter_exports enable row level security;

create function public.save_communication_notice(
  requested_notice_id uuid,
  requested_title text,
  requested_slug text,
  requested_summary text,
  requested_body text,
  requested_audience public.notice_audience,
  requested_comments_enabled boolean,
  requested_expires_at timestamptz
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  notice_id uuid := coalesce(requested_notice_id, gen_random_uuid());
  before_state jsonb;
begin
  if actor is null or not public.has_any_role(array['conexoes', 'diretor']::public.app_role[]) then
    raise exception using errcode = '42501', message = 'insufficient_privilege';
  end if;
  if char_length(trim(requested_title)) not between 3 and 180
    or requested_slug <> lower(requested_slug)
    or requested_slug !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'
    or char_length(trim(requested_summary)) not between 10 and 500
    or char_length(trim(requested_body)) not between 10 and 10000
  then
    raise exception using errcode = '22023', message = 'invalid_notice';
  end if;
  select to_jsonb(n) into before_state
  from public.communication_notices n where n.id = notice_id for update;
  if before_state ->> 'status' = 'archived' then
    raise exception using errcode = '23514', message = 'archived_notice_is_immutable';
  end if;
  insert into public.communication_notices (
    id, title, slug, summary, body, audience, comments_enabled, expires_at,
    created_by, updated_by
  ) values (
    notice_id, trim(requested_title), requested_slug, trim(requested_summary),
    trim(requested_body), requested_audience, requested_comments_enabled,
    requested_expires_at, actor, actor
  ) on conflict (id) do update set
    title = excluded.title, slug = excluded.slug, summary = excluded.summary,
    body = excluded.body, audience = excluded.audience,
    comments_enabled = excluded.comments_enabled, expires_at = excluded.expires_at,
    updated_by = actor;
  perform public.write_audit_log(
    actor, 'communications.notice_saved', 'communication_notices', notice_id::text,
    'Gestao de informe', before_state,
    (select to_jsonb(n) from public.communication_notices n where n.id = notice_id)
  );
  return notice_id;
end;
$$;

create function public.change_communication_notice_status(
  requested_notice_id uuid,
  requested_action text,
  requested_reason text
)
returns public.notice_status
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  selected_notice public.communication_notices;
  target_status public.notice_status;
begin
  if actor is null or not public.has_any_role(array['conexoes', 'diretor']::public.app_role[]) then
    raise exception using errcode = '42501', message = 'insufficient_privilege';
  end if;
  if char_length(trim(requested_reason)) < 3 then
    raise exception using errcode = '22023', message = 'reason_required';
  end if;
  select * into selected_notice from public.communication_notices
  where id = requested_notice_id for update;
  if selected_notice.id is null then
    raise exception using errcode = 'P0002', message = 'notice_not_found';
  end if;
  target_status := case requested_action
    when 'publish' then 'published'::public.notice_status
    when 'archive' then 'archived'::public.notice_status
    else null
  end;
  if target_status is null
    or selected_notice.status = target_status
    or selected_notice.status = 'archived'
  then
    raise exception using errcode = '23514', message = 'invalid_notice_transition';
  end if;
  update public.communication_notices set
    status = target_status,
    published_at = case when target_status = 'published'
      then coalesce(published_at, statement_timestamp()) else published_at end,
    archived_at = case when target_status = 'archived' then statement_timestamp() else null end,
    pinned = case when target_status = 'archived' then false else pinned end,
    updated_by = actor
  where id = requested_notice_id;
  perform public.write_audit_log(
    actor, 'communications.notice_status_changed', 'communication_notices',
    requested_notice_id::text, trim(requested_reason),
    jsonb_build_object('status', selected_notice.status, 'pinned', selected_notice.pinned),
    jsonb_build_object('status', target_status, 'pinned',
      case when target_status = 'archived' then false else selected_notice.pinned end)
  );
  return target_status;
end;
$$;

create function public.set_communication_notice_pinned(
  requested_notice_id uuid,
  requested_pinned boolean,
  requested_reason text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare actor uuid := auth.uid(); selected_notice public.communication_notices;
begin
  if actor is null or not public.has_any_role(array['conexoes', 'diretor']::public.app_role[]) then
    raise exception using errcode = '42501', message = 'insufficient_privilege';
  end if;
  if char_length(trim(requested_reason)) < 3 then
    raise exception using errcode = '22023', message = 'reason_required';
  end if;
  select * into selected_notice from public.communication_notices
  where id = requested_notice_id for update;
  if selected_notice.id is null or selected_notice.status <> 'published'
    or (requested_pinned and selected_notice.expires_at <= statement_timestamp())
  then
    raise exception using errcode = '23514', message = 'notice_cannot_be_pinned';
  end if;
  update public.communication_notices
  set pinned = requested_pinned, updated_by = actor where id = requested_notice_id;
  perform public.write_audit_log(
    actor, 'communications.notice_pin_changed', 'communication_notices',
    requested_notice_id::text, trim(requested_reason),
    jsonb_build_object('pinned', selected_notice.pinned),
    jsonb_build_object('pinned', requested_pinned)
  );
  return requested_pinned;
end;
$$;

create function public.expire_communication_notice_highlights(batch_size integer default 100)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare changed_count integer;
begin
  with expired as (
    select id from public.communication_notices
    where status = 'published' and pinned and expires_at <= statement_timestamp()
    order by expires_at limit least(greatest(batch_size, 1), 500)
    for update skip locked
  )
  update public.communication_notices n set pinned = false
  from expired where n.id = expired.id;
  get diagnostics changed_count = row_count;
  return changed_count;
end;
$$;

create function public.add_notice_comment(
  requested_notice_id uuid,
  requested_body text,
  requested_idempotency_key uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare actor uuid := auth.uid(); comment_id uuid;
begin
  if actor is null then
    raise exception using errcode = '42501', message = 'authentication_required';
  end if;
  select id into comment_id from public.notice_comments
  where author_id = actor and idempotency_key = requested_idempotency_key;
  if comment_id is not null then return comment_id; end if;
  if char_length(trim(requested_body)) not between 3 and 2000
    or not exists (
      select 1 from public.communication_notices n
      where n.id = requested_notice_id and n.status = 'published' and n.comments_enabled
    )
  then
    raise exception using errcode = '42501', message = 'notice_comments_not_available';
  end if;
  if (select count(*) from public.notice_comments nc
      where nc.author_id = actor
        and nc.created_at >= statement_timestamp() - interval '10 minutes') >= 5
  then
    raise exception using errcode = 'P0001', message = 'comment_rate_limit_exceeded';
  end if;
  insert into public.notice_comments (notice_id, author_id, body, idempotency_key)
  values (requested_notice_id, actor, trim(requested_body), requested_idempotency_key)
  returning id into comment_id;
  return comment_id;
end;
$$;

create function public.subscribe_newsletter(
  requested_email text,
  requested_consent_version text,
  requested_source text,
  anti_spam_field text default ''
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_email text := lower(trim(requested_email));
  raw_token text := encode(extensions.gen_random_bytes(32), 'hex');
  subscriber_id uuid;
begin
  if nullif(trim(anti_spam_field), '') is not null
    or normalized_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
    or char_length(trim(requested_consent_version)) not between 3 and 40
    or char_length(trim(requested_source)) not between 2 and 80
  then
    raise exception using errcode = '22023', message = 'invalid_subscription';
  end if;
  insert into public.newsletter_subscribers (
    email, status, consent_version, consented_at, consent_source,
    confirmation_token_hash, confirmation_expires_at, confirmed_at, unsubscribed_at
  ) values (
    normalized_email, 'pending', trim(requested_consent_version), statement_timestamp(),
    trim(requested_source), extensions.digest(raw_token, 'sha256'),
    statement_timestamp() + interval '24 hours', null, null
  ) on conflict (email) do update set
    status = case when newsletter_subscribers.status = 'active'
      then 'active'::public.newsletter_subscriber_status
      else 'pending'::public.newsletter_subscriber_status end,
    consent_version = excluded.consent_version,
    consented_at = excluded.consented_at,
    consent_source = excluded.consent_source,
    confirmation_token_hash = case when newsletter_subscribers.status = 'active'
      then null else excluded.confirmation_token_hash end,
    confirmation_expires_at = case when newsletter_subscribers.status = 'active'
      then null else excluded.confirmation_expires_at end,
    unsubscribed_at = null
  returning id into subscriber_id;

  if (select status from public.newsletter_subscribers where id = subscriber_id) = 'pending' then
    insert into public.outbox_events (
      event_type, aggregate_type, aggregate_id, payload, idempotency_key
    ) values (
      'newsletter.confirmation_requested', 'newsletter_subscriber', subscriber_id,
      jsonb_build_object('email', normalized_email, 'confirmation_token', raw_token),
      subscriber_id::text || ':' || encode(extensions.digest(raw_token, 'sha256'), 'hex') || ':confirmation'
    );
  end if;
  return 'pending_confirmation';
end;
$$;

create function public.confirm_newsletter_subscription(requested_token text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare subscriber_id uuid;
begin
  update public.newsletter_subscribers set
    status = 'active', confirmed_at = coalesce(confirmed_at, statement_timestamp()),
    confirmation_token_hash = null, confirmation_expires_at = null, unsubscribed_at = null
  where confirmation_token_hash = extensions.digest(requested_token, 'sha256')
    and confirmation_expires_at > statement_timestamp()
    and status = 'pending'
  returning id into subscriber_id;
  return subscriber_id is not null;
end;
$$;

create function public.unsubscribe_newsletter(requested_token text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare selected_subscriber_id uuid;
begin
  select d.subscriber_id into selected_subscriber_id
  from public.newsletter_deliveries d
  where d.unsubscribe_token_hash = extensions.digest(requested_token, 'sha256')
  order by d.created_at desc limit 1;
  if selected_subscriber_id is null then return false; end if;
  update public.newsletter_subscribers set
    status = 'unsubscribed', unsubscribed_at = statement_timestamp(),
    confirmation_token_hash = null, confirmation_expires_at = null
  where id = selected_subscriber_id;
  update public.newsletter_deliveries d set status = 'skipped',
    last_error = 'subscriber_unsubscribed'
  where d.subscriber_id = selected_subscriber_id
    and d.status in ('queued', 'failed');
  return true;
end;
$$;

create function public.set_newsletter_subscriber_inactive(
  requested_subscriber_id uuid,
  requested_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare actor uuid := auth.uid(); before_state jsonb;
begin
  if actor is null or not public.has_any_role(array['conexoes', 'diretor']::public.app_role[]) then
    raise exception using errcode = '42501', message = 'insufficient_privilege';
  end if;
  if char_length(trim(requested_reason)) < 3 then
    raise exception using errcode = '22023', message = 'reason_required';
  end if;
  select jsonb_build_object('status', s.status) into before_state
  from public.newsletter_subscribers s where s.id = requested_subscriber_id for update;
  if before_state is null then
    raise exception using errcode = 'P0002', message = 'subscriber_not_found';
  end if;
  update public.newsletter_subscribers set status = 'inactive', unsubscribed_at = null
  where id = requested_subscriber_id;
  update public.newsletter_deliveries set status = 'skipped', last_error = 'subscriber_inactive'
  where subscriber_id = requested_subscriber_id and status in ('queued', 'failed');
  perform public.write_audit_log(
    actor, 'communications.subscriber_inactivated', 'newsletter_subscribers',
    requested_subscriber_id::text, trim(requested_reason), before_state,
    jsonb_build_object('status', 'inactive')
  );
end;
$$;

create function public.save_newsletter_campaign(
  requested_campaign_id uuid,
  requested_name text,
  requested_subject text,
  requested_preview_text text,
  requested_body_text text,
  requested_segment public.newsletter_segment
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare actor uuid := auth.uid(); campaign_id uuid := coalesce(requested_campaign_id, gen_random_uuid()); before_state jsonb;
begin
  if actor is null or not public.has_any_role(array['conexoes', 'editor', 'diretor']::public.app_role[]) then
    raise exception using errcode = '42501', message = 'insufficient_privilege';
  end if;
  if char_length(trim(requested_name)) not between 3 and 120
    or char_length(trim(requested_subject)) not between 3 and 180
    or char_length(trim(requested_body_text)) not between 10 and 20000
  then
    raise exception using errcode = '22023', message = 'invalid_campaign';
  end if;
  select to_jsonb(c) into before_state from public.newsletter_campaigns c
  where c.id = campaign_id for update;
  if before_state is not null and before_state ->> 'status' <> 'draft' then
    raise exception using errcode = '23514', message = 'only_draft_campaign_is_editable';
  end if;
  insert into public.newsletter_campaigns (
    id, name, subject, preview_text, body_text, segment, created_by, updated_by
  ) values (
    campaign_id, trim(requested_name), trim(requested_subject),
    nullif(trim(requested_preview_text), ''), trim(requested_body_text),
    requested_segment, actor, actor
  ) on conflict (id) do update set
    name = excluded.name, subject = excluded.subject,
    preview_text = excluded.preview_text, body_text = excluded.body_text,
    segment = excluded.segment, updated_by = actor;
  perform public.write_audit_log(
    actor, 'communications.campaign_saved', 'newsletter_campaigns', campaign_id::text,
    'Gestao de campanha', before_state,
    jsonb_build_object('name', trim(requested_name), 'subject', trim(requested_subject),
      'segment', requested_segment)
  );
  return campaign_id;
end;
$$;

create function public.schedule_newsletter_campaign(
  requested_campaign_id uuid,
  requested_scheduled_at timestamptz,
  requested_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare actor uuid := auth.uid(); selected_campaign public.newsletter_campaigns;
begin
  if actor is null or not public.has_any_role(array['conexoes', 'editor', 'diretor']::public.app_role[]) then
    raise exception using errcode = '42501', message = 'insufficient_privilege';
  end if;
  if requested_scheduled_at < statement_timestamp()
    or char_length(trim(requested_reason)) < 3 then
    raise exception using errcode = '22023', message = 'invalid_campaign_schedule';
  end if;
  select * into selected_campaign from public.newsletter_campaigns
  where id = requested_campaign_id and status = 'draft' for update;
  if selected_campaign.id is null then
    raise exception using errcode = '23514', message = 'campaign_not_schedulable';
  end if;
  update public.newsletter_campaigns set status = 'scheduled',
    scheduled_at = requested_scheduled_at, updated_by = actor
  where id = requested_campaign_id;
  perform public.write_audit_log(
    actor, 'communications.campaign_scheduled', 'newsletter_campaigns',
    requested_campaign_id::text, trim(requested_reason),
    jsonb_build_object('status', selected_campaign.status),
    jsonb_build_object('status', 'scheduled', 'scheduled_at', requested_scheduled_at)
  );
end;
$$;

create function public.cancel_newsletter_campaign(
  requested_campaign_id uuid,
  requested_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare actor uuid := auth.uid(); previous_status public.newsletter_campaign_status;
begin
  if actor is null or not public.has_any_role(array['conexoes', 'editor', 'diretor']::public.app_role[]) then
    raise exception using errcode = '42501', message = 'insufficient_privilege';
  end if;
  if char_length(trim(requested_reason)) < 3 then
    raise exception using errcode = '22023', message = 'reason_required';
  end if;
  select status into previous_status from public.newsletter_campaigns
  where id = requested_campaign_id and status in ('draft', 'scheduled', 'sending', 'failed') for update;
  if previous_status is null then
    raise exception using errcode = '23514', message = 'campaign_not_cancellable';
  end if;
  update public.newsletter_campaigns set status = 'cancelled',
    cancelled_at = statement_timestamp(), updated_by = actor where id = requested_campaign_id;
  update public.newsletter_deliveries set status = 'skipped', last_error = 'campaign_cancelled'
  where campaign_id = requested_campaign_id and status in ('queued', 'failed');
  perform public.write_audit_log(
    actor, 'communications.campaign_cancelled', 'newsletter_campaigns',
    requested_campaign_id::text, trim(requested_reason),
    jsonb_build_object('status', previous_status), jsonb_build_object('status', 'cancelled')
  );
end;
$$;

create function public.retry_failed_newsletter_campaign(
  requested_campaign_id uuid,
  requested_reason text
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare actor uuid := auth.uid(); changed_count integer;
begin
  if actor is null or not public.has_any_role(array['conexoes', 'editor', 'diretor']::public.app_role[]) then
    raise exception using errcode = '42501', message = 'insufficient_privilege';
  end if;
  if char_length(trim(requested_reason)) < 3 then
    raise exception using errcode = '22023', message = 'reason_required';
  end if;
  if not exists (select 1 from public.newsletter_campaigns
    where id = requested_campaign_id and status in ('sending', 'failed')) then
    raise exception using errcode = '23514', message = 'campaign_not_retryable';
  end if;
  update public.newsletter_deliveries d set status = 'queued',
    next_attempt_at = statement_timestamp(), last_error = null
  where d.campaign_id = requested_campaign_id and d.status = 'failed'
    and d.attempts < 5 and exists (
      select 1 from public.newsletter_subscribers s
      where s.id = d.subscriber_id and s.status = 'active'
    );
  get diagnostics changed_count = row_count;
  update public.newsletter_campaigns set status = 'sending', last_error = null,
    updated_by = actor where id = requested_campaign_id;
  perform public.write_audit_log(
    actor, 'communications.campaign_retried', 'newsletter_campaigns',
    requested_campaign_id::text, trim(requested_reason), null,
    jsonb_build_object('deliveries_requeued', changed_count)
  );
  return changed_count;
end;
$$;

create function public.claim_newsletter_batch(
  requested_campaign_id uuid default null,
  batch_size integer default 50
)
returns table (
  delivery_id uuid,
  campaign_id uuid,
  subscriber_id uuid,
  email text,
  subject text,
  preview_text text,
  body_text text,
  idempotency_key text,
  unsubscribe_token text
)
language plpgsql
security definer
set search_path = ''
as $$
declare selected_campaign public.newsletter_campaigns;
begin
  select * into selected_campaign from public.newsletter_campaigns c
  where (requested_campaign_id is null or c.id = requested_campaign_id)
    and c.status in ('scheduled', 'sending', 'failed')
    and (c.status <> 'scheduled' or c.scheduled_at <= statement_timestamp())
  order by c.scheduled_at nulls first, c.created_at
  limit 1 for update skip locked;
  if selected_campaign.id is null then return; end if;

  insert into public.newsletter_deliveries (
    campaign_id, subscriber_id, idempotency_key
  )
  select selected_campaign.id, s.id,
    'newsletter:' || selected_campaign.id::text || ':' || s.id::text
  from public.newsletter_subscribers s
  where s.status = 'active'
    and (selected_campaign.segment = 'all' or s.segment = selected_campaign.segment)
  on conflict on constraint newsletter_deliveries_campaign_id_subscriber_id_key do nothing;

  update public.newsletter_deliveries d set status = 'skipped',
    last_error = 'subscriber_not_active'
  where d.campaign_id = selected_campaign.id and d.status in ('queued', 'failed')
    and not exists (select 1 from public.newsletter_subscribers s
      where s.id = d.subscriber_id and s.status = 'active');

  update public.newsletter_campaigns set status = 'sending',
    sending_started_at = coalesce(sending_started_at, statement_timestamp()), last_error = null
  where id = selected_campaign.id;

  return query
  with candidates as (
    select d.id, encode(extensions.gen_random_bytes(32), 'hex') as raw_token
    from public.newsletter_deliveries d
    join public.newsletter_subscribers s on s.id = d.subscriber_id and s.status = 'active'
    where d.campaign_id = selected_campaign.id
      and d.status in ('queued', 'failed') and d.attempts < 5
      and d.next_attempt_at <= statement_timestamp()
    order by d.created_at, d.id
    limit least(greatest(batch_size, 1), 200)
    for update of d skip locked
  ), claimed as (
    update public.newsletter_deliveries d set
      status = 'processing', attempts = attempts + 1,
      unsubscribe_token_hash = extensions.digest(c.raw_token, 'sha256')
    from candidates c where d.id = c.id
    returning d.*, c.raw_token
  )
  select c.id, c.campaign_id, c.subscriber_id, s.email,
    selected_campaign.subject, selected_campaign.preview_text,
    selected_campaign.body_text, c.idempotency_key, c.raw_token
  from claimed c join public.newsletter_subscribers s on s.id = c.subscriber_id;
end;
$$;

create function public.record_newsletter_delivery(
  requested_delivery_id uuid,
  requested_succeeded boolean,
  requested_provider_message_id text,
  requested_error text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare selected_delivery public.newsletter_deliveries; remaining integer; permanent_failures integer;
begin
  select * into selected_delivery from public.newsletter_deliveries
  where id = requested_delivery_id and status = 'processing' for update;
  if selected_delivery.id is null then return; end if;
  update public.newsletter_deliveries set
    status = case when requested_succeeded then 'sent'::public.newsletter_delivery_status
      else 'failed'::public.newsletter_delivery_status end,
    provider_message_id = case when requested_succeeded then requested_provider_message_id else null end,
    last_error = case when requested_succeeded then null
      else left(coalesce(requested_error, 'provider_error'), 500) end,
    sent_at = case when requested_succeeded then statement_timestamp() else null end,
    next_attempt_at = case when requested_succeeded then next_attempt_at
      else statement_timestamp() + make_interval(mins => least(60, (2 ^ attempts)::integer)) end
  where id = requested_delivery_id;
  select count(*) into remaining from public.newsletter_deliveries
  where campaign_id = selected_delivery.campaign_id
    and (status in ('queued', 'processing') or (status = 'failed' and attempts < 5));
  if remaining = 0 then
    select count(*) into permanent_failures from public.newsletter_deliveries
    where campaign_id = selected_delivery.campaign_id and status = 'failed';
    update public.newsletter_campaigns set
      status = case when permanent_failures > 0 then 'failed'::public.newsletter_campaign_status
        else 'sent'::public.newsletter_campaign_status end,
      sent_at = case when permanent_failures = 0 then statement_timestamp() else null end,
      last_error = case when permanent_failures > 0 then 'delivery_failures_remaining' else null end
    where id = selected_delivery.campaign_id;
  end if;
end;
$$;

create function public.claim_newsletter_confirmation_events(batch_size integer default 50)
returns table (event_id uuid, email text, confirmation_token text, idempotency_key text)
language sql
security definer
set search_path = ''
as $$
  with candidates as (
    select e.id from public.outbox_events e
    where e.event_type = 'newsletter.confirmation_requested'
      and e.status in ('pending', 'failed') and e.attempts < 5
      and e.next_attempt_at <= statement_timestamp()
    order by e.created_at limit least(greatest(batch_size, 1), 200)
    for update skip locked
  ), claimed as (
    update public.outbox_events e set status = 'processing', attempts = attempts + 1
    from candidates c where e.id = c.id returning e.*
  )
  select c.id, c.payload ->> 'email', c.payload ->> 'confirmation_token', c.idempotency_key
  from claimed c;
$$;

create function public.record_communication_outbox_event(
  requested_event_id uuid,
  requested_succeeded boolean,
  requested_error text
)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.outbox_events set
    status = case when requested_succeeded then 'succeeded'::public.outbox_status
      else 'failed'::public.outbox_status end,
    processed_at = case when requested_succeeded then statement_timestamp() else null end,
    last_error = case when requested_succeeded then null
      else left(coalesce(requested_error, 'worker_error'), 500) end,
    next_attempt_at = case when requested_succeeded then next_attempt_at
      else statement_timestamp() + make_interval(mins => least(60, (2 ^ attempts)::integer)) end
  where id = requested_event_id and status = 'processing';
$$;

create function public.process_editorial_notifications(batch_size integer default 100)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare processed_count integer;
begin
  with candidates as (
    select e.id, e.event_type, e.aggregate_id
    from public.outbox_events e
    where e.status in ('pending', 'failed')
      and e.event_type in (
        'content.submitted', 'review.comment_added', 'review.changes_requested',
        'content.approved', 'content.rejected', 'content.published'
      ) and e.next_attempt_at <= statement_timestamp()
    order by e.created_at limit least(greatest(batch_size, 1), 500)
    for update skip locked
  ), recipients as (
    select c.id event_id, ur.user_id recipient_id,
      'Nova submissao aguardando revisao'::text title,
      'Uma materia entrou na fila editorial.'::text body,
      '/admin/revisao/' || c.aggregate_id::text href
    from candidates c join public.user_roles ur on ur.role_code in ('revisor', 'diretor')
    where c.event_type = 'content.submitted'
    union all
    select c.id, ci.submitted_by,
      case c.event_type
        when 'review.comment_added' then 'Novo comentario editorial'
        when 'review.changes_requested' then 'Ajustes solicitados na sua submissao'
        when 'content.approved' then 'Sua submissao foi aprovada'
        when 'content.rejected' then 'Decisao editorial registrada'
        else 'Seu conteudo foi publicado'
      end,
      'Acompanhe a atualizacao e o historico na sua area.'::text,
      '/submissoes/' || c.aggregate_id::text
    from candidates c join public.content_items ci on ci.id = c.aggregate_id
    where c.event_type <> 'content.submitted'
  ), inserted as (
    insert into public.user_notifications (
      recipient_id, outbox_event_id, title, body, href
    ) select recipient_id, event_id, title, body, href from recipients
    on conflict (recipient_id, outbox_event_id) do nothing returning 1
  ), completed as (
    update public.outbox_events e set status = 'succeeded',
      processed_at = statement_timestamp(), last_error = null
    from candidates c where e.id = c.id returning e.id
  )
  select count(*) into processed_count from completed;
  return processed_count;
end;
$$;

create function public.mark_own_notification_read(requested_notification_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.user_notifications set read_at = coalesce(read_at, statement_timestamp())
  where id = requested_notification_id and recipient_id = auth.uid();
$$;

create function public.request_newsletter_export(requested_reason text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare actor uuid := auth.uid(); export_id uuid;
begin
  if actor is null or not public.has_role('diretor') then
    raise exception using errcode = '42501', message = 'insufficient_privilege';
  end if;
  if char_length(trim(requested_reason)) < 3 then
    raise exception using errcode = '22023', message = 'reason_required';
  end if;
  insert into public.newsletter_exports (requested_by) values (actor) returning id into export_id;
  perform public.write_audit_log(
    actor, 'communications.subscribers_export_requested', 'newsletter_exports',
    export_id::text, trim(requested_reason), null,
    jsonb_build_object('status', 'pending', 'expires_in_hours', 24)
  );
  return export_id;
end;
$$;

create function public.claim_newsletter_exports(batch_size integer default 5)
returns table (export_id uuid, requested_by uuid)
language sql
security definer
set search_path = ''
as $$
  with candidates as (
    select e.id from public.newsletter_exports e where e.status = 'pending'
    order by e.created_at limit least(greatest(batch_size, 1), 20)
    for update skip locked
  ), claimed as (
    update public.newsletter_exports e set status = 'processing'
    from candidates c where e.id = c.id returning e.id, e.requested_by
  ) select id, requested_by from claimed;
$$;

create function public.complete_newsletter_export(
  requested_export_id uuid,
  requested_succeeded boolean,
  requested_object_path text,
  requested_row_count integer,
  requested_error text
)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.newsletter_exports set
    status = case when requested_succeeded then 'ready'::public.newsletter_export_status
      else 'failed'::public.newsletter_export_status end,
    object_path = case when requested_succeeded then requested_object_path else null end,
    row_count = case when requested_succeeded then requested_row_count else null end,
    expires_at = case when requested_succeeded then statement_timestamp() + interval '24 hours' else null end,
    completed_at = statement_timestamp(),
    last_error = case when requested_succeeded then null
      else left(coalesce(requested_error, 'export_error'), 500) end
  where id = requested_export_id and status = 'processing';
$$;

create function public.expire_newsletter_exports(batch_size integer default 100)
returns table (export_id uuid, object_path text)
language sql
security definer
set search_path = ''
as $$
  with expired as (
    select e.id, e.object_path from public.newsletter_exports e
    where e.status = 'ready' and e.expires_at <= statement_timestamp()
    order by e.expires_at limit least(greatest(batch_size, 1), 500)
    for update skip locked
  ), updated as (
    update public.newsletter_exports e set status = 'expired'
    from expired x where e.id = x.id returning e.id, x.object_path
  ) select id, object_path from updated;
$$;

revoke all on public.communication_notices, public.notice_comments,
  public.user_notifications, public.newsletter_subscribers, public.newsletter_campaigns,
  public.newsletter_deliveries, public.newsletter_exports from anon, authenticated;
grant select on public.communication_notices, public.notice_comments to anon, authenticated;
grant select on public.user_notifications to authenticated;
grant select on public.newsletter_subscribers, public.newsletter_campaigns,
  public.newsletter_deliveries, public.newsletter_exports to authenticated;
grant select on public.user_roles, public.newsletter_subscribers,
  public.newsletter_exports to service_role;

create policy communication_notices_select_public on public.communication_notices
for select to anon, authenticated using (status = 'published');
create policy communication_notices_select_managers on public.communication_notices
for select to authenticated using (
  public.has_any_role(array['conexoes', 'diretor']::public.app_role[])
);
create policy notice_comments_select_public on public.notice_comments
for select to anon, authenticated using (
  exists (select 1 from public.communication_notices n
    where n.id = notice_id and n.status = 'published')
);
create policy user_notifications_select_own on public.user_notifications
for select to authenticated using (recipient_id = auth.uid());
create policy newsletter_subscribers_select_managers on public.newsletter_subscribers
for select to authenticated using (
  public.has_any_role(array['conexoes', 'diretor']::public.app_role[])
);
create policy newsletter_campaigns_select_managers on public.newsletter_campaigns
for select to authenticated using (
  public.has_any_role(array['conexoes', 'editor', 'diretor']::public.app_role[])
);
create policy newsletter_deliveries_select_managers on public.newsletter_deliveries
for select to authenticated using (
  public.has_any_role(array['conexoes', 'editor', 'diretor']::public.app_role[])
);
create policy newsletter_exports_select_own_director on public.newsletter_exports
for select to authenticated using (requested_by = auth.uid() and public.has_role('diretor'));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('newsletter-exports', 'newsletter-exports', false, 5242880, array['text/csv'])
on conflict (id) do update set public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

revoke all on function public.save_communication_notice(uuid, text, text, text, text, public.notice_audience, boolean, timestamptz) from public, anon;
revoke all on function public.change_communication_notice_status(uuid, text, text) from public, anon;
revoke all on function public.set_communication_notice_pinned(uuid, boolean, text) from public, anon;
revoke all on function public.expire_communication_notice_highlights(integer) from public, anon, authenticated;
revoke all on function public.add_notice_comment(uuid, text, uuid) from public, anon;
revoke all on function public.subscribe_newsletter(text, text, text, text) from public;
revoke all on function public.confirm_newsletter_subscription(text) from public;
revoke all on function public.unsubscribe_newsletter(text) from public;
revoke all on function public.set_newsletter_subscriber_inactive(uuid, text) from public, anon;
revoke all on function public.save_newsletter_campaign(uuid, text, text, text, text, public.newsletter_segment) from public, anon;
revoke all on function public.schedule_newsletter_campaign(uuid, timestamptz, text) from public, anon;
revoke all on function public.cancel_newsletter_campaign(uuid, text) from public, anon;
revoke all on function public.retry_failed_newsletter_campaign(uuid, text) from public, anon;
revoke all on function public.claim_newsletter_batch(uuid, integer) from public, anon, authenticated;
revoke all on function public.record_newsletter_delivery(uuid, boolean, text, text) from public, anon, authenticated;
revoke all on function public.claim_newsletter_confirmation_events(integer) from public, anon, authenticated;
revoke all on function public.record_communication_outbox_event(uuid, boolean, text) from public, anon, authenticated;
revoke all on function public.process_editorial_notifications(integer) from public, anon, authenticated;
revoke all on function public.mark_own_notification_read(uuid) from public, anon;
revoke all on function public.request_newsletter_export(text) from public, anon;
revoke all on function public.claim_newsletter_exports(integer) from public, anon, authenticated;
revoke all on function public.complete_newsletter_export(uuid, boolean, text, integer, text) from public, anon, authenticated;
revoke all on function public.expire_newsletter_exports(integer) from public, anon, authenticated;

grant execute on function public.save_communication_notice(uuid, text, text, text, text, public.notice_audience, boolean, timestamptz) to authenticated;
grant execute on function public.change_communication_notice_status(uuid, text, text) to authenticated;
grant execute on function public.set_communication_notice_pinned(uuid, boolean, text) to authenticated;
grant execute on function public.expire_communication_notice_highlights(integer) to service_role;
grant execute on function public.add_notice_comment(uuid, text, uuid) to authenticated;
grant execute on function public.subscribe_newsletter(text, text, text, text) to anon, authenticated;
grant execute on function public.confirm_newsletter_subscription(text) to anon, authenticated;
grant execute on function public.unsubscribe_newsletter(text) to anon, authenticated;
grant execute on function public.set_newsletter_subscriber_inactive(uuid, text) to authenticated;
grant execute on function public.save_newsletter_campaign(uuid, text, text, text, text, public.newsletter_segment) to authenticated;
grant execute on function public.schedule_newsletter_campaign(uuid, timestamptz, text) to authenticated;
grant execute on function public.cancel_newsletter_campaign(uuid, text) to authenticated;
grant execute on function public.retry_failed_newsletter_campaign(uuid, text) to authenticated;
grant execute on function public.claim_newsletter_batch(uuid, integer) to service_role;
grant execute on function public.record_newsletter_delivery(uuid, boolean, text, text) to service_role;
grant execute on function public.claim_newsletter_confirmation_events(integer) to service_role;
grant execute on function public.record_communication_outbox_event(uuid, boolean, text) to service_role;
grant execute on function public.process_editorial_notifications(integer) to service_role;
grant execute on function public.mark_own_notification_read(uuid) to authenticated;
grant execute on function public.request_newsletter_export(text) to authenticated;
grant execute on function public.claim_newsletter_exports(integer) to service_role;
grant execute on function public.complete_newsletter_export(uuid, boolean, text, integer, text) to service_role;
grant execute on function public.expire_newsletter_exports(integer) to service_role;

comment on table public.communication_notices is 'Informes independentes do fluxo editorial, geridos por Conexoes e Direcao.';
comment on table public.newsletter_subscribers is 'Consentimentos e estado atual; tokens sao armazenados somente como hash.';
comment on table public.newsletter_deliveries is 'Uma entrega idempotente por campanha e inscrito, com retry limitado.';
comment on table public.newsletter_exports is 'Exportacoes privadas, auditadas e validas por no maximo 24 horas.';
