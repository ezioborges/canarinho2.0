# Runbook — publicação agendada

## Objetivo

Publicar conteúdos `scheduled` cujo `scheduled_at` já foi atingido, sem duplicar versão, histórico
ou evento quando houver retry ou workers concorrentes.

## Configuração

O job deve executar a cada minuto em ambiente protegido, usando `service_role` apenas no servidor:

```sql
select public.publish_due_editorial_content(25);
```

O token nunca entra no navegador nem em variável `NEXT_PUBLIC_*`. Supabase Cron pode chamar uma
Edge Function protegida, ou um agendador equivalente pode invocar a RPC. A função aceita lotes de 1
a 100 itens e usa `SKIP LOCKED` para dividir trabalho concorrente.

## Verificação

1. confirme que o item permanece `scheduled` e que `scheduled_at <= now()`;
2. procure `editorial.scheduled_published` ou `editorial.schedule_failed` em `audit_logs`;
3. confirme uma versão `publication` com `actor_kind = system`;
4. confirme um único evento `content.published` na outbox;
5. execute o job novamente: o retorno deve ser `0` se não houver outro item vencido.

Falha de validação mantém a matéria agendada e registra erro sanitizado. Corrija capa, autoria,
categoria, SEO ou conteúdo, cancele o agendamento pela mesa editorial, salve a correção e agende
novamente. Não altere `status` diretamente.
