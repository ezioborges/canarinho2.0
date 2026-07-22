begin;

select plan(20);

select has_column('public', 'content_items', 'search_vector', 'conteudo possui documento full-text');
select has_table('public', 'content_relationships', 'relacionamentos de conteudo existem');
select has_table('public', 'content_placements', 'curadoria da home existe');
select is(
  (
    select count(*) from pg_indexes
    where schemaname = 'public' and indexname = 'content_items_search_vector_idx'
  ),
  1::bigint,
  'busca full-text possui indice GIN parcial'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.content_relationships'::regclass),
  'relacionamentos possuem RLS'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.content_placements'::regclass),
  'destaques possuem RLS'
);
select has_function('public', 'list_published_content', 'RPC de listagem publica existe');
select has_function('public', 'get_published_content', 'RPC de detalhe publico existe');

insert into public.content_relationships (
  source_content_id, target_content_id, position, created_by
) values (
  '31000000-0000-4000-8000-000000000199',
  '31000000-0000-4000-8000-000000000101',
  1,
  '10000000-0000-4000-8000-000000000003'
);

update public.content_items
set slug = 'campus-em-movimento-renovado'
where id = '31000000-0000-4000-8000-000000000101';

set local role anon;

select is(
  (public.list_published_content(page_size => 48) ->> 'total')::integer,
  6,
  'listagem retorna somente os seis conteudos publicados'
);
select is(
  (public.list_published_content(search_query => 'segredo editorial') ->> 'total')::integer,
  0,
  'busca nunca retorna rascunho'
);
select is(
  (public.list_published_content(search_query => 'ciência') ->> 'total')::integer,
  1,
  'busca em portugues encontra conteudo publicado'
);
select is(
  (public.list_published_content(category_slug => 'cultura') ->> 'total')::integer,
  3,
  'filtro por categoria funciona'
);
select is(
  (public.list_published_content(tag_slug => 'literatura') ->> 'total')::integer,
  2,
  'filtro por tag funciona'
);
select is(
  public.get_published_content('pauta-ainda-secreta'),
  null::jsonb,
  'detalhe nao revela conteudo nao publicado'
);
select is(
  public.get_published_content('campus-em-movimento-renovado') ->> 'title',
  'Um campus que se move com quem chega',
  'detalhe agrega o conteudo publicado'
);
select is(
  jsonb_array_length(
    public.get_published_content('campus-em-movimento-renovado') -> 'related'
  ),
  2,
  'detalhe inclui sugestoes relacionadas publicadas'
);
select is(
  public.resolve_published_content_slug('campus-em-movimento'),
  'campus-em-movimento-renovado',
  'slug anterior resolve para a URL canonica'
);
select is(
  public.get_public_homepage() #>> '{hero,slug}',
  'campus-em-movimento-renovado',
  'home prioriza o destaque editorial ativo'
);
select is(
  (select count(*) from public.content_relationships),
  5::bigint,
  'RLS oculta relacionamento cuja origem nao foi publicada'
);
select is(
  (select count(*) from public.content_items),
  6::bigint,
  'consulta direta anonima tambem so le publicados'
);

select * from finish();

rollback;
