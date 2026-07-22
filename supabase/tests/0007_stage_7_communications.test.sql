begin;

select no_plan();

select has_table('public', 'communication_notices', 'informes possuem agregado proprio');
select has_table('public', 'notice_comments', 'comentarios de informes existem');
select has_table('public', 'user_notifications', 'notificacoes internas existem');
select has_table('public', 'newsletter_subscribers', 'inscritos existem');
select has_table('public', 'newsletter_campaigns', 'campanhas existem');
select has_table('public', 'newsletter_deliveries', 'entregas idempotentes existem');
select has_table('public', 'newsletter_exports', 'exportacoes protegidas existem');
select has_function('public', 'save_communication_notice', 'comando de informe existe');
select has_function('public', 'subscribe_newsletter', 'inscricao publica existe');
select has_function('public', 'unsubscribe_newsletter', 'descadastro por token existe');
select has_function('public', 'claim_newsletter_batch', 'worker em lote existe');
select has_function('public', 'request_newsletter_export', 'exportacao auditada existe');
select is((select relrowsecurity from pg_class where oid = 'public.communication_notices'::regclass), true, 'RLS em informes');
select is((select relrowsecurity from pg_class where oid = 'public.newsletter_subscribers'::regclass), true, 'RLS em inscritos');
select is((select relrowsecurity from pg_class where oid = 'public.newsletter_deliveries'::regclass), true, 'RLS em entregas');

set local role anon;
select is((select count(*) from public.communication_notices), 1::bigint, 'visitante ve apenas informe publicado');
select throws_ok(
  $$select count(*) from public.newsletter_subscribers$$,
  '42501', null, 'visitante nao enumera emails'
);
select is(
  public.subscribe_newsletter(
    'NOVA.PESSOA@EXAMPLE.COM', 'newsletter-2026-01', 'pgtap', ''
  ),
  'pending_confirmation', 'visitante inicia double opt-in'
);
select is(
  public.subscribe_newsletter(
    'nova.pessoa@example.com', 'newsletter-2026-01', 'pgtap-retry', ''
  ),
  'pending_confirmation', 'retry normalizado reaproveita o mesmo inscrito'
);

reset role;
select is(
  (select count(*) from public.newsletter_subscribers where email = 'nova.pessoa@example.com'),
  1::bigint, 'email normalizado permanece unico'
);
select ok(
  (select confirmation_token_hash is not null and confirmation_expires_at > statement_timestamp()
    from public.newsletter_subscribers where email = 'nova.pessoa@example.com'),
  'banco armazena apenas hash e validade da confirmacao'
);
create temporary table confirmation_token_holder on commit drop as
select payload ->> 'confirmation_token' as token from public.outbox_events
where event_type = 'newsletter.confirmation_requested'
  and payload ->> 'email' = 'nova.pessoa@example.com'
order by created_at desc limit 1;
grant select on confirmation_token_holder to anon;

