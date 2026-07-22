# Etapa 7 — Informes, notificações e newsletter

Execução registrada em 2026-07-22.

## Escopo entregue

- quadro público e detalhe de informes, com comentários autenticados opcionais;
- gestão por Conexões/Diretor: rascunho, edição, publicação, fixação, expiração e arquivamento auditados;
- módulo sem dependência ou permissão indireta sobre matérias, poemas e edições;
- inscrição pública com email normalizado, consentimento versionado, double opt-in e anti-spam básico;
- confirmação e descadastro por tokens aleatórios armazenados somente como hash;
- listagem/inativação de inscritos por Conexões/Diretor e exportação exclusiva de Diretor;
- campanhas `draft/scheduled/sending/sent/failed/cancelled`, segmentos mínimos e entregas individualizadas;
- lotes com idempotência, cinco tentativas, backoff, retomada seletiva e revalidação do descadastro;
- Edge Function para provedor de email, processamento de outbox, campanhas e CSV privado;
- notificações internas derivadas dos eventos editoriais sem bloquear transições;
- exportações auditadas, armazenadas em bucket privado, baixadas por URL assinada de 60 segundos e removidas após 24 horas.

## Rastreabilidade

| Requisito  | Implementação principal                                   | Evidência                                 |
| ---------- | --------------------------------------------------------- | ----------------------------------------- |
| RF-025     | `user_notifications`, `process_editorial_notifications`   | pgTAP: outbox vira caixa do autor         |
| RF-050–053 | `communication_notices`, `notice_comments` e `/informes`  | pgTAP de RLS + E2E público/Conexões       |
| RF-070–072 | `newsletter_subscribers`, RPCs de confirmação/descadastro | pgTAP de normalização, hash e descadastro |
| RF-073     | painel de inscritos e `newsletter_exports`                | pgTAP de restrição + E2E Diretor          |
| RF-074     | `newsletter_campaigns`, `newsletter_deliveries`, worker   | pgTAP de lote, idempotência e retry       |
| RN-050–052 | agregado e job de expiração próprios                      | pgTAP preserva URL e remove fixação       |
| RN-060–063 | unicidade, revalidação, RLS, consentimento versionado     | pgTAP positivo e negativo                 |

## Limites de segurança

- tabelas administrativas não aceitam escrita direta de `anon` ou `authenticated`; comandos passam por RPCs protegidas;
- Conexões gerencia informes e inscritos, mas não recebe papéis editoriais;
- `service_role`, segredo de cron e chave do provedor existem somente na Edge Function;
- payloads de entrega não persistem o corpo da campanha, e erros são truncados/sanitizados;
- CSV não fica público e não é entregue diretamente pelo frontend.

## Validação local

```bash
pnpm db:reset
pnpm db:test
pnpm validate
pnpm test:e2e -- tests/e2e/stage-7-communications.spec.ts
```

O teste da Edge Function com provedor real depende das variáveis descritas em `.env.example`. Sem provedor configurado, o worker usa transporte local idempotente para homologação.
