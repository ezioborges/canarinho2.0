# Execução da Etapa 6 — comunidade, mídia, equipe e recrutamento

- Data: 2026-07-22
- Plano de origem: `../../../canarinho-docs/plano-de-acao-monolito-modular.md`
- Estado: implementada

## Escopo entregue

### Comunidade e favoritos

- comentários autenticados, cursor estável, limite de página, idempotência, bloqueio de texto
  repetido e limites de frequência;
- diretrizes visíveis antes da participação;
- denúncias únicas por usuário e comentário, com fila privada;
- ocultação, restauração e remoção lógica por Editor/Diretor, sempre com motivo, ator, data,
  histórico imutável e auditoria;
- favoritos persistentes e privados por usuário para qualquer conteúdo publicado;
- página “Favoritos” na conta.

### Mídia e produções artísticas

- galeria pública específica para `artwork` e página dedicada a poemas;
- reaproveitamento do agregado editorial já versionado para título, descrição, autoria, tags, data,
  capa, texto alternativo, crédito, licença, arquivamento, SEO e detalhe;
- itens privados ou arquivados continuam fora do read model público.

### Equipe e recrutamento

- página pública de equipe agrupada por eixos extensíveis;
- inclusão, ordenação e inativação auditadas, exclusivas da Direção;
- página “Faça parte” com descrição, requisitos, processo, contato e chamadas publicadas;
- formulário de candidatura com validação, campo anti-bot, limite por email, consentimento
  versionado e data de expiração;
- candidaturas sem grant para `anon`, invisíveis a Leitor/Revisor/Editor/Conexões e acessíveis
  somente à Direção;
- parecer e mudança de status auditados;
- função de serviço em lotes para eliminação ao vencer a retenção.

## Rastreabilidade

| Requisito/regra          | Evidência principal                                            |
| ------------------------ | -------------------------------------------------------------- |
| RF-016                   | `/galeria`, metadados de `media_assets` e agregado `artwork`   |
| RF-017                   | `/poemas`, autoria, tags, destaque e detalhe editorial         |
| RF-018                   | `content_favorites`, RPC e `/favoritos`                        |
| RF-060 / RN-040 / RN-043 | RPC autenticada, listagem paginada e teste de estado editorial |
| RF-061 / RN-041–042      | moderação protegida, histórico append-only e `audit_logs`      |
| RF-062                   | `comment_reports` e fila de moderação privada                  |
| RF-063                   | idempotência, duplicata, limites por janela e honeypot         |
| RF-090–091               | read model `/equipe` e gestão exclusiva da Direção             |
| RF-092–093               | `/faca-parte`, consentimento, RLS e retenção                   |

## Evidências automatizadas

- `0006_stage_6_community_media_organization.test.sql`: 64 verificações de schema, grants, RLS,
  comandos, moderação, favoritos, equipe, candidaturas e retenção;
- a suíte pgTAP completa soma 234 verificações com regressão das Etapas 1–5;
- Playwright cobre a jornada pública de galeria/equipe/candidatura e a jornada
  Leitor → comentário/favorito → Editor/moderação.

## Decisão de escopo

Candidaturas foram priorizadas nesta execução. Favoritos locais de visitante não foram incluídos
porque o critério final recomenda persistência por usuário e a experiência autenticada evita
sincronização ambígua. Imagens adicionais de uma mesma produção continuam vinculáveis por
`content_media_assets`; a capa permanece a imagem principal do card público.
