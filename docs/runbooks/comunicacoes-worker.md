# Runbook — worker de comunicações

## Agendamento

Invocar `communications-worker` a cada minuto com `POST`, corpo `{"action":"all","batchSize":50}` e header `x-cron-secret`. Configure `COMMUNICATIONS_CRON_SECRET`, `SITE_URL`, `EMAIL_PROVIDER_URL`, `EMAIL_PROVIDER_API_KEY` e `EMAIL_FROM` como secrets da Edge Function.

## Falha de email

1. Verifique campanhas `sending/failed`, entregas `failed`, `attempts`, `next_attempt_at` e o erro sanitizado.
2. Confirme a saúde do provedor sem copiar emails para tickets ou logs.
3. Corrija a integração e use “Retomar somente falhas”. Entregas `sent` não são reenfileiradas.
4. Não altere inscritos descadastrados. O worker os converte em `skipped` antes do retry.

## Exportações

Solicitações ficam `pending` até o worker gerar o CSV. Downloads usam URL assinada por 60 segundos. O job marca arquivos com mais de 24 horas como `expired` e remove o objeto do bucket privado.

## Informe expirado ainda fixado

Execute a ação `all` ou chame `expire_communication_notice_highlights` com credencial de serviço. A rotina é idempotente e preserva a página pública.
