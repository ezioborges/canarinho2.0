begin;

select plan(52);

select has_table('public', 'editorial_comments', 'comentarios editoriais por versao existem');
select has_type('public', 'editorial_actor_kind', 'historico distingue usuario e sistema');
select has_column('public', 'content_items', 'reading_time_minutes', 'tempo de leitura pode ser editado');
select is(
  (select relrowsecurity from pg_class where oid = 'public.editorial_comments'::regclass),
  true,
  'RLS esta ativa nos comentarios editoriais'
);
select has_function('public', 'add_editorial_comment', 'comando protegido de comentario existe');
select has_function('public', 'save_editorial_content', 'edicao final transacional existe');
select has_function('public', 'restore_editorial_version', 'restauracao controlada existe');
select has_function('public', 'set_primary_hero', 'curadoria atomica do hero existe');
select has_function('public', 'publish_due_editorial_content', 'worker de agenda existe');

insert into public.media_assets (
  id, owner_id, bucket_id, object_path, purpose, mime_type, byte_size,
  title, alt_text, credit, license
) values (
  '45000000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000003',
  'content-public',
  '10000000-0000-4000-8000-000000000003/capas/etapa-cinco.webp',
  'cover', 'image/webp', 4096, 'Capa da etapa cinco',
  'Equipe reunida ao redor de uma mesa de edição.', 'Equipe Canarinho', 'CC BY-NC 4.0'
);

