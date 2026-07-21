begin;

select plan(51);

-- Estrutura, integridade e RLS.
select ok(to_regtype('public.content_type') is not null, 'enum content_type existe');
select ok(to_regtype('public.editorial_status') is not null, 'enum editorial_status existe');
select has_table('public', 'content_items', 'tabela raiz de conteudo existe');
select has_table('public', 'content_authors', 'relacao de autores existe');
select has_table('public', 'categories', 'categorias existem');
select has_table('public', 'content_versions', 'versoes existem');
select has_table('public', 'editorial_status_history', 'historico editorial existe');
select has_table('public', 'audit_logs', 'auditoria existe');
select has_table('public', 'outbox_events', 'outbox existe');
select has_table('public', 'media_assets', 'metadados de Storage existem');
select has_trigger(
  'public',
  'content_versions',
  'content_versions_immutable',
  'versoes possuem trigger de imutabilidade'
);
select has_trigger(
  'public',
  'audit_logs',
  'audit_logs_immutable',
  'auditoria possui trigger de imutabilidade'
);
select is(
  (
    select count(*)
    from pg_class
    where oid in (
      'public.profiles'::regclass,
      'public.roles'::regclass,
      'public.user_roles'::regclass,
      'public.categories'::regclass,
      'public.tags'::regclass,
      'public.editions'::regclass,
      'public.media_assets'::regclass,
      'public.content_items'::regclass,
      'public.content_authors'::regclass,
      'public.content_categories'::regclass,
      'public.content_tags'::regclass,
      'public.edition_items'::regclass,
      'public.content_slug_redirects'::regclass,
      'public.content_versions'::regclass,
      'public.editorial_status_history'::regclass,
      'public.audit_logs'::regclass,
      'public.outbox_events'::regclass
    ) and relrowsecurity
  ),
  17::bigint,
  'RLS esta ativa em todas as tabelas expostas'
);
select is(
  (select count(*) from storage.buckets where id in ('content-drafts', 'content-public')),
  2::bigint,
  'buckets privado e publico foram configurados'
);
select is(
  (
    select count(*)
    from pg_indexes
    where schemaname = 'public'
      and indexname in (
        'content_items_public_listing_idx',
        'content_items_submission_queue_idx',
        'content_categories_one_primary_uidx'
      )
  ),
  3::bigint,
  'indices de consulta e integridade existem'
);

-- Fixtures controladas: as policies serao exercitadas depois de trocar para os papeis da API.
insert into public.categories (id, name, slug, created_by)
values (
  '20000000-0000-4000-8000-000000000001',
  'Internacional',
  'internacional',
  '10000000-0000-4000-8000-000000000003'
);

insert into public.content_items (
  id, slug, type, title, body, status, visibility, submitted_by,
  terms_version, terms_accepted_at, submitted_at, approved_at, published_at,
  seo_title, seo_description
)
values
  (
    '30000000-0000-4000-8000-000000000001', 'rascunho-leitor', 'news',
    'Rascunho do leitor', '{"type":"doc","content":[{"type":"paragraph"}]}'::jsonb,
    'draft', 'public', '10000000-0000-4000-8000-000000000001',
    '2026-01', statement_timestamp(), null, null, null, null, null
  ),
  (
    '30000000-0000-4000-8000-000000000002', 'submissao-leitor', 'essay',
    'Submissao do leitor', '{"type":"doc","content":[{"type":"paragraph"}]}'::jsonb,
    'submitted', 'public', '10000000-0000-4000-8000-000000000001',
    '2026-01', statement_timestamp(), statement_timestamp(), null, null, null, null
  ),
  (
    '30000000-0000-4000-8000-000000000003', 'submissao-revisor', 'column',
    'Submissao do revisor', '{"type":"doc","content":[{"type":"paragraph"}]}'::jsonb,
    'submitted', 'public', '10000000-0000-4000-8000-000000000002',
    '2026-01', statement_timestamp(), statement_timestamp(), null, null, null, null
  ),
  (
    '30000000-0000-4000-8000-000000000004', 'conteudo-publicado', 'poem',
    'Conteudo publicado', '{"type":"doc","content":[{"type":"paragraph"}]}'::jsonb,
    'published', 'public', '10000000-0000-4000-8000-000000000003',
    '2026-01', statement_timestamp(), statement_timestamp(), statement_timestamp(),
    statement_timestamp(), 'Conteudo publicado', 'Descricao publica do conteudo'
  );

