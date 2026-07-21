# Execução da Etapa 3 — conteúdo publicado no portal

- Data: 2026-07-21
- Plano de origem: `../../../canarinho-docs/plano-de-acao-monolito-modular.md`
- Estado: implementada e validada localmente; homologação visual/editorial permanece externa

## Valor entregue

O projeto deixou de exibir a página de fundação e passou a oferecer uma fatia pública completa,
alimentada pelo Supabase local:

- home editorial com hero curado, destaques, artigos, literatura, galeria, edição e chamada para a
  futura newsletter;
- arquivo paginado com busca e filtros de tipo e data;
- rotas navegáveis por categoria, tag, autor e edição;
- detalhe com documento rich text, autoria, data, categoria, tags, capa, crédito, licença, tempo de
  leitura, compartilhamento e sugestões relacionadas;
- estados de carregamento, vazio, erro e 404;
- conteúdo seed editorial fictício com seis publicações, uma edição, mídia e um rascunho negativo.

## Banco e fronteira pública

A migration `20260721000300_stage_3_public_portal.sql` adiciona:

- `search_vector` gerado e índice GIN parcial para conteúdo público;
- `content_relationships` para sugestões ordenadas;
- `content_placements` para hero, destaques e galeria;
- triggers de reserva e histórico de slug publicado;
- RPCs de home, listagem/busca, detalhe e redirect.

As RPCs usam condição positiva completa — `published`, `public` e `deleted_at is null` — mesmo
executando como definer. O teste negativo usa um rascunho que contém o termo “segredo editorial” e
comprova que ele não aparece na consulta direta, RPC, busca, detalhe ou sitemap.

## SEO, mídia e cache

- `metadataBase`, títulos, descrições, canonical, Open Graph, Twitter Card e JSON-LD de artigo;
- sitemap derivado exclusivamente do read model público;
- `robots.txt` bloqueia todo crawler fora de produção e, em produção, libera o portal enquanto
  bloqueia `/admin` e `/conta`;
- capas responsivas com `next/image`, dimensões reservadas, `sizes`, texto alternativo, crédito e
  licença;
- ilustrações locais do seed são assets versionados; uploads reais continuarão usando o bucket
  `content-public`;
- home/listagens: revalidação em 300 s; detalhe/redirect: 3.600 s; busca livre: `no-store`.

## Acessibilidade e desempenho preventivo

- link para pular conteúdo, landmarks, labels e navegação semântica;
- foco visível de alto contraste e alvos de interação identificados;
- hierarquia de títulos e datas com elemento `time`;
- preferência `prefers-reduced-motion` respeitada;
- layout responsivo sem ocultar conteúdo e espaço de imagem reservado para reduzir CLS;
- documento rich text renderizado por allowlist, sem HTML editorial injetado;
- página principal pré-renderizada e consultas sem N+1.

Como a Etapa 0 ainda não registrou um orçamento aprovado, ficam propostos para a homologação em
hardware móvel mediano: LCP ≤ 2,5 s, CLS ≤ 0,1, INP ≤ 200 ms e nenhuma violação crítica de
acessibilidade automatizada. A medição Lighthouse/axe em navegador real e o aceite de contraste
visual devem entrar no ambiente de homologação, não são inferidos do build local.

## Rastreabilidade

| Requisito | Evidência desta etapa                                      | Observação                                              |
| --------- | ---------------------------------------------------------- | ------------------------------------------------------- |
| RF-010    | home, placements e seed público                            | chamada de newsletter não coleta dados antes da Etapa 7 |
| RF-011    | RPC full-text, filtros, paginação e arquivo                | categoria/tag/autor/edição possuem rotas próprias       |
| RF-012    | detalhe agregado, rich text, mídia, leitura e relacionados | implementado                                            |
| RF-013    | oito tipos fechados e apresentação por tipo                | modelo veio da Etapa 2                                  |
| RF-014    | categorias/tags visíveis e filtráveis                      | gestão administrativa entra na Etapa 5                  |
| RF-015    | edição pública e agrupamento de itens                      | gestão administrativa entra na Etapa 5                  |
| RF-016    | chamada e item artístico com mídia completa                | galeria completa pertence à Etapa 6                     |
| RF-017    | poema e arte usam detalhe e filtros próprios               | implementado no read model unificado                    |
| RF-018    | fora da fatia da Etapa 3                                   | favoritos persistentes permanecem na Etapa 6 do plano   |
| RF-019    | canonical, OG, Twitter, JSON-LD, sitemap e robots          | implementado                                            |

## Validação executada

| Comando/verificação | Resultado                                                                                      |
| ------------------- | ---------------------------------------------------------------------------------------------- |
| `pnpm db:reset`     | migrations e seed recriados desde zero                                                         |
| `pnpm db:test`      | 83 verificações pgTAP aprovadas                                                                |
| `pnpm format:check` | aprovado                                                                                       |
| `pnpm lint`         | aprovado sem warnings                                                                          |
| `pnpm typecheck`    | aprovado em TypeScript estrito                                                                 |
| `pnpm test`         | 8 testes Vitest aprovados                                                                      |
| `pnpm build`        | build de produção aprovado; home e sitemap pré-renderizados                                    |
| smoke HTTP          | home, arquivo, busca, detalhe, sitemap e robots responderam; rascunho ausente de busca/sitemap |

## Limites conscientes

Favoritos, galeria completa e gestão editorial das entidades continuam nas etapas 5 e 6, conforme o
plano original. A invalidação instantânea do cache será conectada à RPC de publicação na Etapa 5; a
janela de revalidação atual é explícita. Homologação de produto/editorial e auditoria Lighthouse/axe
dependem do ambiente e não são declaradas como concluídas por testes de código.