insert into public.content_items (
  id, slug, type, title, summary, body, status, visibility, submitted_by,
  terms_version, terms_accepted_at, submitted_at
) values (
  '35000000-0000-4000-8000-000000000001',
  'fluxo-editorial-etapa-cinco', 'essay', 'Fluxo editorial da etapa cinco',
  'Uma pauta completa para validar revisão, edição, agenda e publicação.',
  '{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"Texto original para a revisão editorial."}]}]}'::jsonb,
  'submitted', 'public', '10000000-0000-4000-8000-000000000001',
  '2026-07', statement_timestamp(), statement_timestamp()
);
insert into public.content_authors (content_id, position, profile_id)
values (
  '35000000-0000-4000-8000-000000000001', 1,
  '10000000-0000-4000-8000-000000000001'
);
insert into public.content_categories (content_id, category_id, is_primary)
values (
  '35000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000101', true
);
insert into public.content_versions (
  id, content_id, version_number, reason, snapshot, created_by
) values (
  '36000000-0000-4000-8000-000000000001',
  '35000000-0000-4000-8000-000000000001', 1, 'submission',
  public.snapshot_content('35000000-0000-4000-8000-000000000001'),
  '10000000-0000-4000-8000-000000000001'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', true);
select throws_ok(
  $$select public.publish_due_editorial_content(25)$$,
  '42501', null,
  'cliente autenticado nao executa o worker privilegiado'
);

select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', true);
select is(
  public.assign_editorial_reviewer(
    '35000000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000002', 1,
    'Revisao assumida pela pessoa responsavel'
  ),
  2,
  'revisor assume a pauta com lock otimista'
);
select isnt(
  public.add_editorial_comment(
    '35000000-0000-4000-8000-000000000001',
    '36000000-0000-4000-8000-000000000001',
    'O argumento precisa explicitar melhor a fonte principal.'
  ),
  null,
  'revisor responsavel comenta a versao imutavel'
);
select is(
  (select count(*) from public.editorial_comments
    where content_id = '35000000-0000-4000-8000-000000000001'),
  1::bigint,
  'comentario fica vinculado ao conteudo'
);
select is(
  (select count(*) from public.outbox_events
    where aggregate_id = '35000000-0000-4000-8000-000000000001'
      and event_type = 'review.comment_added'),
  0::bigint,
  'revisor nao ganha leitura da fila interna ao comentar'
);
select throws_ok(
  $$select public.add_editorial_comment(
    '35000000-0000-4000-8000-000000000001',
    '36000000-0000-4000-8000-000000000099',
    'Tentativa na versao errada'
  )$$,
  '23503', 'version_does_not_belong_to_content',
  'comentario nao pode apontar para versao de outro contexto'
);

select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', true);
select is(
  (select count(*) from public.editorial_comments
    where content_id = '35000000-0000-4000-8000-000000000001'),
  1::bigint,
  'autor le o retorno editorial permitido'
);
select throws_ok(
  $$insert into public.editorial_comments (content_id, version_id, author_id, body)
    values (
      '35000000-0000-4000-8000-000000000001',
      '36000000-0000-4000-8000-000000000001',
      '10000000-0000-4000-8000-000000000001', 'Comentario forjado pelo autor'
    )$$,
  '42501', null,
  'autor nao forja comentario editorial por insert direto'
);

reset role;
select is(
  (select count(*) from public.outbox_events
    where aggregate_id = '35000000-0000-4000-8000-000000000001'
      and event_type = 'review.comment_added'),
  1::bigint,
  'comentario cria notificacao desacoplada na outbox'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', true);
select is(
  public.transition_editorial_content(
    '35000000-0000-4000-8000-000000000001', 'approved', 2,
    'Parecer favoravel apos verificacao das fontes'
  ),
  3,
  'revisor responsavel aprova com justificativa'
);

select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', true);
select is(
  public.transition_editorial_content(
    '35000000-0000-4000-8000-000000000001', 'in_editing', 3,
    'Inicio da preparacao para publicacao'
  ),
  4,
  'editor assume a edicao com lock otimista'
);
select throws_ok(
  $$update public.content_items
    set title = 'Edicao sem snapshot'
    where id = '35000000-0000-4000-8000-000000000001'$$,
  '42501', null,
  'editor nao contorna versionamento por update direto'
);
select throws_ok(
  $$select public.transition_editorial_content(
    '35000000-0000-4000-8000-000000000001', 'published', 4,
    'Tentativa antes dos metadados obrigatorios'
  )$$,
  '23514', 'content_missing_publication_requirements',
  'publicacao incompleta e bloqueada no banco'
);
select is(
  public.save_editorial_content(
    '35000000-0000-4000-8000-000000000001', 4,
    'Fluxo editorial da etapa cinco revisado',
    'Da submissao ao portal sem perder o historico',
    'Uma pauta pronta para demonstrar o ciclo editorial completo.',
    '{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"Texto final preparado pela edicao."}]}]}'::jsonb,
    '20000000-0000-4000-8000-000000000101',
    array['21000000-0000-4000-8000-000000000101']::uuid[],
    '45000000-0000-4000-8000-000000000001',
    'Fluxo editorial completo no Canarinho',
    'Veja como uma pauta passa por revisao, edicao, agenda e publicacao.',
    4,
    'Edicao final de texto e metadados'
  ),
  5,
  'edicao final salva o agregado completo'
);
select is(
  (select reading_time_minutes from public.content_items
    where id = '35000000-0000-4000-8000-000000000001'),
  4,
  'tempo de leitura faz parte da edicao final'
);
select is(
  (select count(*) from public.content_versions
    where content_id = '35000000-0000-4000-8000-000000000001'),
  3::bigint,
  'submissao, aprovacao e edicao possuem snapshots'
);
select throws_ok(
  $$select public.save_editorial_content(
    '35000000-0000-4000-8000-000000000001', 4,
    'Sobrescrita obsoleta', '', '', '{"type":"doc"}'::jsonb,
    null, '{}'::uuid[], null, '', '', 1, 'Payload de outra aba'
  )$$,
  '40001', 'stale_content_version',
  'segunda pessoa nao sobrescreve uma edicao mais nova'
);
select is(
  public.restore_editorial_version(
    '35000000-0000-4000-8000-000000000001',
    '36000000-0000-4000-8000-000000000001', 5,
    'Restauracao controlada para comparar o texto original'
  ),
  6,
  'editor restaura uma versao apenas durante edicao'
);
select is(
  (select count(*) from public.content_versions
    where content_id = '35000000-0000-4000-8000-000000000001'),
  5::bigint,
  'restauracao preserva o antes e o depois'
);

-- A restauracao voltou aos metadados da submissao; a edicao os completa novamente.
select is(
  public.save_editorial_content(
    '35000000-0000-4000-8000-000000000001', 6,
    'Fluxo editorial da etapa cinco pronto', '',
    'Versao final pronta para ser agendada.',
    '{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"Conteudo restaurado e finalizado."}]}]}'::jsonb,
    '20000000-0000-4000-8000-000000000101', '{}'::uuid[],
    '45000000-0000-4000-8000-000000000001',
    'Fluxo editorial pronto para publicar',
    'Versao final validada para a publicacao agendada.', 3,
    'Finalizacao depois da comparacao de versoes'
  ),
  7,
  'conteudo restaurado pode ser finalizado novamente'
);
select is(
  public.transition_editorial_content(
    '35000000-0000-4000-8000-000000000001', 'scheduled', 7,
    'Publicacao programada para a janela editorial',
    statement_timestamp() + interval '1 hour'
  ),
  8,
  'editor agenda somente conteudo completo para data futura'
);
select ok(
  (select scheduled_at > statement_timestamp() from public.content_items
    where id = '35000000-0000-4000-8000-000000000001'),
  'agendamento futuro fica registrado'
);

reset role;
update public.content_items
set scheduled_at = statement_timestamp() - interval '1 minute'
where id = '35000000-0000-4000-8000-000000000001';

select is(public.publish_due_editorial_content(25), 1, 'job publica a pauta vencida uma vez');
select is(
  (select status::text from public.content_items
    where id = '35000000-0000-4000-8000-000000000001'),
  'published',
  'job move a pauta para publicada'
);
select is(
  (select count(*) from public.editorial_status_history
    where content_id = '35000000-0000-4000-8000-000000000001'
      and actor_kind = 'system' and actor_label = 'job:publish-scheduled'),
  1::bigint,
  'historico identifica explicitamente o job'
);
select is(
  (select count(*) from public.content_versions
    where content_id = '35000000-0000-4000-8000-000000000001'
      and actor_kind = 'system' and reason = 'publication'),
  1::bigint,
  'job cria snapshot de publicacao identificado'
);
select is(public.publish_due_editorial_content(25), 0, 'retry do job nao republica a mesma pauta');
select is(
  (select count(*) from public.outbox_events
    where aggregate_id = '35000000-0000-4000-8000-000000000001'
      and event_type = 'content.published'),
  1::bigint,
  'retry nao duplica evento de publicacao'
);
select throws_ok(
  $$select public.publish_due_editorial_content(101)$$,
  '22023', 'invalid_batch_size',
  'worker limita o tamanho do lote'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', true);
select is(
  public.save_editorial_content(
    '35000000-0000-4000-8000-000000000001', 10,
    'Fluxo editorial atualizado depois da publicacao', '',
    'Correcao editorial relevante e versionada.',
    '{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"Correcao transparente depois da publicacao."}]}]}'::jsonb,
    '20000000-0000-4000-8000-000000000101', '{}'::uuid[],
    '45000000-0000-4000-8000-000000000001',
    'Fluxo editorial atualizado', 'Correcao editorial registrada no historico.', 3,
    'Correcao de clareza depois da publicacao'
  ),
  11,
  'alteracao pos-publicacao passa pelo comando versionado'
);
select is(
  (select count(*) from public.content_versions
    where content_id = '35000000-0000-4000-8000-000000000001'),
  10::bigint,
  'edicao publicada guarda estado anterior e estado corrigido'
);
select throws_ok(
  $$select public.restore_editorial_version(
    '35000000-0000-4000-8000-000000000001',
    '36000000-0000-4000-8000-000000000001', 11,
    'Tentativa de restaurar sem voltar para edicao'
  )$$,
  '42501', 'restoration_requires_editing_state',
  'restauracao nao altera publicacao ao vivo fora do estado de edicao'
);
select is(
  public.transition_editorial_content(
    '35000000-0000-4000-8000-000000000001', 'archived', 11,
    'Arquivamento editorial sem exclusao permanente'
  ),
  12,
  'editor arquiva sem apagar o registro'
);
select is(
  public.transition_editorial_content(
    '35000000-0000-4000-8000-000000000001', 'published', 12,
    'Republicacao aprovada depois da revisao do arquivo'
  ),
  13,
  'conteudo arquivado pode ser republicado de forma auditada'
);
select ok(
  (select published_at is not null and archived_at is null
    from public.content_items where id = '35000000-0000-4000-8000-000000000001'),
  'republicacao renova data publica e limpa arquivamento'
);
select isnt(
  public.set_primary_hero(
    '35000000-0000-4000-8000-000000000001',
    'Nova prioridade editorial da pagina inicial'
  ),
  null,
  'editor troca o destaque principal por comando atomico'
);
select is(
  (select count(*) from public.content_placements where slot = 'hero' and position = 1),
  1::bigint,
  'home conserva um unico destaque principal'
);
select is(
  (select content_id from public.content_placements where slot = 'hero' and position = 1),
  '35000000-0000-4000-8000-000000000001'::uuid,
  'novo destaque substitui o anterior'
);

reset role;
insert into public.content_items (
  id, slug, type, title, body, status, visibility, submitted_by,
  cover_asset_id, seo_title, seo_description, terms_version, terms_accepted_at
) values (
  '35000000-0000-4000-8000-000000000002',
  'excecao-da-direcao', 'news', 'Publicacao excepcional da Direcao',
  '{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"Conteudo urgente validado pela Direcao."}]}]}'::jsonb,
  'draft', 'public', '10000000-0000-4000-8000-000000000001',
  '45000000-0000-4000-8000-000000000001',
  'Publicacao excepcional da Direcao',
  'Conteudo urgente publicado com motivo e auditoria.',
  '2026-07', statement_timestamp()
);
insert into public.content_authors (content_id, position, profile_id)
values (
  '35000000-0000-4000-8000-000000000002', 1,
  '10000000-0000-4000-8000-000000000001'
);
insert into public.content_categories (content_id, category_id, is_primary)
values (
  '35000000-0000-4000-8000-000000000002',
  '20000000-0000-4000-8000-000000000101', true
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000005', true);
select is(
  public.transition_editorial_content(
    '35000000-0000-4000-8000-000000000002', 'published', 1,
    'Comunicado urgente validado diretamente pela Direcao', null, true
  ),
  2,
  'Diretor publica por excecao explicita'
);
select is(
  (select count(*) from public.audit_logs
    where target_id = '35000000-0000-4000-8000-000000000002'
      and action = 'editorial.director_exception'),
  1::bigint,
  'excecao da Direcao possui auditoria especifica'
);
select is(
  (select count(*) from public.content_versions
    where content_id = '35000000-0000-4000-8000-000000000002'
      and reason = 'publication'),
  1::bigint,
  'excecao da Direcao tambem cria versao de publicacao'
);
select is(
  (select count(*) from public.outbox_events
    where aggregate_id = '35000000-0000-4000-8000-000000000002'
      and event_type = 'content.published'),
  1::bigint,
  'falha futura de notificacao nao faz parte da transacao editorial ja concluida'
);
select throws_ok(
  $$select public.transition_editorial_content(
    '35000000-0000-4000-8000-000000000002', 'archived', 1,
    'Comando concorrente com versao antiga'
  )$$,
  '40001', 'stale_content_version',
  'lock tambem protege excecao e arquivamento concorrentes'
);

select * from finish();
rollback;
