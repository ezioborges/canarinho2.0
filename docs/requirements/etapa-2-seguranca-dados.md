# Execução da Etapa 2 — modelo de dados, RBAC, RLS e auditoria

- Data: 2026-07-21
- Plano de origem: `../../../canarinho-docs/plano-de-acao-monolito-modular.md`
- Estado: implementada e validada localmente

## Escopo entregue

A Etapa 2 foi implementada de forma incremental sobre a fundação, sem alterar a migration já
aplicada da Etapa 1.

### Modelo e integridade

- perfil ampliado com avatar, curso e vínculo opcional;
- email permanece canônico em `auth.users`, vinculado pelo mesmo UUID, sem cópia pública sujeita a
  divergência ou vazamento;
- conteúdo unificado e enums fechados de tipo, estado, visibilidade e motivo de versão;
- autores ordenados, categoria principal única, tags, edições e redirects de slug;
- metadados de mídia com proprietário, bucket, MIME, tamanho e texto alternativo;
- constraints, FKs, unicidade e índices para listagem pública e filas editoriais;
- `lock_version` incrementado em toda escrita para impedir sobrescrita silenciosa;
- versões, histórico, auditoria e outbox com índices operacionais.

### Fronteira de segurança

- RLS ativa nas 17 tabelas públicas desta fase;
- grants explícitos e negação por padrão para `anon` e `authenticated`;
- RBAC N:N consultado por helpers protegidos, sem metadados controlados pelo cliente;
- leitura de conteúdo por estado e papel; autoria própria preservada sem abrir filas;
- taxonomia e edições mutáveis somente por Editor/Diretor;
- auditoria e outbox visíveis somente para Diretor;
- buckets separados para rascunhos privados e mídia pública, com caminho iniciado pelo UUID do
  proprietário, allowlist de MIME e limite de 10 MiB.

### Comandos transacionais

- `assign_user_role` e `revoke_user_role`: exclusivos de Diretor, justificados e auditados;
- `assign_editorial_reviewer`: valida papel do responsável e lock otimista;
- `transition_editorial_content`: aplica a máquina de estados, impede autoaprovação, valida
  submissão/publicação e grava estado, versão, histórico, auditoria e outbox atomicamente;
- colunas críticas de status, responsáveis e datas não possuem grant de atualização direta.

## Decisões e rastreabilidade

- ADR 0002 registra conteúdo unificado, máquina de estados e concorrência;
- ADR 0003 registra RBAC, RLS, Storage, auditoria e outbox;
- `etapa-2-matriz-acesso.md` justifica leitura/escrita por papel e operação;
- migration `20260721000100_stage_2_domain_model.sql`: schema, constraints, índices e imutabilidade;
- migration `20260721000200_stage_2_authorization_workflows.sql`: helpers, RPCs, grants, policies e
  buckets;
- pgTAP `0002_stage_2_security_and_workflow.test.sql`: 51 verificações da fase, além das 12 da
  fundação.

| Requisito/regra | Evidência principal                                             |
| --------------- | --------------------------------------------------------------- |
| RF-002–004      | `profiles`, RBAC, policies e RPCs de papel                      |
| RF-013–015      | tipos, categorias, tags, edições e relações normalizadas        |
| RF-020–024      | conteúdo próprio, validação de submissão, versão e histórico    |
| RF-030–035      | fila por RLS, atribuição e transições de revisão                |
| RF-040–046      | fila de edição, validação de publicação, versões e arquivamento |
| RF-102 / RN-004 | auditoria append-only e leitura exclusiva de Diretor            |
| RN-001–005      | grants mínimos, RLS e testes por persona                        |
| RN-010–015      | autoria/estado, campos mínimos e Storage protegido              |
| RN-020–024      | aprovação, autoaprovação negada e histórico atômico             |
| RN-030–034      | publicação validada, exceção auditada e sem exclusão direta     |

## Limites conscientes

Esta etapa entrega a fronteira de dados e segurança, não as telas. Auth completo, formulário,
autosave e uploads via interface pertencem à Etapa 4; filas visuais e job automático de publicação
pertencem à Etapa 5. Comentários editoriais por versão serão modelados quando a prova de conceito do
editor definir a âncora estável. O modelo atual não simula offsets frágeis.

## Validação executada

Os comandos e resultados finais estão registrados após a execução completa:

| Comando         | Resultado                                          |
| --------------- | -------------------------------------------------- |
| `pnpm db:reset` | banco recriado integralmente por migrations e seed |
| `pnpm db:test`  | fundação e Etapa 2 aprovadas, 63 testes pgTAP      |
| `pnpm validate` | formato, lint, tipos, Vitest e build aprovados     |
