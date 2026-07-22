-- Etapa 3: read model publico, busca full-text, curadoria e redirects de slug.

create type public.content_placement_slot as enum ('hero', 'featured', 'gallery');

alter table public.content_items
  add column search_vector tsvector generated always as (
    setweight(to_tsvector('pg_catalog.portuguese', coalesce(title, '')), 'A')
    || setweight(to_tsvector('pg_catalog.portuguese', coalesce(subtitle, '')), 'B')
    || setweight(to_tsvector('pg_catalog.portuguese', coalesce(summary, '')), 'B')
    || setweight(to_tsvector('pg_catalog.portuguese', coalesce(body::text, '')), 'C')
  ) stored;

create index content_items_search_vector_idx
  on public.content_items using gin (search_vector)
  where status = 'published' and visibility = 'public' and deleted_at is null;

create table public.content_relationships (
  source_content_id uuid not null references public.content_items (id) on delete cascade,
  target_content_id uuid not null references public.content_items (id) on delete cascade,
  position smallint not null default 1 check (position > 0),
  created_by uuid not null references public.profiles (id) on delete restrict,
  created_at timestamptz not null default statement_timestamp(),
  primary key (source_content_id, target_content_id),
  constraint content_relationships_not_self check (source_content_id <> target_content_id),
  unique (source_content_id, position)
);
create index content_relationships_target_idx
  on public.content_relationships (target_content_id, source_content_id);

create table public.content_placements (
  id uuid primary key default gen_random_uuid(),
  content_id uuid not null references public.content_items (id) on delete cascade,
  slot public.content_placement_slot not null,
  position smallint not null check (position > 0),
  starts_at timestamptz,
  ends_at timestamptz,
  created_by uuid not null references public.profiles (id) on delete restrict,
  created_at timestamptz not null default statement_timestamp(),
  constraint content_placements_period_valid check (
    starts_at is null or ends_at is null or starts_at < ends_at
  ),
  unique (slot, position),
  unique (slot, content_id)
);
create index content_placements_active_idx
  on public.content_placements (slot, position, starts_at, ends_at);

alter table public.content_relationships enable row level security;
alter table public.content_placements enable row level security;

grant select on public.content_relationships, public.content_placements to anon, authenticated;
grant insert, update, delete on public.content_relationships, public.content_placements
  to authenticated;

create policy content_relationships_select_published
on public.content_relationships for select
to anon, authenticated
using (
  public.can_read_content(source_content_id)
  and public.can_read_content(target_content_id)
);

create policy content_relationships_manage_editorial
on public.content_relationships for all
to authenticated
using (public.has_any_role(array['editor', 'diretor']::public.app_role[]))
with check (public.has_any_role(array['editor', 'diretor']::public.app_role[]));

create policy content_placements_select_published
on public.content_placements for select
to anon, authenticated
using (public.can_read_content(content_id));

create policy content_placements_manage_editorial
on public.content_placements for all
to authenticated
using (public.has_any_role(array['editor', 'diretor']::public.app_role[]))
with check (public.has_any_role(array['editor', 'diretor']::public.app_role[]));

create function public.assert_content_slug_available()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  redirect_owner uuid;
begin
  select csr.content_id into redirect_owner
  from public.content_slug_redirects csr
  where csr.old_slug = new.slug;

  if redirect_owner is not null and redirect_owner <> new.id then
    raise exception using errcode = '23505', message = 'content_slug_reserved_by_redirect';
  end if;

  if redirect_owner = new.id then
    delete from public.content_slug_redirects where old_slug = new.slug;
  end if;

  return new;
end;
$$;

create trigger content_items_assert_slug_available
before insert or update of slug on public.content_items
for each row execute function public.assert_content_slug_available();

create function public.remember_published_content_slug()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.slug <> new.slug and old.published_at is not null then
    insert into public.content_slug_redirects (old_slug, content_id)
    values (old.slug, new.id)
    on conflict (old_slug) do update set content_id = excluded.content_id;
  end if;

  return new;
end;
$$;

create trigger content_items_remember_published_slug
after update of slug on public.content_items
for each row execute function public.remember_published_content_slug();

revoke all on function public.assert_content_slug_available() from public, anon, authenticated;
revoke all on function public.remember_published_content_slug() from public, anon, authenticated;

