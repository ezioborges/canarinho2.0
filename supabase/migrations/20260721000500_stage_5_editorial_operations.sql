-- Etapa 5: operacao editorial completa, versionamento controlado, agenda e curadoria.

create type public.editorial_actor_kind as enum ('user', 'system');

alter table public.content_items
  add column reading_time_minutes integer
    check (reading_time_minutes is null or reading_time_minutes between 1 and 240);

alter table public.content_versions
  alter column created_by drop not null,
  add column actor_kind public.editorial_actor_kind not null default 'user',
  add column actor_label text,
  add constraint content_versions_actor_is_identified check (
    (actor_kind = 'user' and created_by is not null and actor_label is null)
    or
    (actor_kind = 'system' and created_by is null and char_length(trim(actor_label)) >= 3)
  );

alter table public.editorial_status_history
  alter column changed_by drop not null,
  add column actor_kind public.editorial_actor_kind not null default 'user',
  add column actor_label text,
  add constraint editorial_history_actor_is_identified check (
    (actor_kind = 'user' and changed_by is not null and actor_label is null)
    or
    (actor_kind = 'system' and changed_by is null and char_length(trim(actor_label)) >= 3)
  );

create table public.editorial_comments (
  id uuid primary key default gen_random_uuid(),
  content_id uuid not null references public.content_items (id) on delete restrict,
  version_id uuid not null references public.content_versions (id) on delete restrict,
  author_id uuid not null references public.profiles (id) on delete restrict,
  body text not null check (char_length(trim(body)) between 3 and 4000),
  resolved_at timestamptz,
  resolved_by uuid references public.profiles (id) on delete restrict,
  created_at timestamptz not null default statement_timestamp(),
  constraint editorial_comment_resolution_together check (
    (resolved_at is null) = (resolved_by is null)
  )
);

create index editorial_comments_content_idx
  on public.editorial_comments (content_id, created_at, id);
create index editorial_comments_version_idx
  on public.editorial_comments (version_id, created_at, id);

alter table public.editorial_comments enable row level security;

revoke all on public.editorial_comments from anon, authenticated;
grant select on public.editorial_comments to authenticated;

create policy editorial_comments_select_allowed
on public.editorial_comments for select
to authenticated
using (public.can_read_content(content_id));

create or replace function public.get_own_submission(requested_content_id uuid)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select jsonb_build_object(
    'content', to_jsonb(ci) - 'deleted_at',
    'authors', coalesce((
      select jsonb_agg(to_jsonb(ca) order by ca.position)
      from public.content_authors ca where ca.content_id = ci.id
    ), '[]'::jsonb),
    'categories', coalesce((
      select jsonb_agg(to_jsonb(cc))
      from public.content_categories cc where cc.content_id = ci.id
    ), '[]'::jsonb),
    'tags', coalesce((
      select jsonb_agg(to_jsonb(ct))
      from public.content_tags ct where ct.content_id = ci.id
    ), '[]'::jsonb),
    'assets', coalesce((
      select jsonb_agg(to_jsonb(ma) order by cma.position)
      from public.content_media_assets cma
      join public.media_assets ma on ma.id = cma.asset_id
      where cma.content_id = ci.id and ma.archived_at is null
    ), '[]'::jsonb),
    'history', coalesce((
      select jsonb_agg(to_jsonb(esh) order by esh.created_at desc, esh.id desc)
      from public.editorial_status_history esh where esh.content_id = ci.id
    ), '[]'::jsonb),
    'comments', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', ec.id,
          'version_id', ec.version_id,
          'body', ec.body,
          'created_at', ec.created_at
        ) order by ec.created_at, ec.id
      )
      from public.editorial_comments ec where ec.content_id = ci.id
    ), '[]'::jsonb)
  )
  from public.content_items ci
  where ci.id = requested_content_id
    and ci.deleted_at is null;
$$;

