# Execução da Etapa 4 — autenticação, conta e submissão

- Data: 2026-07-21
- Plano de origem: `../../../canarinho-docs/plano-de-acao-monolito-modular.md`
- Estado: implementada

## Escopo entregue

### Autenticação e conta

- cadastro com perfil e papel mínimo `leitor` criado pelo trigger de Auth;
- login e logout por Supabase Auth;
- recuperação e atualização de senha por callback PKCE;
- atualização de nome público, curso e vínculo;
- renovação de sessão e proteção de `/conta` e `/submissoes` no servidor;
- retorno pós-login restrito a caminho interno, sem open redirect;
- mensagens de recuperação que não revelam se o email existe.

### Rascunho e submissão

- “Minhas submissões” com status, acesso ao rascunho e histórico permitido por RLS;
- editor TipTap com documento JSON estruturado, títulos, listas, citações, negrito e itálico;
- autores múltiplos, ordem de assinatura, categoria principal, tags e observações internas;
- autosave após 1,6 segundo, botão de salvamento explícito, indicador acessível e fallback local;
- lock otimista para impedir sobrescrita silenciosa entre abas;
- termos canônicos versionados, com versão e instante aceitos gravados no conteúdo;
- submissão transacional que cria versão, histórico, auditoria e outbox;
- recibos internos e convergência de estado para impedir duplicação em retry/duplo clique.

### Arquivos privados

- JPG/JPEG, PNG, WebP e PDF, com limite de 10 MiB;
- validação combinada de MIME e extensão na API e no banco;
- caminho `<user>/<conteúdo>/<arquivo>.<extensão>` e bucket não público;
- texto alternativo obrigatório para imagens;
- registro de metadado e vínculo ao conteúdo na mesma RPC;
- Storage RLS valida proprietário e se o conteúdo ainda pode ser editado.

## Rastreabilidade

| Requisito/regra     | Evidência principal                                                    |
| ------------------- | ---------------------------------------------------------------------- |
| RF-001              | páginas e ações de cadastro, login e logout; E2E                       |
| RF-002 / RF-005     | trigger de perfil, página `/conta`, recuperação e senha                |
| RF-020              | editor estruturado, taxonomia, autoria e observações                   |
| RF-021 / RN-013–014 | autosave, RLS, `save_own_content_draft` e lock                         |
| RF-022 / RN-015     | rota de upload, bucket privado, trigger e policies                     |
| RF-023 / RN-010–012 | `submit_own_content` e validação no PostgreSQL                         |
| RF-024              | lista, detalhe, status e histórico do autor                            |
| RF-025              | evento `content.submitted` na outbox; processamento pertence à Etapa 7 |
| RN-001–005          | grants mínimos, RLS e sessão sem substituir autorização de banco       |

## Evidências automatizadas

- `0004_stage_4_accounts_and_submissions.test.sql`: 35 verificações de schema, RLS, Storage,
  autosave, termos, versão, histórico e idempotência;
- Vitest: sanitização do retorno, slug estável e documento rich text vazio/real;
- Playwright: login, sessão protegida, rascunho, editor, arquivo privado, submissão, histórico,
  perfil e logout;
- a suíte de banco completa soma 118 testes, incluindo regressão das Etapas 1 a 3.

## Limites conscientes

O evento de notificação é criado atomicamente, mas o worker de email pertence à Etapa 7. Comentários
editoriais e solicitações de ajuste entram na Etapa 5; por isso o histórico desta fase contém as
transições já autorizadas ao autor. Remoção visual de arquivo e restauração assistida da cópia local
podem evoluir sem mudar o formato ou a fronteira de segurança escolhidos.