insert into public.content_authors (content_id, position, profile_id)
select id, 1, submitted_by from public.content_items
where id::text like '30000000-0000-4000-8000-%';

insert into public.content_categories (content_id, category_id, is_primary)
select id, '20000000-0000-4000-8000-000000000001', true
from public.content_items
where id::text like '30000000-0000-4000-8000-%';

insert into public.outbox_events (
  event_type, aggregate_type, aggregate_id, idempotency_key
) values (
  'internal.test_event',
  'content',
  '30000000-0000-4000-8000-000000000002',
  'stage-2-private-event'
);

-- Visitante: somente o que e explicitamente publico.
set local role anon;
select is(
  (select count(*) from public.content_items where id::text like '30000000-%'),
  1::bigint,
  'visitante le somente conteudo publicado'
);
select is(
  (select title from public.content_items where id = '30000000-0000-4000-8000-000000000004'),
  'Conteudo publicado',
  'conteudo nao publicado nao vaza para visitante'
);
select is(
  (select count(*) from public.profiles where id = '10000000-0000-4000-8000-000000000003'),
  1::bigint,
  'visitante le somente perfil ligado a conteudo publicado'
);
select throws_ok(
  $$select count(*) from public.content_versions$$,
  '42501',
  null,
  'visitante nao possui grant para versoes internas'
);

-- Leitor: proprio conteudo, propria atribuicao e nenhuma fila/auditoria.
set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', true);
select is(
  (select count(*) from public.content_items where id::text like '30000000-%'),
  3::bigint,
  'leitor ve os dois conteudos proprios e o publicado'
);
select is((select count(*) from public.user_roles), 1::bigint, 'leitor ve somente os proprios papeis');
select is((select count(*) from public.audit_logs), 0::bigint, 'leitor nao le auditoria');
select is((select count(*) from public.outbox_events), 0::bigint, 'leitor nao le fila interna');
select results_eq(
  $$update public.content_items
    set title = 'Rascunho atualizado'
    where id = '30000000-0000-4000-8000-000000000001'
    returning 1$$,
  $$values (1)$$,
  'autor edita o proprio rascunho'
);
select is_empty(
  $$update public.content_items
    set title = 'Tentativa indevida'
    where id = '30000000-0000-4000-8000-000000000002'
    returning 1$$,
  'autor nao edita conteudo em revisao'
);
select throws_ok(
  $$update public.content_items set status = 'published' where id = '30000000-0000-4000-8000-000000000001'$$,
  '42501',
  null,
  'status nao pode ser alterado diretamente pelo cliente'
);
select throws_ok(
  $$select public.assign_user_role(
    '10000000-0000-4000-8000-000000000001', 'editor', 'tentativa do leitor'
  )$$,
  '42501',
  'insufficient_privilege',
  'leitor nao promove papeis'
);
select throws_ok(
  $$insert into public.user_roles (user_id, role_code)
    values ('10000000-0000-4000-8000-000000000001', 'diretor')$$,
  '42501',
  null,
  'atribuicao direta de papel nao possui grant'
);

-- Conexoes: nenhum acesso indireto ao fluxo editorial.
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000004', true);
select is(
  (select count(*) from public.content_items where id::text like '30000000-%'),
  1::bigint,
  'Conexoes le apenas o publicado'
);
select is_empty(
  $$update public.content_items
    set title = 'Tentativa de Conexoes'
    where id = '30000000-0000-4000-8000-000000000004'
    returning 1$$,
  'Conexoes nao edita materia editorial'
);

-- Revisor: fila, atribuicao segura, controle otimista e vedacao de autoaprovacao.
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', true);
select is(
  (select count(*) from public.content_items where id::text like '30000000-%'),
  3::bigint,
  'revisor le fila e conteudo publicado'
);
select is(
  public.assign_editorial_reviewer(
    '30000000-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000002',
    1,
    'Assumindo a revisao'
  ),
  2,
  'revisor assume conteudo com lock otimista'
);
select throws_ok(
  $$select public.assign_editorial_reviewer(
    '30000000-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000002',
    1,
    'Versao antiga'
  )$$,
  '40001',
  'stale_content_version',
  'versao concorrente obsoleta e rejeitada'
);
select is(
  public.assign_editorial_reviewer(
    '30000000-0000-4000-8000-000000000003',
    '10000000-0000-4000-8000-000000000002',
    1,
    'Assumindo conteudo proprio para testar bloqueio'
  ),
  2,
  'atribuicao do proprio texto nao implica permissao de aprovar'
);
select throws_ok(
  $$select public.transition_editorial_content(
    '30000000-0000-4000-8000-000000000003',
    'approved',
    2,
    'Eu aprovaria meu proprio texto'
  )$$,
  '42501',
  'reviewer_cannot_approve_own_content',
  'revisor nao autoaprova'
);
select is(
  public.transition_editorial_content(
    '30000000-0000-4000-8000-000000000002',
    'approved',
    2,
    'Conteudo revisado e aprovado'
  ),
  3,
  'revisor responsavel aprova conteudo de outra pessoa'
);