set local role anon;
select is(
  public.confirm_newsletter_subscription(
    (select token from confirmation_token_holder)
  ),
  true, 'token valido confirma inscricao'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000004', true);
select isnt(
  public.save_communication_notice(
    '71000000-0000-4000-8000-000000000099', 'Plantao de acolhimento',
    'plantao-de-acolhimento', 'Atendimento aberto para estudantes nesta semana.',
    'A equipe de acolhimento estara disponivel na sala do centro academico.',
    'students', true, statement_timestamp() + interval '10 days'
  ), null, 'Conexoes cria informe sem fluxo de materia'
);
select is(
  public.change_communication_notice_status(
    '71000000-0000-4000-8000-000000000099', 'publish', 'Divulgacao aprovada por Conexoes'
  ), 'published'::public.notice_status, 'Conexoes publica informe'
);
select is(
  public.set_communication_notice_pinned(
    '71000000-0000-4000-8000-000000000099', true, 'Plantao prioritario nesta semana'
  ), true, 'Conexoes fixa informe publicado'
);
select isnt(
  public.add_notice_comment(
    '71000000-0000-4000-8000-000000000099',
    'O atendimento tambem sera remoto?',
    '74000000-0000-4000-8000-000000000001'
  ), null, 'usuario autenticado comenta informe habilitado'
);
select throws_ok(
  $$select public.save_team_member(
    null, '61000000-0000-4000-8000-000000000004',
    'Acesso indevido', 'Conexoes', '', '', 9::smallint
  )$$,
  '42501', 'insufficient_privilege', 'Conexoes nao recebe gestao de equipe'
);
select is(
  (select count(*) from public.content_items where id = '31000000-0000-4000-8000-000000000101'),
  1::bigint, 'Conexoes preserva somente a leitura publica de materia publicada'
);
select is(
  (select count(*) from public.content_items where id = '31000000-0000-4000-8000-000000000199'),
  0::bigint, 'Conexoes nao ganha leitura indireta de rascunho editorial'
);

select isnt(
  public.save_newsletter_campaign(
    '73000000-0000-4000-8000-000000000099', 'Campanha pgTAP',
    'Assunto da campanha pgTAP', 'Uma previa curta',
    'Corpo da campanha com conteudo suficiente para envio.', 'all'
  ), null, 'Conexoes cria campanha'
);
select lives_ok(
  $$select public.schedule_newsletter_campaign(
    '73000000-0000-4000-8000-000000000099', statement_timestamp() + interval '1 hour',
    'Envio aprovado para o teste'
  )$$,
  'Conexoes agenda campanha futura'
);
select throws_ok(
  $$select public.request_newsletter_export('Tentativa de exportacao por Conexoes')$$,
  '42501', 'insufficient_privilege', 'Conexoes nao exporta sem autorizacao explicita'
);
select throws_ok(
  $$select public.claim_newsletter_batch(
    '73000000-0000-4000-8000-000000000099', 10
  )$$,
  '42501', null, 'cliente nao executa worker privilegiado'
);

reset role;
update public.newsletter_campaigns set scheduled_at = statement_timestamp() - interval '1 minute'
where id = '73000000-0000-4000-8000-000000000099';
set local role service_role;
create temporary table claimed_delivery on commit drop as
select * from public.claim_newsletter_batch('73000000-0000-4000-8000-000000000099', 20);
grant select on claimed_delivery to anon;
select ok((select count(*) >= 2 from claimed_delivery), 'lote inclui somente inscritos ativos elegiveis');
select is(
  (select count(distinct idempotency_key) from claimed_delivery),
  (select count(*) from claimed_delivery),
  'cada entrega possui chave de idempotencia estavel'
);

select lives_ok(
  $$select public.record_newsletter_delivery(
    (select delivery_id from claimed_delivery where email = 'nova.pessoa@example.com'),
    false, null, 'falha parcial simulada'
  )$$,
  'falha parcial vira retry sem desfazer outras entregas'
);
set local role anon;
select is(
  public.unsubscribe_newsletter(
    (select unsubscribe_token from claimed_delivery where email = 'nova.pessoa@example.com')
  ), true, 'token de entrega descadastra'
);
reset role;
select is(
  (select status from public.newsletter_subscribers where email = 'nova.pessoa@example.com'),
  'unsubscribed'::public.newsletter_subscriber_status,
  'descadastro muda o estado imediatamente'
);
select is(
  (select d.status from public.newsletter_deliveries d join public.newsletter_subscribers s
    on s.id = d.subscriber_id where s.email = 'nova.pessoa@example.com'
      and d.campaign_id = '73000000-0000-4000-8000-000000000099'),
  'skipped'::public.newsletter_delivery_status,
  'descadastrado sai ate de retry ja materializado'
);

reset role;
update public.communication_notices set
  published_at = statement_timestamp() - interval '2 days',
  expires_at = statement_timestamp() - interval '1 day'
where id = '71000000-0000-4000-8000-000000000099';
set local role service_role;
select is(public.expire_communication_notice_highlights(10), 1, 'job remove informe expirado do destaque');
reset role;
select is(
  (select status from public.communication_notices where id = '71000000-0000-4000-8000-000000000099'),
  'published'::public.notice_status, 'expiracao preserva pagina e historico'
);
select is(
  (select pinned from public.communication_notices where id = '71000000-0000-4000-8000-000000000099'),
  false, 'expiracao apenas desafixa'
);

insert into public.outbox_events (
  event_type, aggregate_type, aggregate_id, payload, idempotency_key
) values (
  'content.published', 'content', '31000000-0000-4000-8000-000000000101', '{}',
  'stage7-notification-test'
);
set local role service_role;
select is(public.process_editorial_notifications(10), 1, 'worker converte outbox em notificacao interna');
reset role;
select is(
  (select count(*) from public.user_notifications
    where recipient_id = '10000000-0000-4000-8000-000000000001'),
  1::bigint, 'autor recebe notificacao de publicacao'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', true);
select is((select count(*) from public.user_notifications), 1::bigint, 'usuario ve somente a propria caixa');
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', true);
select is((select count(*) from public.user_notifications), 0::bigint, 'outro usuario nao le notificacao alheia');

select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000005', true);
select isnt(
  public.request_newsletter_export('Auditoria de consentimentos para homologacao'),
  null, 'Diretor solicita exportacao'
);
select is((select count(*) from public.newsletter_exports), 1::bigint, 'Diretor enxerga somente exportacao propria');

reset role;
select is(
  (select count(*) from public.audit_logs where action like 'communications.%') >= 6,
  true, 'acoes sensiveis de comunicacao geram auditoria'
);

select * from finish();
rollback;
