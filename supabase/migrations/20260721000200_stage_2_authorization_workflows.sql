-- Etapa 2: helpers de autorizacao, grants minimos, RLS, Storage e comandos criticos.

create function public.has_role(required_role public.app_role)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null
    and exists (
      select 1
      from public.user_roles ur
      where ur.user_id = auth.uid()
        and ur.role_code = required_role
    );
$$;

create function public.has_any_role(required_roles public.app_role[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null
    and exists (
      select 1
      from public.user_roles ur
      where ur.user_id = auth.uid()
        and ur.role_code = any(required_roles)
    );
$$;

create function public.can_read_content(requested_content_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.content_items ci
    where ci.id = requested_content_id
      and ci.deleted_at is null
      and (
        (ci.status = 'published' and ci.visibility = 'public')
        or ci.submitted_by = auth.uid()
        or exists (
          select 1
          from public.content_authors ca
          where ca.content_id = ci.id and ca.profile_id = auth.uid()
        )
        or public.has_role('diretor')
        or (
          public.has_role('revisor')
          and ci.status in ('submitted', 'under_review', 'changes_requested')
        )
        or (
          public.has_role('editor')
          and ci.status in ('approved', 'in_editing', 'scheduled', 'published', 'archived')
        )
      )
  );
$$;

create function public.can_edit_content(requested_content_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.content_items ci
    where ci.id = requested_content_id
      and ci.deleted_at is null
      and (
        (
          ci.status in ('draft', 'changes_requested')
          and (
            ci.submitted_by = auth.uid()
            or exists (
              select 1
              from public.content_authors ca
              where ca.content_id = ci.id and ca.profile_id = auth.uid()
            )
          )
        )
        or (
          public.has_any_role(array['editor', 'diretor']::public.app_role[])
          and ci.status = 'in_editing'
        )
        or (
          public.has_role('diretor')
          and ci.status in ('draft', 'changes_requested', 'approved')
        )
      )
  );
$$;

create function public.can_read_profile(requested_profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select requested_profile_id = auth.uid()
    or public.has_any_role(array['revisor', 'editor', 'diretor']::public.app_role[])
    or exists (
      select 1
      from public.content_authors ca
      join public.content_items ci on ci.id = ca.content_id
      where ca.profile_id = requested_profile_id
        and ci.status = 'published'
        and ci.visibility = 'public'
        and ci.deleted_at is null
    );
$$;

create function public.snapshot_content(requested_content_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'content', to_jsonb(ci) - 'deleted_at',
    'authors', coalesce((
      select jsonb_agg(to_jsonb(ca) order by ca.position)
      from public.content_authors ca
      where ca.content_id = ci.id
    ), '[]'::jsonb),
    'categories', coalesce((
      select jsonb_agg(to_jsonb(cc) order by cc.is_primary desc, cc.category_id)
      from public.content_categories cc
      where cc.content_id = ci.id
    ), '[]'::jsonb),
    'tags', coalesce((
      select jsonb_agg(to_jsonb(ct) order by ct.tag_id)
      from public.content_tags ct
      where ct.content_id = ci.id
    ), '[]'::jsonb)
  )
  from public.content_items ci
  where ci.id = requested_content_id;
$$;

create function public.assert_content_ready_for_submission(requested_content_id uuid)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  selected_content public.content_items;
begin
  select * into selected_content
  from public.content_items
  where id = requested_content_id;

  if selected_content.id is null then
    raise exception using errcode = 'P0002', message = 'content_not_found';
  end if;

  if nullif(trim(selected_content.title), '') is null
    or selected_content.body = '{}'::jsonb
    or selected_content.terms_version is null
    or selected_content.terms_accepted_at is null
    or not exists (
      select 1 from public.content_authors ca where ca.content_id = requested_content_id
    )
    or not exists (
      select 1
      from public.content_categories cc
      join public.categories c on c.id = cc.category_id
      where cc.content_id = requested_content_id
        and cc.is_primary
        and c.archived_at is null
    )
  then
    raise exception using errcode = '23514', message = 'content_missing_submission_requirements';
  end if;
end;
$$;

create function public.assert_content_ready_for_publication(requested_content_id uuid)
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

  if selected_content.seo_title is null
    or selected_content.seo_description is null
    or selected_content.cover_asset_id is null
    or not exists (
      select 1
      from public.media_assets ma
      where ma.id = selected_content.cover_asset_id
        and ma.mime_type like 'image/%'
        and nullif(trim(ma.alt_text), '') is not null
        and ma.archived_at is null
    )
  then
    raise exception using errcode = '23514', message = 'content_missing_publication_requirements';
  end if;
end;
$$;

create function public.create_content_version(
  requested_content_id uuid,
  requested_reason public.version_reason,
  requested_actor uuid
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  next_version integer;
begin
  select coalesce(max(cv.version_number), 0) + 1
    into next_version
  from public.content_versions cv
  where cv.content_id = requested_content_id;

  insert into public.content_versions (
    content_id,
    version_number,
    reason,
    snapshot,
    created_by
  ) values (
    requested_content_id,
    next_version,
    requested_reason,
    public.snapshot_content(requested_content_id),
    requested_actor
  );

  return next_version;
end;
$$;

create function public.write_audit_log(
  requested_actor uuid,
  requested_action text,
  requested_table text,
  requested_target_id text,
  requested_reason text,
  requested_before jsonb,
  requested_after jsonb
)
returns void
language sql
volatile
security definer
set search_path = ''
as $$
  insert into public.audit_logs (
    actor_id,
    action,
    target_table,
    target_id,
    reason,
    before_state,
    after_state,
    request_id
  ) values (
    requested_actor,
    requested_action,
    requested_table,
    requested_target_id,
    requested_reason,
    requested_before,
    requested_after,
    current_setting('request.headers', true)::jsonb ->> 'x-request-id'
  );
$$;

create function public.assign_user_role(
  requested_user_id uuid,
  requested_role public.app_role,
  justification text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  inserted boolean;
begin
  if actor is null or not public.has_role('diretor') then
    raise exception using errcode = '42501', message = 'insufficient_privilege';
  end if;
  if char_length(trim(justification)) < 3 then
    raise exception using errcode = '22023', message = 'justification_required';
  end if;
  if not exists (select 1 from public.profiles p where p.id = requested_user_id) then
    raise exception using errcode = 'P0002', message = 'profile_not_found';
  end if;

  insert into public.user_roles (user_id, role_code)
  values (requested_user_id, requested_role)
  on conflict do nothing
  returning true into inserted;

  if coalesce(inserted, false) then
    perform public.write_audit_log(
      actor,
      'identity.role_assigned',
      'user_roles',
      requested_user_id::text || ':' || requested_role::text,
      justification,
      null,
      jsonb_build_object('role', requested_role)
    );
  end if;
end;
$$;

create function public.revoke_user_role(
  requested_user_id uuid,
  requested_role public.app_role,
  justification text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  removed boolean;
begin
  if actor is null or not public.has_role('diretor') then
    raise exception using errcode = '42501', message = 'insufficient_privilege';
  end if;
  if char_length(trim(justification)) < 3 then
    raise exception using errcode = '22023', message = 'justification_required';
  end if;
  if requested_role = 'diretor'
    and (select count(*) from public.user_roles where role_code = 'diretor') <= 1
  then
    raise exception using errcode = '23514', message = 'last_director_cannot_be_removed';
  end if;

  delete from public.user_roles
  where user_id = requested_user_id and role_code = requested_role
  returning true into removed;

  if coalesce(removed, false) then
    perform public.write_audit_log(
      actor,
      'identity.role_revoked',
      'user_roles',
      requested_user_id::text || ':' || requested_role::text,
      justification,
      jsonb_build_object('role', requested_role),
      null
    );
  end if;
end;
$$;

create function public.assign_editorial_reviewer(
  requested_content_id uuid,
  requested_reviewer_id uuid,
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
  resulting_lock integer;
begin
  if actor is null or not public.has_any_role(array['revisor', 'diretor']::public.app_role[]) then
    raise exception using errcode = '42501', message = 'insufficient_privilege';
  end if;
  if char_length(trim(justification)) < 3 then
    raise exception using errcode = '22023', message = 'justification_required';
  end if;
  if not exists (
    select 1 from public.user_roles
    where user_id = requested_reviewer_id and role_code in ('revisor', 'diretor')
  ) then
    raise exception using errcode = '23514', message = 'assignee_is_not_a_reviewer';
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
  if selected_content.status not in ('submitted', 'under_review') then
    raise exception using errcode = '23514', message = 'content_not_assignable';
  end if;

  update public.content_items
  set reviewer_id = requested_reviewer_id,
      status = 'under_review'
  where id = requested_content_id
  returning lock_version into resulting_lock;

  if selected_content.status = 'submitted' then
    insert into public.editorial_status_history (
      content_id, from_status, to_status, changed_by, reason
    ) values (
      requested_content_id, 'submitted', 'under_review', actor, justification
    );
  end if;

  perform public.write_audit_log(
    actor,
    'editorial.reviewer_assigned',
    'content_items',
    requested_content_id::text,
    justification,
    jsonb_build_object('reviewer_id', selected_content.reviewer_id, 'status', selected_content.status),
    jsonb_build_object('reviewer_id', requested_reviewer_id, 'status', 'under_review')
  );

  return resulting_lock;
end;
$$;

create function public.transition_editorial_content(
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
    if not is_director or requested_status <> 'published' then
      raise exception using errcode = '42501', message = 'invalid_director_exception';
    end if;
    perform public.assert_content_ready_for_publication(requested_content_id);
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
        when requested_status = 'in_editing' and editor_id is null then actor
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
        else scheduled_at
      end,
      published_at = case
        when requested_status = 'published' then coalesce(published_at, statement_timestamp())
        else published_at
      end,
      archived_at = case
        when requested_status = 'archived' then statement_timestamp()
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
      event_type,
      aggregate_type,
      aggregate_id,
      payload,
      idempotency_key
    ) values (
      event_type,
      'content',
      requested_content_id,
      jsonb_build_object('content_id', requested_content_id, 'status', requested_status),
      requested_content_id::text || ':' || resulting_lock::text || ':' || event_type
    );
  end if;

  perform public.write_audit_log(
    actor,
    case when director_exception then 'editorial.director_exception' else 'editorial.status_changed' end,
    'content_items',
    requested_content_id::text,
    justification,
    jsonb_build_object('status', selected_content.status, 'lock_version', selected_content.lock_version),
    jsonb_build_object('status', requested_status, 'lock_version', resulting_lock)
  );

  return resulting_lock;
end;
$$;

-- Privilegios: a API so enxerga o que foi concedido explicitamente e a RLS ainda precisa aprovar.
revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;

grant select on public.profiles to anon, authenticated;
grant update (display_name, avatar_path, course, affiliation) on public.profiles to authenticated;
grant select on public.roles to authenticated;
grant select on public.user_roles to authenticated;

grant select on public.categories, public.tags, public.editions to anon, authenticated;
grant insert on public.categories, public.tags, public.editions to authenticated;
grant update (name, slug, description, archived_at) on public.categories to authenticated;
grant update (name, slug, archived_at) on public.tags to authenticated;
grant update (
  title, slug, summary, issue_number, starts_on, ends_on, published_at, archived_at
) on public.editions to authenticated;
grant select on public.media_assets to anon, authenticated;
grant insert on public.media_assets to authenticated;
grant update (title, alt_text, credit, license, archived_at) on public.media_assets to authenticated;

grant select on public.content_items to anon, authenticated;
grant insert (
  slug, type, title, subtitle, summary, body, visibility, submitted_by,
  cover_asset_id, seo_title, seo_description, comments_enabled, terms_version, terms_accepted_at
) on public.content_items to authenticated;
grant update (
  slug, type, title, subtitle, summary, body, visibility, cover_asset_id,
  seo_title, seo_description, comments_enabled, terms_version, terms_accepted_at
) on public.content_items to authenticated;

grant select on public.content_authors, public.content_categories, public.content_tags to anon, authenticated;
grant insert, update, delete on public.content_authors, public.content_categories, public.content_tags to authenticated;
grant select on public.edition_items to anon, authenticated;
grant insert, update, delete on public.edition_items to authenticated;
grant select on public.content_slug_redirects to anon, authenticated;
grant select on public.content_versions, public.editorial_status_history to authenticated;
grant select on public.audit_logs, public.outbox_events to authenticated;

revoke all on function public.has_role(public.app_role) from public;
revoke all on function public.has_any_role(public.app_role[]) from public;
revoke all on function public.can_read_content(uuid) from public;
revoke all on function public.can_edit_content(uuid) from public;
revoke all on function public.can_read_profile(uuid) from public;
grant execute on function public.has_role(public.app_role) to authenticated;
grant execute on function public.has_any_role(public.app_role[]) to authenticated;
grant execute on function public.can_read_content(uuid) to anon, authenticated;
grant execute on function public.can_edit_content(uuid) to authenticated;
grant execute on function public.can_read_profile(uuid) to anon, authenticated;

revoke all on function public.snapshot_content(uuid) from public, anon, authenticated;
revoke all on function public.assert_content_ready_for_submission(uuid) from public, anon, authenticated;
revoke all on function public.assert_content_ready_for_publication(uuid) from public, anon, authenticated;
revoke all on function public.create_content_version(uuid, public.version_reason, uuid) from public, anon, authenticated;
revoke all on function public.write_audit_log(uuid, text, text, text, text, jsonb, jsonb) from public, anon, authenticated;

revoke all on function public.assign_user_role(uuid, public.app_role, text) from public, anon;
revoke all on function public.revoke_user_role(uuid, public.app_role, text) from public, anon;
revoke all on function public.assign_editorial_reviewer(uuid, uuid, integer, text) from public, anon;
revoke all on function public.transition_editorial_content(uuid, public.editorial_status, integer, text, timestamptz, boolean) from public, anon;
grant execute on function public.assign_user_role(uuid, public.app_role, text) to authenticated;
grant execute on function public.revoke_user_role(uuid, public.app_role, text) to authenticated;
grant execute on function public.assign_editorial_reviewer(uuid, uuid, integer, text) to authenticated;
grant execute on function public.transition_editorial_content(uuid, public.editorial_status, integer, text, timestamptz, boolean) to authenticated;

-- Profiles e RBAC.
create policy profiles_select_allowed
on public.profiles for select
to anon, authenticated
using (public.can_read_profile(id));

create policy profiles_update_self
on public.profiles for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

create policy roles_select_authenticated
on public.roles for select
to authenticated
using (true);

create policy user_roles_select_self_or_director
on public.user_roles for select
to authenticated
using (user_id = auth.uid() or public.has_role('diretor'));

-- Taxonomia e edicoes: catalogo ativo e publico; mutacao apenas por Editor/Diretor.
create policy categories_select_visible
on public.categories for select
to anon, authenticated
using (archived_at is null or public.has_any_role(array['editor', 'diretor']::public.app_role[]));
create policy categories_insert_editorial
on public.categories for insert
to authenticated
with check (
  created_by = auth.uid()
  and public.has_any_role(array['editor', 'diretor']::public.app_role[])
);
create policy categories_update_editorial
on public.categories for update
to authenticated
using (public.has_any_role(array['editor', 'diretor']::public.app_role[]))
with check (public.has_any_role(array['editor', 'diretor']::public.app_role[]));

create policy tags_select_visible
on public.tags for select
to anon, authenticated
using (archived_at is null or public.has_any_role(array['editor', 'diretor']::public.app_role[]));
create policy tags_insert_editorial
on public.tags for insert
to authenticated
with check (
  created_by = auth.uid()
  and public.has_any_role(array['editor', 'diretor']::public.app_role[])
);
create policy tags_update_editorial
on public.tags for update
to authenticated
using (public.has_any_role(array['editor', 'diretor']::public.app_role[]))
with check (public.has_any_role(array['editor', 'diretor']::public.app_role[]));

create policy editions_select_visible
on public.editions for select
to anon, authenticated
using (
  (published_at is not null and archived_at is null)
  or public.has_any_role(array['editor', 'diretor']::public.app_role[])
);
create policy editions_insert_editorial
on public.editions for insert
to authenticated
with check (
  created_by = auth.uid()
  and public.has_any_role(array['editor', 'diretor']::public.app_role[])
);
create policy editions_update_editorial
on public.editions for update
to authenticated
using (public.has_any_role(array['editor', 'diretor']::public.app_role[]))
with check (public.has_any_role(array['editor', 'diretor']::public.app_role[]));

-- Conteudo e relacoes do agregado.
create policy content_items_select_allowed
on public.content_items for select
to anon, authenticated
using (public.can_read_content(id));

create policy content_items_insert_own_draft
on public.content_items for insert
to authenticated
with check (
  submitted_by = auth.uid()
  and status = 'draft'
  and reviewer_id is null
  and editor_id is null
  and submitted_at is null
  and approved_at is null
  and scheduled_at is null
  and published_at is null
  and archived_at is null
  and deleted_at is null
);

create policy content_items_update_allowed
on public.content_items for update
to authenticated
using (public.can_edit_content(id))
with check (public.can_edit_content(id));

create policy content_authors_select_allowed
on public.content_authors for select
to anon, authenticated
using (public.can_read_content(content_id));
create policy content_authors_insert_allowed
on public.content_authors for insert
to authenticated
with check (public.can_edit_content(content_id));
create policy content_authors_update_allowed
on public.content_authors for update
to authenticated
using (public.can_edit_content(content_id))
with check (public.can_edit_content(content_id));
create policy content_authors_delete_allowed
on public.content_authors for delete
to authenticated
using (public.can_edit_content(content_id));

create policy content_categories_select_allowed
on public.content_categories for select
to anon, authenticated
using (public.can_read_content(content_id));
create policy content_categories_insert_allowed
on public.content_categories for insert
to authenticated
with check (public.can_edit_content(content_id));
create policy content_categories_update_allowed
on public.content_categories for update
to authenticated
using (public.can_edit_content(content_id))
with check (public.can_edit_content(content_id));
create policy content_categories_delete_allowed
on public.content_categories for delete
to authenticated
using (public.can_edit_content(content_id));

create policy content_tags_select_allowed
on public.content_tags for select
to anon, authenticated
using (public.can_read_content(content_id));
create policy content_tags_insert_allowed
on public.content_tags for insert
to authenticated
with check (public.can_edit_content(content_id));
create policy content_tags_update_allowed
on public.content_tags for update
to authenticated
using (public.can_edit_content(content_id))
with check (public.can_edit_content(content_id));
create policy content_tags_delete_allowed
on public.content_tags for delete
to authenticated
using (public.can_edit_content(content_id));

create policy edition_items_select_allowed
on public.edition_items for select
to anon, authenticated
using (
  public.can_read_content(content_id)
  and exists (
    select 1 from public.editions e
    where e.id = edition_id
      and ((e.published_at is not null and e.archived_at is null)
        or public.has_any_role(array['editor', 'diretor']::public.app_role[]))
  )
);
create policy edition_items_insert_editorial
on public.edition_items for insert
to authenticated
with check (public.has_any_role(array['editor', 'diretor']::public.app_role[]));
create policy edition_items_update_editorial
on public.edition_items for update
to authenticated
using (public.has_any_role(array['editor', 'diretor']::public.app_role[]))
with check (public.has_any_role(array['editor', 'diretor']::public.app_role[]));
create policy edition_items_delete_editorial
on public.edition_items for delete
to authenticated
using (public.has_any_role(array['editor', 'diretor']::public.app_role[]));

create policy content_slug_redirects_select_published
on public.content_slug_redirects for select
to anon, authenticated
using (public.can_read_content(content_id));

create policy content_versions_select_allowed
on public.content_versions for select
to authenticated
using (public.can_read_content(content_id));
create policy editorial_history_select_allowed
on public.editorial_status_history for select
to authenticated
using (public.can_read_content(content_id));

create policy audit_logs_select_director
on public.audit_logs for select
to authenticated
using (public.has_role('diretor'));
create policy outbox_events_select_director
on public.outbox_events for select
to authenticated
using (public.has_role('diretor'));

-- Metadados e objetos de Storage.
create policy media_assets_select_allowed
on public.media_assets for select
to anon, authenticated
using (
  (bucket_id = 'content-public' and archived_at is null)
  or owner_id = auth.uid()
  or public.has_any_role(array['revisor', 'editor', 'diretor']::public.app_role[])
);
create policy media_assets_insert_allowed
on public.media_assets for insert
to authenticated
with check (
  owner_id = auth.uid()
  and split_part(object_path, '/', 1) = auth.uid()::text
  and (
    bucket_id = 'content-drafts'
    or public.has_any_role(array['editor', 'diretor']::public.app_role[])
  )
);
create policy media_assets_update_allowed
on public.media_assets for update
to authenticated
using (
  (owner_id = auth.uid() and bucket_id = 'content-drafts')
  or public.has_any_role(array['editor', 'diretor']::public.app_role[])
)
with check (
  (owner_id = auth.uid() and bucket_id = 'content-drafts')
  or public.has_any_role(array['editor', 'diretor']::public.app_role[])
);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  (
    'content-drafts',
    'content-drafts',
    false,
    10485760,
    array['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
  ),
  (
    'content-public',
    'content-public',
    true,
    10485760,
    array['image/jpeg', 'image/png', 'image/webp']
  )
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy storage_drafts_select_owner_or_editorial
on storage.objects for select
to authenticated
using (
  bucket_id = 'content-drafts'
  and (
    (storage.foldername(name))[1] = auth.uid()::text
    or public.has_any_role(array['revisor', 'editor', 'diretor']::public.app_role[])
  )
);
create policy storage_public_select
on storage.objects for select
to anon, authenticated
using (bucket_id = 'content-public');
create policy storage_insert_owned_path
on storage.objects for insert
to authenticated
with check (
  bucket_id in ('content-drafts', 'content-public')
  and (storage.foldername(name))[1] = auth.uid()::text
  and (
    bucket_id = 'content-drafts'
    or public.has_any_role(array['editor', 'diretor']::public.app_role[])
  )
);
create policy storage_update_owned_path
on storage.objects for update
to authenticated
using (
  bucket_id in ('content-drafts', 'content-public')
  and (storage.foldername(name))[1] = auth.uid()::text
  and (
    bucket_id = 'content-drafts'
    or public.has_any_role(array['editor', 'diretor']::public.app_role[])
  )
)
with check (
  bucket_id in ('content-drafts', 'content-public')
  and (storage.foldername(name))[1] = auth.uid()::text
  and (
    bucket_id = 'content-drafts'
    or public.has_any_role(array['editor', 'diretor']::public.app_role[])
  )
);
create policy storage_delete_owned_path
on storage.objects for delete
to authenticated
using (
  bucket_id in ('content-drafts', 'content-public')
  and (storage.foldername(name))[1] = auth.uid()::text
  and (
    bucket_id = 'content-drafts'
    or public.has_any_role(array['editor', 'diretor']::public.app_role[])
  )
);
