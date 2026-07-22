begin;

select plan(35);

select has_table('public', 'submission_terms', 'termos versionados existem');
select has_table('public', 'content_media_assets', 'vinculo de anexos existe');
select has_table('public', 'content_command_receipts', 'recibos idempotentes existem');
select is(
  (select count(*) from pg_class where oid in (
    'public.submission_terms'::regclass,
    'public.content_media_assets'::regclass,
    'public.content_command_receipts'::regclass
  ) and relrowsecurity),
  3::bigint,
  'RLS esta ativa nas tres tabelas da etapa'
);
select has_trigger(
  'public', 'media_assets', 'media_assets_validate_private_upload',
  'metadados privados validam caminho, MIME e extensao'
);
select has_function('public', 'save_own_content_draft', 'comando de autosave existe');
select has_function('public', 'submit_own_content', 'comando de submissao existe');
select has_function('public', 'register_own_draft_asset', 'registro transacional de anexo existe');
select is(
  (select count(*) from public.submission_terms where version = '2026-07' and retired_at is null),
  1::bigint,
  'ha uma versao ativa dos termos'
);
select is(
  (select public from storage.buckets where id = 'content-drafts'),
  false,
  'bucket de rascunhos permanece privado'
);

set local role anon;
select is(
  (select count(*) from public.submission_terms where version = '2026-07'),
  1::bigint,
  'visitante pode ler os termos antes do cadastro'
);
select throws_ok(
  $$select count(*) from public.content_command_receipts$$,
  '42501', null,
  'recibos internos nao sao expostos ao visitante'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', true);

select is(
  (public.save_own_content_draft(
    '31000000-0000-4000-8000-000000000199',
    1,
    '40000000-0000-4000-8000-000000000001',
    'pauta-ainda-secreta-31000000',
    'news',
    'Pauta ainda secreta atualizada',
    'Subtitulo do rascunho',
    'Resumo privado do rascunho',
    '{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"Texto salvo pelo autor."}]}]}'::jsonb,
    '[{"profile_id":"10000000-0000-4000-8000-000000000001","display_name":null},{"profile_id":null,"display_name":"Coautora Externa"}]'::jsonb,
    '20000000-0000-4000-8000-000000000101',
    array['21000000-0000-4000-8000-000000000101']::uuid[],
    'Nota privada para a equipe'
  ) ->> 'lock_version')::integer,
  2,
  'autor salva o agregado proprio com lock otimista'
);
select is(
  (select count(*) from public.content_authors where content_id = '31000000-0000-4000-8000-000000000199'),
  2::bigint,
  'autosave preserva autores multiplos e ordem'
);
select is(
  (select count(*) from public.content_categories where content_id = '31000000-0000-4000-8000-000000000199' and is_primary),
  1::bigint,
  'autosave grava uma categoria principal'
);
select is(
  (select count(*) from public.content_tags where content_id = '31000000-0000-4000-8000-000000000199'),
  1::bigint,
  'autosave substitui tags atomicamente'
);
select is(
  (public.save_own_content_draft(
    '31000000-0000-4000-8000-000000000199',
    1,
    '40000000-0000-4000-8000-000000000001',
    'pauta-ainda-secreta-31000000',
    'news', 'Payload repetido', null, null,
    '{"type":"doc"}'::jsonb, '[]'::jsonb, null, '{}'::uuid[], null
  ) ->> 'lock_version')::integer,
  2,
  'retry com a mesma chave devolve o recibo sem nova escrita'
);
select is(
  (select count(*) from public.content_authors where content_id = '31000000-0000-4000-8000-000000000199'),
  2::bigint,
  'retry nao substitui relacoes pela segunda carga'
);
select throws_ok(
  $$select count(*) from public.content_command_receipts$$,
  '42501', null,
  'autor nao enumera recibos internos'
);
select ok(
  public.is_owned_draft_object_path(
    '10000000-0000-4000-8000-000000000001/31000000-0000-4000-8000-000000000199/40000000-0000-4000-8000-000000000099.pdf'
  ),
  'caminho previsivel do proprio rascunho e autorizado'
);
select isnt(
  public.is_owned_draft_object_path(
    '10000000-0000-4000-8000-000000000001/31000000-0000-4000-8000-000000000101/40000000-0000-4000-8000-000000000099.pdf'
  ),
  true,
  'autor nao usa caminho de conteudo que nao pode editar'
);
select throws_ok(
  $$insert into public.media_assets (
    owner_id, bucket_id, object_path, purpose, mime_type, byte_size, title
  ) values (
    '10000000-0000-4000-8000-000000000001', 'content-drafts',
    '10000000-0000-4000-8000-000000000001/invalido/arquivo.exe',
    'attachment', 'application/pdf', 100, 'Arquivo invalido'
  )$$,
  '23514', 'invalid_private_asset_path',
  'metadado recusa caminho ou extensao manipulados'
);

select is(
  (public.save_own_content_draft(
    '32000000-0000-4000-8000-000000000001', null,
    '40000000-0000-4000-8000-000000000002',
    'nova-submissao-32000000', 'essay', 'Nova submissao completa', null,
    'Resumo da nova submissao',
    '{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"Conteudo pronto para revisao."}]}]}'::jsonb,
    '[{"profile_id":"10000000-0000-4000-8000-000000000001","display_name":null}]'::jsonb,
    '20000000-0000-4000-8000-000000000101', '{}'::uuid[], null
  ) ->> 'lock_version')::integer,
  1,
  'novo rascunho usa UUID definido pelo cliente sem duplicar agregado'
);
select is(
  public.submit_own_content(
    '32000000-0000-4000-8000-000000000001', 1, '2026-07',
    '40000000-0000-4000-8000-000000000003'
  ) ->> 'status',
  'submitted',
  'aceite e transicao sao executados na mesma operacao'
);
select is(
  (select count(*) from public.content_versions where content_id = '32000000-0000-4000-8000-000000000001'),
  1::bigint,
  'submissao cria uma versao imutavel'
);
select is(
  (select count(*) from public.editorial_status_history where content_id = '32000000-0000-4000-8000-000000000001'),
  1::bigint,
  'submissao cria historico visivel ao autor'
);
select is(
  public.submit_own_content(
    '32000000-0000-4000-8000-000000000001', 1, '2026-07',
    '40000000-0000-4000-8000-000000000004'
  ) ->> 'status',
  'submitted',
  'segundo clique com outra chave converge para o estado atual'
);
select is(
  (select count(*) from public.content_versions where content_id = '32000000-0000-4000-8000-000000000001'),
  1::bigint,
  'segundo clique nao cria outra versao'
);
select is(
  (select count(*) from public.outbox_events),
  0::bigint,
  'autor nao le eventos da outbox'
);
select throws_ok(
  $$select public.save_own_content_draft(
    '32000000-0000-4000-8000-000000000001', 3,
    '40000000-0000-4000-8000-000000000005',
    'tentativa-de-edicao-32000000', 'essay', 'Tentativa de edicao', null, null,
    '{"type":"doc"}'::jsonb, '[]'::jsonb, null, '{}'::uuid[], null
  )$$,
  '42501', 'content_not_editable',
  'autor nao edita conteudo em revisao ativa'
);

reset role;
select is(
  (select count(*) from public.outbox_events where aggregate_id = '32000000-0000-4000-8000-000000000001'),
  1::bigint,
  'duplo clique produz somente um evento de submissao'
);
select is(
  (select terms_version from public.content_items where id = '32000000-0000-4000-8000-000000000001'),
  '2026-07',
  'conteudo guarda a versao exata dos termos aceitos'
);
select throws_ok(
  $$insert into public.media_assets (
    owner_id, bucket_id, object_path, purpose, mime_type, byte_size, title
  ) values (
    '10000000-0000-4000-8000-000000000001', 'content-drafts',
    '10000000-0000-4000-8000-000000000001/31000000-0000-4000-8000-000000000199/40000000-0000-4000-8000-000000000099.png',
    'inline_image', 'application/pdf', 100, 'MIME divergente'
  )$$,
  '23514', 'asset_extension_mime_mismatch',
  'banco recusa divergencia entre MIME e extensao'
);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change, email_change_token_new,
  is_sso_user, is_anonymous
) values (
  '00000000-0000-0000-0000-000000000000',
  '50000000-0000-4000-8000-000000000001',
  'authenticated', 'authenticated', 'nova-conta@local.canarinho.test', 'senha-local',
  statement_timestamp(), '{"provider":"email","providers":["email"]}'::jsonb,
  '{"display_name":"Nova Pessoa"}'::jsonb, statement_timestamp(), statement_timestamp(),
  '', '', '', '', false, false
);
select is(
  (select display_name from public.profiles where id = '50000000-0000-4000-8000-000000000001'),
  'Nova Pessoa',
  'cadastro cria perfil vinculado ao Auth'
);
select is(
  (select role_code::text from public.user_roles where user_id = '50000000-0000-4000-8000-000000000001'),
  'leitor',
  'cadastro concede apenas o papel minimo de leitor'
);

select * from finish();
rollback;