create function public.public_content_card(selected_content public.content_items)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', selected_content.id,
    'slug', selected_content.slug,
    'type', selected_content.type,
    'title', selected_content.title,
    'subtitle', selected_content.subtitle,
    'summary', selected_content.summary,
    'publishedAt', selected_content.published_at,
    'authors', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', ca.profile_id,
          'name', coalesce(ca.display_name, p.display_name)
        ) order by ca.position
      )
      from public.content_authors ca
      left join public.profiles p on p.id = ca.profile_id
      where ca.content_id = selected_content.id
    ), '[]'::jsonb),
    'categories', coalesce((
      select jsonb_agg(
        jsonb_build_object('name', c.name, 'slug', c.slug, 'isPrimary', cc.is_primary)
        order by cc.is_primary desc, c.name
      )
      from public.content_categories cc
      join public.categories c on c.id = cc.category_id
      where cc.content_id = selected_content.id and c.archived_at is null
    ), '[]'::jsonb),
    'tags', coalesce((
      select jsonb_agg(jsonb_build_object('name', t.name, 'slug', t.slug) order by t.name)
      from public.content_tags ct
      join public.tags t on t.id = ct.tag_id
      where ct.content_id = selected_content.id and t.archived_at is null
    ), '[]'::jsonb),
    'cover', (
      select jsonb_build_object(
        'objectPath', ma.object_path,
        'alt', ma.alt_text,
        'title', ma.title,
        'credit', ma.credit,
        'license', ma.license,
        'mimeType', ma.mime_type
      )
      from public.media_assets ma
      where ma.id = selected_content.cover_asset_id
        and ma.bucket_id = 'content-public'
        and ma.archived_at is null
    )
  );
$$;

create function public.list_published_content(
  search_query text default null,
  category_slug text default null,
  tag_slug text default null,
  author_id uuid default null,
  edition_slug text default null,
  content_kind public.content_type default null,
  published_from date default null,
  published_to date default null,
  page_size integer default 12,
  page_offset integer default 0
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with filtered as (
    select
      ci as content,
      ci.id,
      ci.published_at,
      case
        when nullif(trim(search_query), '') is null then 0::real
        else ts_rank_cd(
          ci.search_vector,
          websearch_to_tsquery('pg_catalog.portuguese', trim(search_query))
        )
      end as relevance
    from public.content_items ci
    where ci.status = 'published'
      and ci.visibility = 'public'
      and ci.deleted_at is null
      and ci.published_at is not null
      and (
        nullif(trim(search_query), '') is null
        or ci.search_vector @@ websearch_to_tsquery('pg_catalog.portuguese', trim(search_query))
      )
      and (content_kind is null or ci.type = content_kind)
      and (published_from is null or ci.published_at::date >= published_from)
      and (published_to is null or ci.published_at::date <= published_to)
      and (
        category_slug is null or exists (
          select 1
          from public.content_categories cc
          join public.categories c on c.id = cc.category_id
          where cc.content_id = ci.id and c.slug = category_slug and c.archived_at is null
        )
      )
      and (
        tag_slug is null or exists (
          select 1
          from public.content_tags ct
          join public.tags t on t.id = ct.tag_id
          where ct.content_id = ci.id and t.slug = tag_slug and t.archived_at is null
        )
      )
      and (
        author_id is null or exists (
          select 1 from public.content_authors ca
          where ca.content_id = ci.id and ca.profile_id = author_id
        )
      )
      and (
        edition_slug is null or exists (
          select 1
          from public.edition_items ei
          join public.editions e on e.id = ei.edition_id
          where ei.content_id = ci.id
            and e.slug = edition_slug
            and e.published_at is not null
            and e.archived_at is null
        )
      )
  ),
  paged as (
    select *
    from filtered
    order by relevance desc, published_at desc, id
    limit least(greatest(page_size, 1), 48)
    offset greatest(page_offset, 0)
  )
  select jsonb_build_object(
    'items', coalesce((
      select jsonb_agg(public.public_content_card(p.content) order by p.relevance desc, p.published_at desc)
      from paged p
    ), '[]'::jsonb),
    'total', (select count(*) from filtered)
  );
$$;

create function public.get_published_content(requested_slug text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select public.public_content_card(ci) || jsonb_build_object(
    'body', ci.body,
    'seoTitle', ci.seo_title,
    'seoDescription', ci.seo_description,
    'editions', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'title', e.title,
          'slug', e.slug,
          'issueNumber', e.issue_number
        ) order by e.published_at desc
      )
      from public.edition_items ei
      join public.editions e on e.id = ei.edition_id
      where ei.content_id = ci.id
        and e.published_at is not null
        and e.archived_at is null
    ), '[]'::jsonb),
    'related', coalesce((
      select jsonb_agg(public.public_content_card(related_content) order by cr.position)
      from public.content_relationships cr
      join public.content_items related_content on related_content.id = cr.target_content_id
      where cr.source_content_id = ci.id
        and related_content.status = 'published'
        and related_content.visibility = 'public'
        and related_content.deleted_at is null
    ), '[]'::jsonb)
  )
  from public.content_items ci
  where ci.slug = requested_slug
    and ci.status = 'published'
    and ci.visibility = 'public'
    and ci.deleted_at is null;
