# Execução da Etapa 5 — revisão, edição, agendamento e publicação

- Data: 2026-07-21
- Plano de origem: `../../../canarinho-docs/plano-de-acao-monolito-modular.md`
- Estado: implementada

## Escopo entregue

### Revisão

- fila privada com estados `submitted`, `under_review` e `changes_requested`;
- atribuição/retribuição por RPC, lock otimista e identificação do responsável;
- comentário geral vinculado à versão imutável e visível ao autor;
- solicitação de ajustes, aprovação, rejeição e reabertura pela Direção com justificativa;
- autoaprovação de Revisor bloqueada no PostgreSQL;
- histórico e eventos de outbox criados na mesma transação da decisão.

Comentários por trecho não entram no MVP: a decisão segue a recomendação do plano de exigir prova
de conceito para âncoras tolerantes a alterações. O formato atual permite acrescentá-los depois sem
transformar offsets frágeis em contrato.

### Edição, versão e publicação

- mesa do Editor para `approved`, `in_editing`, `scheduled`, `published` e `archived`;
- edição final de texto estruturado, título, subtítulo, resumo, categoria, tags, capa, SEO e tempo de
  leitura por comando transacional;
- comparação das duas versões recentes e restauração somente durante edição;
- snapshots antes/depois de alteração relevante pós-publicação;
- validação de autoria, categoria, conteúdo, SEO e capa pública com texto alternativo;
- agendamento futuro, cancelamento, worker idempotente em lote e ator de sistema explícito;
- publicação direta depois da aprovação e exceção exclusiva/auditada da Direção;
- arquivamento sem exclusão, republicação justificada e preservação do registro;
- destaque principal único trocado atomicamente.

## Rastreabilidade

| Requisito/regra         | Evidência principal                                                |
| ----------------------- | ------------------------------------------------------------------ |
| RF-030–035 / RN-020–024 | fila, detalhe, comentários, RPC de atribuição e máquina de estados |
| RF-040–041              | mesa editorial, editor TipTap e `save_editorial_content`           |
| RF-042                  | `publish_due_editorial_content` e runbook de agendamento           |
| RF-043 / RN-030–032     | validação de publicação e exceção auditada da Direção              |
| RF-044 / RN-035         | `set_primary_hero` com lock e substituição atômica                 |
| RF-045 / RN-033         | snapshots imutáveis, comparação e restauração controlada           |
| RF-046 / RN-034         | arquivamento/republicação; nenhum grant de exclusão permanente     |

## Evidências automatizadas

- `0005_stage_5_editorial_operations.test.sql`: 52 verificações de grants, RLS, comentários,
  transições, concorrência, edição, restauração, worker, exceção e curadoria;
- a suíte pgTAP completa soma 170 verificações, incluindo regressões das Etapas 1 a 4;
- Vitest cobre a matriz de ações visíveis por estado e papel;
- Playwright cobre Autor → Revisor → Editor → publicação → destaque e a negação do admin ao Leitor.

## Operação

O deploy deve configurar a chamada periódica descrita em
`docs/runbooks/publicacao-agendada.md`. Processamento efetivo de email/outbox permanece na Etapa 7;
a Etapa 5 garante que falha de notificação não bloqueia nem reverte a mudança editorial.