-- Editor: somente estados editoriais, publicacao validada e sem update de status livre.
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', true);
select is(
  (
    select count(*) from public.content_items
    where id = '30000000-0000-4000-8000-000000000002'
  ),
  1::bigint,
  'editor enxerga conteudo aprovado'
);
select is(
  public.transition_editorial_content(
    '30000000-0000-4000-8000-000000000002',
    'in_editing',
    3,
    'Inicio da edicao final'
  ),
  4,
  'editor inicia edicao por transicao valida'
);
select throws_ok(
  $$select public.transition_editorial_content(
    '30000000-0000-4000-8000-000000000002',
    'published',
    4,
    'Tentativa sem capa nem SEO'
  )$$,
  '23514',
  'content_missing_publication_requirements',
  'editor nao publica conteudo incompleto'
);

insert into public.media_assets (
  id, owner_id, bucket_id, object_path, purpose, mime_type, byte_size, alt_text
) values (
  '40000000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000003',
  'content-public',
  '10000000-0000-4000-8000-000000000003/capas/submissao-leitor.webp',
  'cover',
  'image/webp',
  2048,
  'Assembleia estudantil no campus'
);

update public.content_items
set cover_asset_id = '40000000-0000-4000-8000-000000000001',
    seo_title = 'Submissao do leitor',
    seo_description = 'Uma descricao editorial valida para publicacao.'
where id = '30000000-0000-4000-8000-000000000002';

select is(
  public.transition_editorial_content(
    '30000000-0000-4000-8000-000000000002',
    'published',
    5,
    'Edicao final validada para publicacao'
  ),
  6,
  'editor publica conteudo completo'
);

-- Diretor: auditoria e gestao protegida de papeis.
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000005', true);
select ok((select count(*) from public.audit_logs) >= 5, 'Diretor le a trilha de auditoria');
select ok((select count(*) from public.outbox_events) >= 3, 'Diretor le eventos internos da outbox');
select is(
  (select count(*) from public.content_versions where content_id = '30000000-0000-4000-8000-000000000002'),
  2::bigint,
  'aprovacao e publicacao geram versoes imutaveis'
);
select is(
  (select count(*) from public.editorial_status_history where content_id = '30000000-0000-4000-8000-000000000002'),
  4::bigint,
  'atribuicao, aprovacao, edicao e publicacao geram historico'
);
select is_empty(
  $$update public.content_items
    set title = 'Alteracao direta pos-publicacao'
    where id = '30000000-0000-4000-8000-000000000002'
    returning 1$$,
  'nem Diretor contorna versionamento ao editar publicacao diretamente'
);
select lives_ok(
  $$select public.assign_user_role(
    '10000000-0000-4000-8000-000000000001', 'editor', 'Promocao aprovada pela Direcao'
  )$$,
  'Diretor atribui papel por RPC auditada'
);
select is(
  (select count(*) from public.user_roles where user_id = '10000000-0000-4000-8000-000000000001'),
  2::bigint,
  'multiplicidade de papeis e preservada'
);
select lives_ok(
  $$select public.revoke_user_role(
    '10000000-0000-4000-8000-000000000001', 'editor', 'Fim da atribuicao temporaria'
  )$$,
  'Diretor revoga papel por RPC auditada'
);
select throws_ok(
  $$select public.revoke_user_role(
    '10000000-0000-4000-8000-000000000005', 'diretor', 'Remocao do ultimo Diretor'
  )$$,
  '23514',
  'last_director_cannot_be_removed',
  'ultimo Diretor nao pode ser removido'
);

reset role;
select throws_ok(
  $$update public.content_versions set reason = 'editing' where content_id = '30000000-0000-4000-8000-000000000002'$$,
  '55000',
  'content_versions is append-only',
  'nem o owner altera uma versao imutavel'
);
select throws_ok(
  $$delete from public.audit_logs$$,
  '55000',
  'audit_logs is append-only',
  'nem o owner apaga auditoria'
);

select * from finish();
rollback;
