begin;

select no_plan();

select has_table('public', 'public_comments', 'comentarios publicos existem');
select has_table('public', 'comment_moderation_history', 'historico de moderacao existe');
select has_table('public', 'comment_reports', 'denuncias existem');
select has_table('public', 'content_favorites', 'favoritos persistentes existem');
select has_table('public', 'team_areas', 'eixos da equipe existem');
select has_table('public', 'team_members', 'membros da equipe existem');
select has_table('public', 'recruitment_openings', 'chamadas de recrutamento existem');
select has_table('public', 'recruitment_applications', 'candidaturas privadas existem');
select has_function('public', 'add_public_comment', 'comando protegido de comentario existe');
select has_function('public', 'list_public_comments', 'paginacao publica de comentarios existe');
select has_function('public', 'report_public_comment', 'denuncia protegida existe');
select has_function('public', 'moderate_public_comment', 'moderacao auditada existe');
select has_function('public', 'set_content_favorite', 'favorito persistente existe');
select has_function('public', 'list_public_team', 'read model seguro da equipe existe');
select has_function('public', 'submit_recruitment_application', 'envio protegido de candidatura existe');
select has_function('public', 'purge_expired_recruitment_applications', 'job de retencao existe');
select lives_ok(
  $$select public.assert_content_ready_for_publication(
    '31000000-0000-4000-8000-000000000105'
  )$$,
  'producao visual seed possui metadados completos'
);
select is((select relrowsecurity from pg_class where oid = 'public.public_comments'::regclass), true, 'RLS em comentarios');
select is((select relrowsecurity from pg_class where oid = 'public.comment_reports'::regclass), true, 'RLS em denuncias');
select is((select relrowsecurity from pg_class where oid = 'public.content_favorites'::regclass), true, 'RLS em favoritos');
select is((select relrowsecurity from pg_class where oid = 'public.recruitment_applications'::regclass), true, 'RLS em candidaturas');

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', true);
select isnt(
  public.add_public_comment(
    '31000000-0000-4000-8000-000000000101',
    'A pauta ajuda a enxergar o campus de outro jeito.',
    '64000000-0000-4000-8000-000000000001'
  ), null, 'leitor autenticado comenta conteudo publicado'
);
select is(
  (select count(*) from public.public_comments
    where content_id = '31000000-0000-4000-8000-000000000101'),
  1::bigint, 'comentario e persistido'
);
select is(
  public.add_public_comment(
    '31000000-0000-4000-8000-000000000101',
    'A pauta ajuda a enxergar o campus de outro jeito.',
    '64000000-0000-4000-8000-000000000001'
  ),
  (select id from public.public_comments
    where idempotency_key = '64000000-0000-4000-8000-000000000001'),
  'retry devolve o mesmo comentario'
);
select throws_ok(
  $$select public.add_public_comment(
    '31000000-0000-4000-8000-000000000101',
    'A pauta ajuda a enxergar o campus de outro jeito.',
    '64000000-0000-4000-8000-000000000002'
  )$$,
  '23505', 'duplicate_comment', 'texto repetido em uma hora e bloqueado'
);
select throws_ok(
  $$select public.add_public_comment(
    '31000000-0000-4000-8000-000000000199', 'Tentativa no rascunho privado.',
    '64000000-0000-4000-8000-000000000003'
  )$$,
  '42501', 'comments_not_available', 'rascunho nao recebe comentario publico'
);
select throws_ok(
  $$insert into public.public_comments (
    content_id, author_id, body, idempotency_key
  ) values (
    '31000000-0000-4000-8000-000000000101',
    '10000000-0000-4000-8000-000000000001', 'Insert direto',
    '64000000-0000-4000-8000-000000000004'
  )$$,
  '42501', null, 'cliente nao contorna RPC por insert direto'
);
select is(
  (select status from public.content_items
    where id = '31000000-0000-4000-8000-000000000101'),
  'published'::public.editorial_status,
  'comentario nao altera o estado editorial'
);
select is(
  jsonb_array_length(public.list_public_comments(
    '31000000-0000-4000-8000-000000000101', null, null, 20
  ) -> 'items'),
  1, 'read model lista comentario visivel'
);

select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', true);
select isnt(
  public.report_public_comment(
    (select id from public.public_comments limit 1),
    'O texto pode expor uma pessoa sem necessidade.'
  ), null, 'usuario autenticado denuncia comentario'
);
select isnt(
  public.report_public_comment(
    (select id from public.public_comments limit 1),
    'Motivo atualizado para a mesma denuncia.'
  ),
  null,
  'segunda denuncia do mesmo usuario atualiza sem duplicar'
);
select is((select count(*) from public.comment_reports), 0::bigint, 'denunciante nao enumera a fila de denuncias');

