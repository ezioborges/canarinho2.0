-- Etapa 4: conta, termos versionados, rascunhos idempotentes e anexos privados.

alter table public.content_items
  add column submission_notes text check (
    submission_notes is null or char_length(submission_notes) <= 4000
  );

create table public.submission_terms (
  version text primary key check (version ~ '^[0-9]{4}-[0-9]{2}$'),
  title text not null check (char_length(trim(title)) between 3 and 160),
  body text not null check (char_length(trim(body)) >= 20),
  published_at timestamptz not null default statement_timestamp(),
  retired_at timestamptz,
  constraint submission_terms_dates_valid check (
    retired_at is null or retired_at > published_at
  )
);

alter table public.submission_terms enable row level security;

create table public.content_media_assets (
  content_id uuid not null references public.content_items (id) on delete cascade,
  asset_id uuid not null references public.media_assets (id) on delete cascade,
  position smallint not null check (position > 0),
  created_at timestamptz not null default statement_timestamp(),
  primary key (content_id, asset_id),
  unique (content_id, position)
);

create index content_media_assets_asset_idx on public.content_media_assets (asset_id);
alter table public.content_media_assets enable row level security;

-- Recibos internos tornam retry/autosave seguro sem expor chaves de idempotencia pela API.
create table public.content_command_receipts (
  actor_id uuid not null references public.profiles (id) on delete cascade,
  idempotency_key uuid not null,
  command_name text not null check (command_name in ('draft.save', 'content.submit')),
  content_id uuid not null references public.content_items (id) on delete cascade,
  result jsonb not null check (jsonb_typeof(result) = 'object'),
  created_at timestamptz not null default statement_timestamp(),
  primary key (actor_id, idempotency_key)
);

alter table public.content_command_receipts enable row level security;

-- Toda conta nova recebe o papel funcional minimo. O email continua canonico e privado em Auth.
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(
      nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''),
      split_part(coalesce(new.email, 'usuario'), '@', 1)
    )
  );

  insert into public.user_roles (user_id, role_code)
  values (new.id, 'leitor')
  on conflict do nothing;

  return new;
end;
$$;

create function public.validate_private_media_asset()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  extension text := lower(split_part(new.object_path, '.', -1));
begin
  if new.bucket_id <> 'content-drafts' then
    return new;
  end if;

  if new.object_path !~ (
    '^' || new.owner_id::text ||
    '/[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/' ||
    '[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.(jpg|jpeg|png|webp|pdf)$'
  ) then
    raise exception using errcode = '23514', message = 'invalid_private_asset_path';
  end if;

  if not (
    (extension in ('jpg', 'jpeg') and new.mime_type = 'image/jpeg')
    or (extension = 'png' and new.mime_type = 'image/png')
    or (extension = 'webp' and new.mime_type = 'image/webp')
    or (extension = 'pdf' and new.mime_type = 'application/pdf')
  ) then
    raise exception using errcode = '23514', message = 'asset_extension_mime_mismatch';
  end if;

  return new;
end;
$$;

create trigger media_assets_validate_private_upload
before insert or update of object_path, mime_type, byte_size, bucket_id on public.media_assets
for each row execute function public.validate_private_media_asset();

