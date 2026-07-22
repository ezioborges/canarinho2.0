# ADR 0006 — Operação editorial versionada e publicação agendada

- Status: aceita
- Data: 2026-07-21
- Responsáveis: equipe de desenvolvimento do Canarinho

## Contexto

A máquina de estados da Etapa 2 protegia as transições, mas ainda não oferecia a operação diária de
Revisores e Editores. A Etapa 5 precisava acrescentar pareceres, edição final, restauração,
agendamento e curadoria sem reintroduzir atualização livre de estado ou disputas silenciosas.

## Decisão

- comentários editoriais do MVP são gerais e sempre apontam para uma `content_version` imutável;
- comentários ancorados em trecho ficam adiados até uma prova de conceito demonstrar âncoras
  estáveis entre versões;
- toda edição final usa `save_editorial_content`, compara `lock_version`, substitui taxonomia na
  mesma transação e cria snapshot;
- restauração só ocorre em `in_editing`; o estado anterior e o restaurado permanecem versionados;
- uma edição relevante após publicação preserva snapshots anterior e posterior;
- o worker `publish_due_editorial_content` usa lote limitado e `FOR UPDATE SKIP LOCKED`; somente
  `service_role` pode invocá-lo pela API;
- ações do worker usam ator `system` e rótulo explícito no histórico/versão, sem atribuí-las
  falsamente a uma pessoa;
- Editor ou Diretor pode cancelar um agendamento, arquivar e republicar com justificativa;
- somente Diretor usa publicação por exceção, que também cria versão, outbox e auditoria específica;
- a troca do destaque principal passa por `set_primary_hero` e advisory lock, substituindo o hero
  anterior atomicamente.

## Consequências

A interface pode falhar ou ser contornada sem enfraquecer as invariantes. Dois operadores usando a
mesma versão recebem `stale_content_version`. Uma falha posterior do processador de notificações não
reverte a transição porque o evento já foi gravado na outbox. O agendador precisa ser configurado em
cada ambiente conforme o runbook e monitorado por auditoria/outbox.