-- A capa publicada precisa estar no bucket publico; uma URL privada nunca pode virar capa quebrada.
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

  select * into selected_content
  from public.content_items
  where id = requested_content_id;

  if nullif(trim(selected_content.seo_title), '') is null
    or nullif(trim(selected_content.seo_description), '') is null
    or selected_content.cover_asset_id is null
    or not exists (
      select 1
      from public.media_assets ma
      where ma.id = selected_content.cover_asset_id
        and ma.bucket_id = 'content-public'
        and ma.purpose = 'cover'
        and ma.mime_type like 'image/%'
        and nullif(trim(ma.alt_text), '') is not null
        and ma.archived_at is null
    )
  then
    raise exception using errcode = '23514', message = 'content_missing_publication_requirements';
  end if;
end;
$$;

create function public.add_editorial_comment(
  requested_content_id uuid,
  requested_version_id uuid,
  requested_body text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  selected_content public.content_items;
  comment_id uuid;
begin
  if actor is null then
    raise exception using errcode = '42501', message = 'authentication_required';
  end if;
  if char_length(trim(requested_body)) < 3 then
    raise exception using errcode = '22023', message = 'comment_required';
  end if;

  select * into selected_content
  from public.content_items
  where id = requested_content_id
  for update;

  if selected_content.id is null then
    raise exception using errcode = 'P0002', message = 'content_not_found';
  end if;
  if not (
    public.has_role('diretor')
    or (
      public.has_role('revisor')
      and selected_content.reviewer_id = actor
      and selected_content.status = 'under_review'
    )
  ) then
    raise exception using errcode = '42501', message = 'comment_not_allowed';
  end if;
  if not exists (
    select 1
    from public.content_versions cv
    where cv.id = requested_version_id
      and cv.content_id = requested_content_id
  ) then
    raise exception using errcode = '23503', message = 'version_does_not_belong_to_content';
  end if;

  insert into public.editorial_comments (content_id, version_id, author_id, body)
  values (requested_content_id, requested_version_id, actor, trim(requested_body))
  returning id into comment_id;

  insert into public.outbox_events (
    event_type, aggregate_type, aggregate_id, payload, idempotency_key
  ) values (
    'review.comment_added',
    'content',
    requested_content_id,
    jsonb_build_object(
      'content_id', requested_content_id,
      'version_id', requested_version_id,
      'comment_id', comment_id
    ),
    'review-comment:' || comment_id::text
  );

  return comment_id;
end;
$$;

create function public.save_editorial_content(
  requested_content_id uuid,
  expected_lock_version integer,
  requested_title text,
  requested_subtitle text,
  requested_summary text,
  requested_body jsonb,
  requested_primary_category_id uuid,
  requested_tag_ids uuid[],
  requested_cover_asset_id uuid,
  requested_seo_title text,
  requested_seo_description text,
  requested_reading_time_minutes integer,
  justification text
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  selected_content public.content_items;
  resulting_lock integer;
  was_published boolean;
begin
  if actor is null or not public.has_any_role(array['editor', 'diretor']::public.app_role[]) then
    raise exception using errcode = '42501', message = 'insufficient_privilege';
  end if;
  if char_length(trim(justification)) < 3 then
    raise exception using errcode = '22023', message = 'justification_required';
  end if;
  if char_length(trim(requested_title)) not between 3 and 180
    or jsonb_typeof(requested_body) <> 'object'
    or requested_body = '{}'::jsonb
    or requested_reading_time_minutes is null
    or requested_reading_time_minutes not between 1 and 240
  then
    raise exception using errcode = '22023', message = 'invalid_editorial_content';
  end if;
  if cardinality(coalesce(requested_tag_ids, '{}'::uuid[])) > 12 then
    raise exception using errcode = '22023', message = 'too_many_tags';
  end if;

  select * into selected_content
  from public.content_items
  where id = requested_content_id
  for update;

  if selected_content.id is null then
    raise exception using errcode = 'P0002', message = 'content_not_found';
  end if;
  if selected_content.lock_version <> expected_lock_version then
    raise exception using errcode = '40001', message = 'stale_content_version';
  end if;
  if selected_content.status not in ('in_editing', 'published') then
    raise exception using errcode = '42501', message = 'content_not_editable_by_editor';
  end if;
  if not public.has_role('diretor')
    and selected_content.status = 'in_editing'
    and selected_content.editor_id <> actor
  then
    raise exception using errcode = '42501', message = 'editor_is_not_responsible';
  end if;
  if requested_primary_category_id is not null and not exists (
    select 1 from public.categories c
    where c.id = requested_primary_category_id and c.archived_at is null
  ) then
    raise exception using errcode = '23503', message = 'category_not_available';
  end if;
  if exists (
    select 1
    from unnest(coalesce(requested_tag_ids, '{}'::uuid[])) requested_tag_id
    left join public.tags t on t.id = requested_tag_id and t.archived_at is null
    where t.id is null
  ) then
    raise exception using errcode = '23503', message = 'tag_not_available';
  end if;
  if requested_cover_asset_id is not null and not exists (
    select 1 from public.media_assets ma
    where ma.id = requested_cover_asset_id
      and ma.bucket_id = 'content-public'
      and ma.purpose = 'cover'
      and ma.mime_type like 'image/%'
      and nullif(trim(ma.alt_text), '') is not null
      and ma.archived_at is null
  ) then
    raise exception using errcode = '23503', message = 'cover_not_available';
  end if;

  was_published := selected_content.status = 'published';
  if was_published then
    -- Garante um ponto de retorno mesmo para publicacoes antigas sem snapshot inicial.
    perform public.create_content_version(requested_content_id, 'publication', actor);
  end if;

  update public.content_items
  set title = trim(requested_title),
      subtitle = nullif(trim(requested_subtitle), ''),
      summary = nullif(trim(requested_summary), ''),
      body = requested_body,
      cover_asset_id = requested_cover_asset_id,
      seo_title = nullif(trim(requested_seo_title), ''),
      seo_description = nullif(trim(requested_seo_description), ''),
      reading_time_minutes = requested_reading_time_minutes
  where id = requested_content_id
  returning lock_version into resulting_lock;

  delete from public.content_categories where content_id = requested_content_id;
  if requested_primary_category_id is not null then
    insert into public.content_categories (content_id, category_id, is_primary)
    values (requested_content_id, requested_primary_category_id, true);
  end if;

  delete from public.content_tags where content_id = requested_content_id;
  insert into public.content_tags (content_id, tag_id)
  select requested_content_id, requested_tag_id
  from unnest(coalesce(requested_tag_ids, '{}'::uuid[])) requested_tag_id
  group by requested_tag_id;

  perform public.create_content_version(requested_content_id, 'editing', actor);

  if was_published then
    insert into public.outbox_events (
      event_type, aggregate_type, aggregate_id, payload, idempotency_key
    ) values (
      'content.updated', 'content', requested_content_id,
      jsonb_build_object('content_id', requested_content_id, 'status', 'published'),
      requested_content_id::text || ':' || resulting_lock::text || ':content.updated'
    );
  end if;

  perform public.write_audit_log(
    actor,
    'editorial.content_edited',
    'content_items',
    requested_content_id::text,
    justification,
    jsonb_build_object('lock_version', selected_content.lock_version, 'status', selected_content.status),
    jsonb_build_object('lock_version', resulting_lock, 'status', selected_content.status)
  );

  return resulting_lock;
end;
$$;

create function public.restore_editorial_version(
  requested_content_id uuid,
  requested_version_id uuid,
  expected_lock_version integer,
  justification text
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  selected_content public.content_items;
  selected_snapshot jsonb;
  snapshot_content jsonb;
  resulting_lock integer;
begin
  if actor is null or not public.has_any_role(array['editor', 'diretor']::public.app_role[]) then
    raise exception using errcode = '42501', message = 'insufficient_privilege';
  end if;
  if char_length(trim(justification)) < 3 then
    raise exception using errcode = '22023', message = 'justification_required';
  end if;

  select * into selected_content
  from public.content_items
  where id = requested_content_id
  for update;

  if selected_content.id is null then
    raise exception using errcode = 'P0002', message = 'content_not_found';
  end if;
  if selected_content.lock_version <> expected_lock_version then
    raise exception using errcode = '40001', message = 'stale_content_version';
  end if;
  if selected_content.status <> 'in_editing' then
    raise exception using errcode = '42501', message = 'restoration_requires_editing_state';
  end if;
  if not public.has_role('diretor') and selected_content.editor_id <> actor then
    raise exception using errcode = '42501', message = 'editor_is_not_responsible';
  end if;

  select cv.snapshot into selected_snapshot
  from public.content_versions cv
  where cv.id = requested_version_id and cv.content_id = requested_content_id;

  if selected_snapshot is null then
    raise exception using errcode = 'P0002', message = 'version_not_found';
  end if;
  snapshot_content := selected_snapshot -> 'content';
  if jsonb_typeof(snapshot_content) <> 'object' then
    raise exception using errcode = '23514', message = 'invalid_version_snapshot';
  end if;

  perform public.create_content_version(requested_content_id, 'editing', actor);

  update public.content_items
  set title = snapshot_content ->> 'title',
      subtitle = snapshot_content ->> 'subtitle',
      summary = snapshot_content ->> 'summary',
      body = snapshot_content -> 'body',
      visibility = (snapshot_content ->> 'visibility')::public.content_visibility,
      cover_asset_id = nullif(snapshot_content ->> 'cover_asset_id', '')::uuid,
      seo_title = snapshot_content ->> 'seo_title',
      seo_description = snapshot_content ->> 'seo_description',
      comments_enabled = coalesce((snapshot_content ->> 'comments_enabled')::boolean, true),
      reading_time_minutes = coalesce(
        (snapshot_content ->> 'reading_time_minutes')::integer,
        reading_time_minutes
      )
  where id = requested_content_id
  returning lock_version into resulting_lock;

  delete from public.content_authors where content_id = requested_content_id;
  insert into public.content_authors (content_id, position, profile_id, display_name)
  select
    requested_content_id,
    (author ->> 'position')::smallint,
    nullif(author ->> 'profile_id', '')::uuid,
    author ->> 'display_name'
  from jsonb_array_elements(coalesce(selected_snapshot -> 'authors', '[]'::jsonb)) author;

  delete from public.content_categories where content_id = requested_content_id;
  insert into public.content_categories (content_id, category_id, is_primary)
  select
    requested_content_id,
    (category ->> 'category_id')::uuid,
    (category ->> 'is_primary')::boolean
  from jsonb_array_elements(coalesce(selected_snapshot -> 'categories', '[]'::jsonb)) category;

  delete from public.content_tags where content_id = requested_content_id;
  insert into public.content_tags (content_id, tag_id)
  select requested_content_id, (tag ->> 'tag_id')::uuid
  from jsonb_array_elements(coalesce(selected_snapshot -> 'tags', '[]'::jsonb)) tag;

  perform public.create_content_version(requested_content_id, 'restoration', actor);
  perform public.write_audit_log(
    actor,
    'editorial.version_restored',
    'content_items',
    requested_content_id::text,
    justification,
    jsonb_build_object('lock_version', selected_content.lock_version),
    jsonb_build_object('lock_version', resulting_lock, 'restored_version_id', requested_version_id)
  );

  return resulting_lock;
end;
$$;

create function public.set_primary_hero(
  requested_content_id uuid,
  justification text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  previous_content_id uuid;
  placement_id uuid;
begin
  if actor is null or not public.has_any_role(array['editor', 'diretor']::public.app_role[]) then
    raise exception using errcode = '42501', message = 'insufficient_privilege';
  end if;
  if char_length(trim(justification)) < 3 then
    raise exception using errcode = '22023', message = 'justification_required';
  end if;
  if not exists (
    select 1 from public.content_items ci
    where ci.id = requested_content_id and ci.status = 'published' and ci.deleted_at is null
  ) then
    raise exception using errcode = '23514', message = 'hero_must_be_published';
  end if;

  perform pg_advisory_xact_lock(hashtext('canarinho:primary-hero'));
  select cp.content_id into previous_content_id
  from public.content_placements cp
  where cp.slot = 'hero' and cp.position = 1
  for update;

  delete from public.content_placements where slot = 'hero' and position = 1;
  insert into public.content_placements (content_id, slot, position, created_by)
  values (requested_content_id, 'hero', 1, actor)
  returning id into placement_id;

  perform public.write_audit_log(
    actor,
    'editorial.hero_changed',
    'content_placements',
    placement_id::text,
    justification,
    jsonb_build_object('content_id', previous_content_id),
    jsonb_build_object('content_id', requested_content_id)
  );
  return placement_id;
end;
$$;

-- A transicao central e ampliada sem liberar update direto de status ao cliente.
create or replace function public.transition_editorial_content(
  requested_content_id uuid,
  requested_status public.editorial_status,
  expected_lock_version integer,
  justification text,
  requested_schedule timestamptz default null,
  director_exception boolean default false
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  selected_content public.content_items;
  resulting_lock integer;
  version_reason public.version_reason;
  event_type text;
  is_author boolean;
  is_responsible_reviewer boolean;
  is_editor boolean;
  is_director boolean;
begin
  if actor is null then
    raise exception using errcode = '42501', message = 'authentication_required';
  end if;
  if char_length(trim(justification)) < 3 then
    raise exception using errcode = '22023', message = 'justification_required';
  end if;

  select * into selected_content
  from public.content_items
  where id = requested_content_id
  for update;

  if selected_content.id is null then
    raise exception using errcode = 'P0002', message = 'content_not_found';
  end if;
  if selected_content.lock_version <> expected_lock_version then
    raise exception using errcode = '40001', message = 'stale_content_version';
  end if;
  if selected_content.status = requested_status then
    raise exception using errcode = '23514', message = 'status_must_change';
  end if;

  is_author := selected_content.submitted_by = actor or exists (
    select 1 from public.content_authors ca
    where ca.content_id = requested_content_id and ca.profile_id = actor
  );
  is_responsible_reviewer := public.has_role('revisor') and selected_content.reviewer_id = actor;
  is_editor := public.has_role('editor');
  is_director := public.has_role('diretor');

  if director_exception then
    if not is_director or requested_status <> 'published' or selected_content.status = 'published' then
      raise exception using errcode = '42501', message = 'invalid_director_exception';
    end if;
    perform public.assert_content_ready_for_publication(requested_content_id);
    version_reason := 'publication';
    event_type := 'content.published';
  elsif selected_content.status = 'draft' and requested_status = 'submitted' and is_author then
    perform public.assert_content_ready_for_submission(requested_content_id);
    version_reason := 'submission';
    event_type := 'content.submitted';
  elsif selected_content.status = 'changes_requested' and requested_status = 'submitted' and is_author then
    perform public.assert_content_ready_for_submission(requested_content_id);
    version_reason := 'resubmission';
    event_type := 'content.resubmitted';
  elsif selected_content.status = 'submitted'
    and requested_status = 'under_review'
    and (public.has_role('revisor') or is_director)
  then
    null;
  elsif selected_content.status = 'under_review'
    and requested_status in ('changes_requested', 'approved', 'rejected')
    and (is_responsible_reviewer or is_director)
  then
    if requested_status = 'approved' and is_author and not is_director then
      raise exception using errcode = '42501', message = 'reviewer_cannot_approve_own_content';
    end if;
    version_reason := 'review';
    event_type := case requested_status
      when 'changes_requested' then 'review.changes_requested'
      when 'approved' then 'content.approved'
      else 'content.rejected'
    end;
  elsif selected_content.status = 'approved'
    and requested_status = 'in_editing'
    and (is_editor or is_director)
  then
    null;
  elsif selected_content.status = 'scheduled'
    and requested_status = 'in_editing'
    and (is_editor or is_director)
  then
    event_type := 'content.schedule_cancelled';
  elsif selected_content.status = 'in_editing'
    and requested_status = 'scheduled'
    and (is_editor or is_director)
  then
    if requested_schedule is null or requested_schedule <= statement_timestamp() then
      raise exception using errcode = '22023', message = 'future_schedule_required';
    end if;
    perform public.assert_content_ready_for_publication(requested_content_id);
    version_reason := 'editing';
    event_type := 'content.scheduled';
  elsif selected_content.status = 'in_editing'
    and requested_status = 'published'
    and (is_editor or is_director)
  then
    perform public.assert_content_ready_for_publication(requested_content_id);
    version_reason := 'publication';
    event_type := 'content.published';
  elsif selected_content.status = 'scheduled'
    and requested_status = 'published'
    and (is_editor or is_director)
    and selected_content.scheduled_at <= statement_timestamp()
  then
    perform public.assert_content_ready_for_publication(requested_content_id);
    version_reason := 'publication';
    event_type := 'content.published';
  elsif selected_content.status = 'published'
    and requested_status = 'archived'
    and (is_editor or is_director)
  then
    event_type := 'content.archived';
  elsif selected_content.status = 'archived'
    and requested_status = 'published'
    and (is_editor or is_director)
  then
    perform public.assert_content_ready_for_publication(requested_content_id);
    version_reason := 'publication';
    event_type := 'content.republished';
  elsif selected_content.status = 'rejected'
    and requested_status = 'submitted'
    and is_director
  then
    version_reason := 'resubmission';
    event_type := 'content.reopened';
  else
    raise exception using errcode = '42501', message = 'editorial_transition_not_allowed';
  end if;

  update public.content_items
  set status = requested_status,
      reviewer_id = case
        when requested_status = 'under_review' and reviewer_id is null then actor
        else reviewer_id
      end,
      editor_id = case
        when requested_status = 'in_editing' and selected_content.status = 'approved' then actor
        else editor_id
      end,
      submitted_at = case
        when requested_status = 'submitted' then statement_timestamp()
        else submitted_at
      end,
      approved_at = case
        when requested_status = 'approved' then statement_timestamp()
        else approved_at
      end,
      scheduled_at = case
        when requested_status = 'scheduled' then requested_schedule
        when requested_status = 'in_editing' and selected_content.status = 'scheduled' then null
        else scheduled_at
      end,
      published_at = case
        when requested_status = 'published' then statement_timestamp()
        else published_at
      end,
      archived_at = case
        when requested_status = 'archived' then statement_timestamp()
        when requested_status = 'published' then null
        else archived_at
      end
  where id = requested_content_id
  returning lock_version into resulting_lock;

  if version_reason is not null then
    perform public.create_content_version(requested_content_id, version_reason, actor);
  end if;

  insert into public.editorial_status_history (
    content_id, from_status, to_status, changed_by, reason
  ) values (
    requested_content_id, selected_content.status, requested_status, actor, justification
  );

  if event_type is not null then
    insert into public.outbox_events (
      event_type, aggregate_type, aggregate_id, payload, idempotency_key
    ) values (
      event_type, 'content', requested_content_id,
      jsonb_build_object('content_id', requested_content_id, 'status', requested_status),
      requested_content_id::text || ':' || resulting_lock::text || ':' || event_type
    );
  end if;

  perform public.write_audit_log(
    actor,
    case when director_exception then 'editorial.director_exception' else 'editorial.status_changed' end,
    'content_items', requested_content_id::text, justification,
    jsonb_build_object('status', selected_content.status, 'lock_version', selected_content.lock_version),
    jsonb_build_object('status', requested_status, 'lock_version', resulting_lock)
  );

  return resulting_lock;
end;
$$;

-- Chamado por Cron/Edge Function com service_role. SKIP LOCKED permite workers concorrentes.
create function public.publish_due_editorial_content(batch_size integer default 25)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  selected_content public.content_items;
  resulting_lock integer;
  published_count integer := 0;
  next_version integer;
begin
  if batch_size not between 1 and 100 then
    raise exception using errcode = '22023', message = 'invalid_batch_size';
  end if;

  for selected_content in
    select ci.*
    from public.content_items ci
    where ci.status = 'scheduled'
      and ci.scheduled_at <= statement_timestamp()
      and ci.deleted_at is null
    order by ci.scheduled_at, ci.id
    for update skip locked
    limit batch_size
  loop
    begin
      perform public.assert_content_ready_for_publication(selected_content.id);

      update public.content_items
      set status = 'published',
          published_at = statement_timestamp(),
          archived_at = null
      where id = selected_content.id and status = 'scheduled'
      returning lock_version into resulting_lock;

      if resulting_lock is null then
        continue;
      end if;

      select coalesce(max(cv.version_number), 0) + 1 into next_version
      from public.content_versions cv where cv.content_id = selected_content.id;
      insert into public.content_versions (
        content_id, version_number, reason, snapshot, created_by, actor_kind, actor_label
      ) values (
        selected_content.id, next_version, 'publication', public.snapshot_content(selected_content.id),
        null, 'system', 'job:publish-scheduled'
      );

      insert into public.editorial_status_history (
        content_id, from_status, to_status, changed_by, actor_kind, actor_label, reason
      ) values (
        selected_content.id, 'scheduled', 'published', null, 'system',
        'job:publish-scheduled', 'Horário agendado atingido'
      );

      insert into public.outbox_events (
        event_type, aggregate_type, aggregate_id, payload, idempotency_key
      ) values (
        'content.published', 'content', selected_content.id,
        jsonb_build_object('content_id', selected_content.id, 'status', 'published', 'source', 'schedule'),
        selected_content.id::text || ':' || resulting_lock::text || ':content.published'
      ) on conflict (idempotency_key) do nothing;

      perform public.write_audit_log(
        null, 'editorial.scheduled_published', 'content_items', selected_content.id::text,
        'Horário agendado atingido',
        jsonb_build_object('status', 'scheduled', 'lock_version', selected_content.lock_version),
        jsonb_build_object('status', 'published', 'lock_version', resulting_lock)
      );
      published_count := published_count + 1;
    exception when others then
      perform public.write_audit_log(
        null, 'editorial.schedule_failed', 'content_items', selected_content.id::text,
        left(sqlerrm, 500),
        jsonb_build_object('status', selected_content.status, 'lock_version', selected_content.lock_version),
        null
      );
    end;
  end loop;

  return published_count;
end;
$$;

-- Toda curadoria passa pelo comando atomico; a policy continua protegendo leitura.
revoke insert, update, delete on public.content_placements from authenticated;
-- As Etapas 2/4 concediam escrita granular para preparar os primeiros fluxos. A partir daqui,
-- conteúdo e relações do agregado mudam somente pelos comandos versionados.
revoke update (
  slug, type, title, subtitle, summary, body, visibility, cover_asset_id,
  seo_title, seo_description, comments_enabled, terms_version, terms_accepted_at,
  reading_time_minutes
) on public.content_items from authenticated;
revoke insert, update, delete
  on public.content_authors, public.content_categories, public.content_tags
  from authenticated;

revoke all on function public.add_editorial_comment(uuid, uuid, text) from public, anon;
revoke all on function public.save_editorial_content(
  uuid, integer, text, text, text, jsonb, uuid, uuid[], uuid, text, text, integer, text
) from public, anon;
revoke all on function public.restore_editorial_version(uuid, uuid, integer, text) from public, anon;
revoke all on function public.set_primary_hero(uuid, text) from public, anon;
revoke all on function public.publish_due_editorial_content(integer) from public, anon, authenticated;

grant execute on function public.add_editorial_comment(uuid, uuid, text) to authenticated;
grant execute on function public.save_editorial_content(
  uuid, integer, text, text, text, jsonb, uuid, uuid[], uuid, text, text, integer, text
) to authenticated;
grant execute on function public.restore_editorial_version(uuid, uuid, integer, text) to authenticated;
grant execute on function public.set_primary_hero(uuid, text) to authenticated;
grant execute on function public.publish_due_editorial_content(integer) to service_role;

comment on table public.editorial_comments is
  'Comentarios gerais vinculados a uma versao imutavel; ancoras por trecho ficam fora do MVP.';
comment on function public.save_editorial_content is
  'Salva edicao final com lock otimista, taxonomia e snapshot na mesma transacao.';
comment on function public.restore_editorial_version is
  'Restaura snapshot somente durante edicao e preserva antes/depois como versoes.';
comment on function public.publish_due_editorial_content is
  'Worker idempotente e concorrente para publicacoes cujo horario foi atingido.';
