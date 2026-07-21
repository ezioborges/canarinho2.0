# ADR 0002 — Conteúdo unificado e máquina editorial transacional

- Status: aceita
- Data: 2026-07-21
- Responsáveis: equipe de desenvolvimento do Canarinho

## Contexto

Notícias, artigos, colunas, poemas, ensaios, contos, arte e informes compartilham autoria,
taxonomia, versionamento e parte relevante do ciclo editorial. Tabelas independentes repetiriam
essas regras. Uma coluna de status atualizada diretamente pelo cliente, por outro lado, permitiria
estados inválidos, perda de histórico e disputas silenciosas de edição.

## Decisão

`content_items` é a raiz unificada do agregado. Autores, categorias, tags, edições, versões e
redirecionamentos são relações normalizadas. `body` e o snapshot de versão usam JSON somente para o
documento rich text estruturado e para sua representação imutável; relações de negócio não são
armazenadas em JSON.

O fluxo usa o enum `editorial_status` e o comando `transition_editorial_content`. O cliente não
recebe grant para atualizar `status`, responsáveis ou timestamps editoriais. Cada comando:

1. bloqueia a linha e compara `expected_lock_version`;
2. valida ator, origem, destino e pré-condições;
3. atualiza o estado e incrementa a versão otimista por trigger;
4. cria snapshot quando a transição é editorialmente relevante;
5. acrescenta histórico, auditoria e evento de outbox na mesma transação.

A matriz implementada nesta etapa é:

| Origem               | Destino solicitado  | Ator permitido                    |
| -------------------- | ------------------- | --------------------------------- |
| `draft`              | `submitted`         | autor                             |
| `changes_requested`  | `submitted`         | autor                             |
| `submitted`          | `under_review`      | Revisor ou Diretor                |
| `under_review`       | `changes_requested` | Revisor responsável ou Diretor    |
| `under_review`       | `approved`          | Revisor responsável ou Diretor    |
| `under_review`       | `rejected`          | Revisor responsável ou Diretor    |
| `approved`           | `in_editing`        | Editor ou Diretor                 |
| `in_editing`         | `scheduled`         | Editor ou Diretor                 |
| `in_editing`         | `published`         | Editor ou Diretor                 |
| `scheduled`          | `published`         | Editor ou Diretor, após o horário |
| `published`          | `archived`          | Editor ou Diretor                 |
| `rejected`           | `submitted`         | Diretor                           |
| estado não publicado | `published`         | Diretor, como exceção justificada |

A autoaprovação por Revisor é proibida. Exceção de Diretor exige o sinalizador explícito e motivo,
e produz a ação de auditoria `editorial.director_exception`.

## Alternativas consideradas

- Uma tabela por tipo: aumenta duplicação, joins e risco de fluxos divergentes.
- Status livre pela API: simplifica o primeiro formulário, mas desloca autorização e integridade
  para a interface.
- JSON para autores e taxonomia: reduz tabelas inicialmente, mas elimina integridade referencial e
  piora filtros, índices e RLS.

## Consequências

- O banco é a autoridade da máquina de estados, inclusive para chamadas diretas ao Supabase.
- Concorrência produz `stale_content_version`, não sobrescrita silenciosa.
- Novos estados ou transições exigem migration, teste pgTAP e atualização desta matriz.
- O job idempotente que efetivará agendamentos será acrescentado na Etapa 5; a transição já impede
  publicar antes do horário.