select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', true);
select is(
  public.moderate_public_comment(
    (select id from public.public_comments limit 1), 'hide',
    'Ocultado preventivamente durante a analise da denuncia.'
  ), 'hidden'::public.public_comment_status, 'Editor oculta com motivo'
);
select is((select count(*) from public.comment_moderation_history), 1::bigint, 'acao preservada no historico');
select is((select count(*) from public.comment_reports where status = 'reviewed'), 1::bigint, 'denuncia resolvida pela moderacao');
select is(
  jsonb_array_length(public.list_public_comments(
    '31000000-0000-4000-8000-000000000101', null, null, 20
  ) -> 'items'),
  0, 'comentario oculto sai da listagem publica'
);
select is(
  public.moderate_public_comment(
    (select id from public.public_comments limit 1), 'restore',
    'Analise concluida sem violacao das diretrizes.'
  ), 'visible'::public.public_comment_status, 'Editor restaura com motivo'
);
select is(
  public.moderate_public_comment(
    (select id from public.public_comments limit 1), 'remove',
    'Remocao logica apos confirmacao da violacao.'
  ), 'removed'::public.public_comment_status, 'Editor remove logicamente'
);

reset role;
select is((select count(*) from public.public_comments), 1::bigint, 'remocao preserva o registro original');
select is((select count(*) from public.comment_moderation_history), 3::bigint, 'toda transicao de moderacao permanece');
select is((select count(*) from public.audit_logs where action = 'community.comment_moderated'), 3::bigint, 'moderacao gera auditoria');

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', true);
select is(public.set_content_favorite('31000000-0000-4000-8000-000000000104', true), true, 'leitor favorita poema');
select is((select count(*) from public.content_favorites), 1::bigint, 'leitor enxerga o proprio favorito');
select is(jsonb_array_length(public.list_own_favorites()), 1, 'lista propria retorna card publico');
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', true);
select is((select count(*) from public.content_favorites), 0::bigint, 'outro usuario nao enxerga favoritos alheios');
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', true);
select is(public.set_content_favorite('31000000-0000-4000-8000-000000000104', false), false, 'leitor desfavorita');

reset role;
set local role anon;
select is(jsonb_array_length(public.list_public_team()), 4, 'equipe publica e agrupada por eixo');
select is((select count(*) from public.team_members), 4::bigint, 'anonimo ve somente membros ativos');
select throws_ok(
  $$insert into public.team_members (
    area_id, display_name, role_title, position
  ) values (
    '61000000-0000-4000-8000-000000000001', 'Pessoa forjada', 'Diretora', 10
  )$$,
  '42501', null, 'anonimo nao cria membro'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000005', true);
select isnt(
  public.save_team_member(
    '62000000-0000-4000-8000-000000000099',
    '61000000-0000-4000-8000-000000000004',
    'Nova Pessoa', 'Colaboradora', 'Bio publica da nova integrante.', null, 2::smallint
  ), null, 'Diretor inclui membro'
);
select is((select count(*) from public.team_members where active), 5::bigint, 'novo membro aparece para Direcao');
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', true);
select throws_ok(
  $$select public.save_team_member(
    null, '61000000-0000-4000-8000-000000000002',
    'Sem permissao', 'Editora', '', '', 3::smallint
  )$$,
  '42501', 'insufficient_privilege', 'Editor nao gere equipe institucional'
);
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000005', true);
select lives_ok(
  $$select public.archive_team_member(
    '62000000-0000-4000-8000-000000000099', 'Fim do ciclo da colaboracao'
  )$$,
  'Diretor inativa sem apagar'
);

set local role anon;
select is((select count(*) from public.team_members), 4::bigint, 'membro inativo deixa a pagina publica');
select is((select count(*) from public.recruitment_openings), 1::bigint, 'chamada publicada e publica');
select isnt(
  public.submit_recruitment_application(
    '63000000-0000-4000-8000-000000000001', 'Pessoa Candidata',
    'CANDIDATA@EXAMPLE.COM', 'Estudante de RI',
    'Quero colaborar com a revisao e aprender com a equipe.',
    'recrutamento-2026-01', ''
  ), null, 'visitante envia candidatura com consentimento'
);
select throws_ok(
  $$select count(*) from public.recruitment_applications$$,
  '42501', null, 'anonimo nao possui sequer grant de leitura de candidaturas'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', true);
select is((select count(*) from public.recruitment_applications), 0::bigint, 'Leitor nao acessa dados de candidatura');
select throws_ok(
  $$select public.update_recruitment_application(
    (select id from public.recruitment_applications limit 1), 'in_review', 'Analise indevida'
  )$$,
  '42501', 'insufficient_privilege', 'Leitor nao atualiza candidatura'
);
select throws_ok(
  $$select public.purge_expired_recruitment_applications(10)$$,
  '42501', null, 'cliente nao executa job de retencao'
);

select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000005', true);
select is((select count(*) from public.recruitment_applications), 1::bigint, 'somente Diretor le candidatura');
select lives_ok(
  $$select public.update_recruitment_application(
    (select id from public.recruitment_applications limit 1), 'in_review',
    'Perfil encaminhado para leitura da Direcao'
  )$$,
  'Diretor registra parecer'
);
select ok(
  (select bool_and(retention_expires_at > created_at)
    from public.recruitment_applications),
  'candidatura recebe prazo de expiracao'
);

reset role;
select is(
  (select count(*) from public.audit_logs where action like 'organization.%'),
  3::bigint, 'gestao de equipe e candidatura e auditada'
);

select * from finish();
rollback;
