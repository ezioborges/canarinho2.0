# ADR 0008 — Comunicações, consentimento e entregas retomáveis

## Status

Aceito em 2026-07-22.

## Contexto

Informes precisam ser operados por Conexões sem abrir o fluxo editorial. Newsletter envolve dados pessoais, confirmação, descadastro, integrações externas sujeitas a falhas e risco reputacional de envio duplicado. Notificações editoriais não podem bloquear mudanças de estado já concluídas.

## Decisão

- `communication_notices` é um agregado próprio, com RLS e comandos transacionais para salvar, publicar, fixar e arquivar.
- A expiração remove apenas o destaque; o informe publicado e sua URL permanecem preservados.
- Inscrições usam double opt-in. Emails são normalizados; tokens de confirmação e descadastro persistem somente como SHA-256.
- Cada destinatário de campanha recebe uma linha em `newsletter_deliveries` e uma chave de idempotência estável por campanha/inscrito.
- O worker revalida `newsletter_subscribers.status = active` ao materializar e ao reivindicar cada lote. Descadastro também marca retries pendentes como `skipped`.
- Falhas usam backoff e limite de cinco tentativas. Retomada reenfileira somente falhas elegíveis, preservando entregas `sent`.
- A Edge Function concentra credencial do provedor, `service_role`, geração de CSV e URLs assinadas. O cliente usa apenas JWT do usuário.
- Exportações são exclusivas de Diretor, auditadas, privadas e expiram em 24 horas.
- Eventos editoriais existentes viram notificações internas por consumo assíncrono da outbox.

## Consequências

O banco é a fonte de verdade de consentimento e entrega, e uma indisponibilidade do provedor não reverte operações editoriais. A aplicação precisa agendar o worker e monitorar falhas permanentes. Segmentação inicial permanece deliberadamente pequena (`all`, `students`, `authors`).
