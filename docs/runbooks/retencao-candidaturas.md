# Retenção de candidaturas

## Objetivo

Eliminar dados pessoais quando `recruitment_applications.retention_expires_at` vencer. O prazo é
copiado da chamada no momento da candidatura e não muda retroativamente.

## Agendamento

Execute diariamente, com credencial `service_role`, a RPC:

```sql
select public.purge_expired_recruitment_applications(100);
```

Repita enquanto o retorno for `100`. Clientes `anon` e `authenticated` não possuem permissão de
execução. Nunca exponha a chave de serviço no navegador.

## Verificação

1. Consulte a quantidade vencida antes do job em ambiente protegido.
2. Execute lotes pequenos e registre duração/quantidade, sem nome ou email.
3. Confirme que não restaram linhas vencidas.
4. Em falha, preserve o erro sanitizado e tente novamente; a exclusão por chave primária é
   naturalmente idempotente.

## Incidente

Se o job ficar indisponível, suspenda novas chamadas com retenção incompatível, registre o período
afetado e processe os vencidos assim que o serviço retornar. Não exporte os dados como mecanismo de
backup informal.