$$;

create function public.resolve_published_content_slug(requested_slug text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select ci.slug
  from public.content_slug_redirects csr
  join public.content_items ci on ci.id = csr.content_id
  where csr.old_slug = requested_slug
    and ci.status = 'published'
    and ci.visibility = 'public'
    and ci.deleted_at is null;
$$;

create function public.get_public_homepage()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'hero', (
      select public.public_content_card(ci)
      from public.content_items ci
      left join public.content_placements cp
        on cp.content_id = ci.id
        and cp.slot = 'hero'
        and (cp.starts_at is null or cp.starts_at <= statement_timestamp())
        and (cp.ends_at is null or cp.ends_at > statement_timestamp())
      where ci.status = 'published' and ci.visibility = 'public' and ci.deleted_at is null
      order by (cp.id is not null) desc, cp.position, ci.published_at desc
      limit 1
    ),
    'featured', coalesce((
      select jsonb_agg(public.public_content_card(selected.content) order by selected.position)
      from (
        select ci as content, cp.position
        from public.content_placements cp
        join public.content_items ci on ci.id = cp.content_id
        where cp.slot = 'featured'
          and (cp.starts_at is null or cp.starts_at <= statement_timestamp())
          and (cp.ends_at is null or cp.ends_at > statement_timestamp())
          and ci.status = 'published' and ci.visibility = 'public' and ci.deleted_at is null
        order by cp.position
        limit 4
      ) selected
    ), '[]'::jsonb),
    'recent', coalesce((
      select jsonb_agg(public.public_content_card(selected.content) order by selected.published_at desc)
      from (
        select ci as content, ci.published_at
        from public.content_items ci
        where ci.status = 'published' and ci.visibility = 'public' and ci.deleted_at is null
        order by ci.published_at desc
        limit 6
      ) selected
    ), '[]'::jsonb),
    'weekly', coalesce((
      select jsonb_agg(public.public_content_card(selected.content) order by selected.published_at desc)
      from (
        select ci as content, ci.published_at
        from public.content_items ci
        where ci.status = 'published' and ci.visibility = 'public' and ci.deleted_at is null
          and ci.type in ('weekly_article', 'column')
        order by ci.published_at desc
        limit 3
      ) selected
    ), '[]'::jsonb),
    'poems', coalesce((
      select jsonb_agg(public.public_content_card(selected.content) order by selected.published_at desc)
      from (
        select ci as content, ci.published_at
        from public.content_items ci
        where ci.status = 'published' and ci.visibility = 'public' and ci.deleted_at is null
          and ci.type in ('poem', 'short_story', 'essay')
        order by ci.published_at desc
        limit 3
      ) selected
    ), '[]'::jsonb),
    'gallery', coalesce((
      select jsonb_agg(public.public_content_card(selected.content) order by selected.position)
      from (
        select ci as content, cp.position
        from public.content_placements cp
        join public.content_items ci on ci.id = cp.content_id
        where cp.slot = 'gallery'
          and (cp.starts_at is null or cp.starts_at <= statement_timestamp())
          and (cp.ends_at is null or cp.ends_at > statement_timestamp())
          and ci.status = 'published' and ci.visibility = 'public' and ci.deleted_at is null
        order by cp.position
        limit 4
      ) selected
    ), '[]'::jsonb),
    'editions', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'title', e.title,
          'slug', e.slug,
          'summary', e.summary,
          'issueNumber', e.issue_number,
          'publishedAt', e.published_at
        ) order by e.published_at desc
      )
      from (
        select * from public.editions
        where published_at is not null and archived_at is null
        order by published_at desc
        limit 4
      ) e
    ), '[]'::jsonb)
  );
$$;

revoke all on function public.public_content_card(public.content_items) from public, anon, authenticated;
revoke all on function public.list_published_content(text, text, text, uuid, text, public.content_type, date, date, integer, integer) from public;
revoke all on function public.get_published_content(text) from public;
revoke all on function public.resolve_published_content_slug(text) from public;
revoke all on function public.get_public_homepage() from public;

grant execute on function public.list_published_content(text, text, text, uuid, text, public.content_type, date, date, integer, integer)
  to anon, authenticated;
grant execute on function public.get_published_content(text) to anon, authenticated;
grant execute on function public.resolve_published_content_slug(text) to anon, authenticated;
grant execute on function public.get_public_homepage() to anon, authenticated;

comment on column public.content_items.search_vector is
  'Documento full-text ponderado; titulo tem peso A, resumo/subtitulo B e corpo C.';
comment on function public.list_published_content is
  'Read model publico paginado; filtra explicitamente status, visibilidade e soft delete.';
comment on function public.get_published_content is
  'Detalhe publico agregado sem depender de joins montados no cliente.';