create function public.is_owned_draft_object_path(object_name text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  path_parts text[] := string_to_array(object_name, '/');
  requested_content_id uuid;
begin
  if auth.uid() is null or cardinality(path_parts) <> 3 or path_parts[1] <> auth.uid()::text then
    return false;
  end if;

  begin
    requested_content_id := path_parts[2]::uuid;
  exception when invalid_text_representation then
    return false;
  end;

  return public.can_edit_content(requested_content_id);
end;
$$;

create or replace function public.assert_content_ready_for_submission(requested_content_id uuid)
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
    or not exists (
      select 1
      from jsonb_path_query(selected_content.body, 'strict $.**.text') text_node
      where char_length(trim(text_node #>> '{}')) > 0
    )
    or selected_content.terms_version is null
    or selected_content.terms_accepted_at is null
    or not exists (
      select 1
      from public.submission_terms st
      where st.version = selected_content.terms_version
        and st.published_at <= selected_content.terms_accepted_at
    )
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

create function public.save_own_content_draft(
  requested_content_id uuid,
  expected_lock_version integer,
  idempotency_key uuid,
  requested_slug text,
  requested_type public.content_type,
  requested_title text,
  requested_subtitle text,
  requested_summary text,
  requested_body jsonb,
  requested_authors jsonb,
  requested_primary_category_id uuid,
  requested_tag_ids uuid[],
  requested_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  selected_content public.content_items;
  resulting_lock integer;
  saved_result jsonb;
  author_item jsonb;
  author_position integer := 0;
begin
  if actor is null then
    raise exception using errcode = '42501', message = 'authentication_required';
  end if;
  if requested_content_id is null or idempotency_key is null then
    raise exception using errcode = '22023', message = 'content_and_idempotency_required';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(actor::text || ':' || idempotency_key::text, 0));
  select result into saved_result
  from public.content_command_receipts
  where actor_id = actor and content_command_receipts.idempotency_key = save_own_content_draft.idempotency_key;
  if saved_result is not null then
    return saved_result;
  end if;

  if char_length(trim(requested_title)) not between 3 and 180
    or requested_slug !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'
    or jsonb_typeof(requested_body) <> 'object'
    or jsonb_typeof(requested_authors) <> 'array'
    or jsonb_array_length(requested_authors) > 10
    or coalesce(array_length(requested_tag_ids, 1), 0) > 12
    or (requested_notes is not null and char_length(requested_notes) > 4000)
  then
    raise exception using errcode = '22023', message = 'invalid_draft_payload';
  end if;

  select * into selected_content
  from public.content_items
  where id = requested_content_id
  for update;

  if selected_content.id is null then
    if expected_lock_version is not null then
      raise exception using errcode = 'P0002', message = 'content_not_found';
    end if;

    insert into public.content_items (
      id, slug, type, title, subtitle, summary, body, status, submitted_by, submission_notes
    ) values (
      requested_content_id, requested_slug, requested_type, trim(requested_title),
      nullif(trim(requested_subtitle), ''), nullif(trim(requested_summary), ''),
      requested_body, 'draft', actor, nullif(trim(requested_notes), '')
    ) returning lock_version into resulting_lock;
  else
    if not public.can_edit_content(requested_content_id)
      or selected_content.status not in ('draft', 'changes_requested')
    then
      raise exception using errcode = '42501', message = 'content_not_editable';
    end if;
    if expected_lock_version is null or selected_content.lock_version <> expected_lock_version then
      raise exception using errcode = '40001', message = 'stale_content_version';
    end if;

    update public.content_items
    set slug = requested_slug,
        type = requested_type,
        title = trim(requested_title),
        subtitle = nullif(trim(requested_subtitle), ''),
        summary = nullif(trim(requested_summary), ''),
        body = requested_body,
        submission_notes = nullif(trim(requested_notes), '')
    where id = requested_content_id
    returning lock_version into resulting_lock;

    delete from public.content_authors where content_id = requested_content_id;
    delete from public.content_categories where content_id = requested_content_id;
    delete from public.content_tags where content_id = requested_content_id;
  end if;

  for author_item in select value from jsonb_array_elements(requested_authors)
  loop
    author_position := author_position + 1;
    if jsonb_typeof(author_item) <> 'object'
      or (author_item ->> 'profile_id') is not null
        and (author_item ->> 'profile_id')::uuid <> actor
      or (author_item ->> 'profile_id') is null
        and char_length(trim(coalesce(author_item ->> 'display_name', ''))) not between 2 and 120
    then
      raise exception using errcode = '22023', message = 'invalid_content_author';
    end if;

    insert into public.content_authors (content_id, position, profile_id, display_name)
    values (
      requested_content_id,
      author_position,
      nullif(author_item ->> 'profile_id', '')::uuid,
      case when (author_item ->> 'profile_id') is null then trim(author_item ->> 'display_name') end
    );
  end loop;

  if requested_primary_category_id is not null then
    if not exists (
      select 1 from public.categories
      where id = requested_primary_category_id and archived_at is null
    ) then
      raise exception using errcode = '23514', message = 'invalid_primary_category';
    end if;
    insert into public.content_categories (content_id, category_id, is_primary)
    values (requested_content_id, requested_primary_category_id, true);
  end if;

  insert into public.content_tags (content_id, tag_id)
  select requested_content_id, tag_id
  from unnest(coalesce(requested_tag_ids, '{}'::uuid[])) tag_id
  join public.tags t on t.id = tag_id and t.archived_at is null
  on conflict do nothing;

  saved_result := jsonb_build_object(
    'content_id', requested_content_id,
    'lock_version', resulting_lock,
    'saved_at', statement_timestamp()
  );

  insert into public.content_command_receipts (
    actor_id, idempotency_key, command_name, content_id, result
  ) values (actor, idempotency_key, 'draft.save', requested_content_id, saved_result);

  return saved_result;
end;
$$;

create function public.submit_own_content(
  requested_content_id uuid,
  expected_lock_version integer,
  requested_terms_version text,
  idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  selected_content public.content_items;
  resulting_lock integer;
  saved_result jsonb;
begin
  if actor is null then
    raise exception using errcode = '42501', message = 'authentication_required';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(actor::text || ':' || idempotency_key::text, 0));
  select result into saved_result
  from public.content_command_receipts
  where actor_id = actor and content_command_receipts.idempotency_key = submit_own_content.idempotency_key;
  if saved_result is not null then
    return saved_result;
  end if;

  select * into selected_content
  from public.content_items
  where id = requested_content_id
  for update;

  if selected_content.id is null then
    raise exception using errcode = 'P0002', message = 'content_not_found';
  end if;
  if selected_content.submitted_by <> actor
    and not exists (
      select 1 from public.content_authors
      where content_id = requested_content_id and profile_id = actor
    )
  then
    raise exception using errcode = '42501', message = 'content_not_owned';
  end if;

  -- Um segundo clique com outra chave tambem converge para o mesmo resultado sem novo evento.
  if selected_content.status = 'submitted' then
    saved_result := jsonb_build_object(
      'content_id', requested_content_id,
      'lock_version', selected_content.lock_version,
      'status', selected_content.status
    );
    insert into public.content_command_receipts (
      actor_id, idempotency_key, command_name, content_id, result
    ) values (actor, idempotency_key, 'content.submit', requested_content_id, saved_result);
    return saved_result;
  end if;

  if selected_content.status not in ('draft', 'changes_requested') then
    raise exception using errcode = '42501', message = 'content_not_submittable';
  end if;
  if selected_content.lock_version <> expected_lock_version then
    raise exception using errcode = '40001', message = 'stale_content_version';
  end if;
  if not exists (
    select 1 from public.submission_terms
    where version = requested_terms_version
      and published_at <= statement_timestamp()
      and retired_at is null
  ) then
    raise exception using errcode = '23514', message = 'submission_terms_not_active';
  end if;

  update public.content_items
  set terms_version = requested_terms_version,
      terms_accepted_at = statement_timestamp()
  where id = requested_content_id
  returning lock_version into resulting_lock;

  resulting_lock := public.transition_editorial_content(
    requested_content_id,
    'submitted',
    resulting_lock,
    'Submissao enviada pelo autor com aceite dos termos ' || requested_terms_version
  );

  saved_result := jsonb_build_object(
    'content_id', requested_content_id,
    'lock_version', resulting_lock,
    'status', 'submitted'
  );
  insert into public.content_command_receipts (
    actor_id, idempotency_key, command_name, content_id, result
  ) values (actor, idempotency_key, 'content.submit', requested_content_id, saved_result);

  return saved_result;
end;
$$;

create function public.register_own_draft_asset(
  requested_asset_id uuid,
  requested_content_id uuid,
  requested_object_path text,
  requested_purpose public.asset_purpose,
  requested_mime_type text,
  requested_byte_size bigint,
  requested_title text,
  requested_alt_text text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  next_position smallint;
begin
  if actor is null then
    raise exception using errcode = '42501', message = 'authentication_required';
  end if;
  if not public.can_edit_content(requested_content_id) then
    raise exception using errcode = '42501', message = 'content_not_editable';
  end if;
  if split_part(requested_object_path, '/', 1) <> actor::text
    or split_part(requested_object_path, '/', 2) <> requested_content_id::text
  then
    raise exception using errcode = '23514', message = 'asset_path_content_mismatch';
  end if;

  insert into public.media_assets (
    id, owner_id, bucket_id, object_path, purpose, mime_type, byte_size, title, alt_text
  ) values (
    requested_asset_id, actor, 'content-drafts', requested_object_path, requested_purpose,
    requested_mime_type, requested_byte_size, nullif(trim(requested_title), ''),
    nullif(trim(requested_alt_text), '')
  );

  select (coalesce(max(position), 0) + 1)::smallint into next_position
  from public.content_media_assets where content_id = requested_content_id;

  insert into public.content_media_assets (content_id, asset_id, position)
  values (requested_content_id, requested_asset_id, next_position);

  return jsonb_build_object(
    'id', requested_asset_id,
    'object_path', requested_object_path,
    'mime_type', requested_mime_type,
    'byte_size', requested_byte_size,
    'title', nullif(trim(requested_title), '')
  );
end;
$$;

create function public.get_own_submission(requested_content_id uuid)
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
    ), '[]'::jsonb)
  )
  from public.content_items ci
  where ci.id = requested_content_id
    and ci.deleted_at is null;
$$;

-- Grants e policies da nova fronteira.
revoke all on public.submission_terms, public.content_media_assets, public.content_command_receipts
from anon, authenticated;
grant select on public.submission_terms to anon, authenticated;
grant select, insert, delete on public.content_media_assets to authenticated;

create policy submission_terms_read_published
on public.submission_terms for select
to anon, authenticated
using (published_at <= statement_timestamp());

create policy content_media_assets_select_allowed
on public.content_media_assets for select
to authenticated
using (public.can_read_content(content_id));
create policy content_media_assets_insert_allowed
on public.content_media_assets for insert
to authenticated
with check (
  public.can_edit_content(content_id)
  and exists (
    select 1 from public.media_assets ma
    where ma.id = asset_id and ma.owner_id = auth.uid() and ma.bucket_id = 'content-drafts'
  )
);
create policy content_media_assets_delete_allowed
on public.content_media_assets for delete
to authenticated
using (public.can_edit_content(content_id));

revoke all on function public.validate_private_media_asset() from public, anon, authenticated;
revoke all on function public.is_owned_draft_object_path(text) from public;
grant execute on function public.is_owned_draft_object_path(text) to authenticated;
revoke all on function public.save_own_content_draft(
  uuid, integer, uuid, text, public.content_type, text, text, text, jsonb, jsonb, uuid, uuid[], text
) from public, anon;
revoke all on function public.submit_own_content(uuid, integer, text, uuid) from public, anon;
revoke all on function public.register_own_draft_asset(
  uuid, uuid, text, public.asset_purpose, text, bigint, text, text
) from public, anon;
revoke all on function public.get_own_submission(uuid) from public, anon;
grant execute on function public.save_own_content_draft(
  uuid, integer, uuid, text, public.content_type, text, text, text, jsonb, jsonb, uuid, uuid[], text
) to authenticated;
grant execute on function public.submit_own_content(uuid, integer, text, uuid) to authenticated;
grant execute on function public.register_own_draft_asset(
  uuid, uuid, text, public.asset_purpose, text, bigint, text, text
) to authenticated;
grant execute on function public.get_own_submission(uuid) to authenticated;

drop policy storage_drafts_select_owner_or_editorial on storage.objects;
drop policy storage_insert_owned_path on storage.objects;
drop policy storage_update_owned_path on storage.objects;
drop policy storage_delete_owned_path on storage.objects;

create policy storage_drafts_select_owner_or_editorial
on storage.objects for select
to authenticated
using (
  bucket_id = 'content-drafts'
  and (
    public.is_owned_draft_object_path(name)
    or public.has_any_role(array['revisor', 'editor', 'diretor']::public.app_role[])
  )
);
create policy storage_insert_owned_path
on storage.objects for insert
to authenticated
with check (
  (bucket_id = 'content-drafts' and public.is_owned_draft_object_path(name))
  or (
    bucket_id = 'content-public'
    and (storage.foldername(name))[1] = auth.uid()::text
    and public.has_any_role(array['editor', 'diretor']::public.app_role[])
  )
);
create policy storage_update_owned_path
on storage.objects for update
to authenticated
using (
  (bucket_id = 'content-drafts' and public.is_owned_draft_object_path(name))
  or (
    bucket_id = 'content-public'
    and (storage.foldername(name))[1] = auth.uid()::text
    and public.has_any_role(array['editor', 'diretor']::public.app_role[])
  )
)
with check (
  (bucket_id = 'content-drafts' and public.is_owned_draft_object_path(name))
  or (
    bucket_id = 'content-public'
    and (storage.foldername(name))[1] = auth.uid()::text
    and public.has_any_role(array['editor', 'diretor']::public.app_role[])
  )
);
create policy storage_delete_owned_path
on storage.objects for delete
to authenticated
using (
  (bucket_id = 'content-drafts' and public.is_owned_draft_object_path(name))
  or (
    bucket_id = 'content-public'
    and (storage.foldername(name))[1] = auth.uid()::text
    and public.has_any_role(array['editor', 'diretor']::public.app_role[])
  )
);

insert into public.submission_terms (version, title, body, published_at, retired_at)
values
  (
    '2026-01',
    'Termos de submissao do Canarinho — versao historica',
    'Versao historica preservada para validar a rastreabilidade dos conteudos aceitos antes da entrada em vigor dos termos atuais.',
    '2026-01-01 00:00:00-03',
    '2026-07-01 00:00:00-03'
  ),
  (
    '2026-07',
    'Termos de submissao do Canarinho',
    'Declaro possuir autorizacao para enviar este conteudo e seus arquivos. Autorizo a equipe do Canarinho a revisar, editar e publicar o material, preservando os creditos informados. Dados pessoais serao usados apenas para operar o fluxo editorial.',
    '2026-07-01 00:00:00-03',
    null
  );

comment on table public.submission_terms is 'Texto canonico e versionado aceito em cada submissao.';
comment on table public.content_command_receipts is 'Recibos internos para retries idempotentes de autosave e submissao.';
comment on function public.save_own_content_draft is 'Salva agregado de rascunho completo com lock otimista e idempotencia.';
comment on function public.submit_own_content is 'Aceita termos e submete atomicamente, criando versao, historico e outbox.';
