# Execução da etapa 1 — fundação do repositório

- Data: 2026-07-20
- Plano de origem: `../canarinho-docs/plano-de-acao-monolito-modular.md`
- Estado: implementada; resultados de validação registrados no fim deste documento

## Objetivo executado

Criar uma base em que outra pessoa consiga instalar dependências, recriar o banco, rodar testes e
gerar a mesma aplicação sem depender de configuração implícita ou dados pessoais.

## Passo a passo do que foi feito

### 1. Aplicação e versões reproduzíveis

Foi criada uma aplicação Next.js com App Router, React e TypeScript estrito. `package.json` fixa
todas as versões, declara Node/pnpm compatíveis e escolhe pnpm como único gerenciador. O
`pnpm-lock.yaml` é a fonte reproduzível de dependências e a CI usa `--frozen-lockfile`.

O TypeScript ativa, além de `strict`, verificações para acesso possivelmente indefinido, opcionais
exatos, overrides e fallthrough. O alias `@/*` aponta para `src/*`.

### 2. Qualidade e convenções

Foram configurados:

- ESLint com regras Next.js/TypeScript e análise de imports;
- bloqueio de ciclos e importações profundas entre módulos;
- Prettier com verificação separada;
- Vitest para testes unitários;
- Commitlint/Conventional Commits para o título dos PRs;
- scripts únicos `format:check`, `lint`, `typecheck`, `test`, `build` e `validate`.

O arquivo `CONTRIBUTING.md` explica branch, commit, migration e revisão. O template de PR transforma
essas regras em checklist.

### 3. Estrutura modular

Foram criadas as dez fronteiras previstas no plano em `src/modules`. Cada uma começa com apenas seu
`index.ts`, evitando camadas vazias. `src/modules/README.md` documenta a direção das dependências e o
ADR 0001 registra contexto, decisão, alternativas e consequências.

A página inicial importa o catálogo pela API pública `@/modules`; isso exercita alias e fronteira no
build real.

### 4. Ambiente validado e segredo fora do cliente

`.env.example` contém apenas nomes necessários e valores locais/fictícios. Schemas Zod validam o
ambiente lógico, URLs e chave pública. A validação ocorre ao carregar `next.config.ts`, portanto
`dev` e `build` falham cedo.

A service role é opcional até existir um caso privilegiado, fica em um módulo marcado `server-only`
e é rejeitada se aparecer com prefixo `NEXT_PUBLIC_`. Testes unitários cobrem ausência de variável e
vazamento pelo nome público.

### 5. Supabase recriável e personas locais

`supabase/config.toml` fixa portas, PostgreSQL, Auth, Storage, Studio e runtime local. A primeira
migration cria o mínimo necessário para as personas da fundação:

- enum dos cinco papéis;
- `profiles`, `roles` e `user_roles` N:N;
- trigger protegido para criar perfil;
- RLS habilitada sem permissões abertas;
- catálogo dos papéis como dado de referência.

As policies funcionais completas permanecem na etapa 2. O seed cria cinco identidades claramente
fictícias, uma por papel, em domínio `.test`. pgTAP verifica schema, quantidade de personas,
atribuição dos papéis e RLS ativa.

### 6. Ambientes

`docs/runbooks/environments.md` separa local, desenvolvimento compartilhado, staging e produção,
incluindo dados permitidos, variáveis e ordem de promoção. Nenhum recurso remoto foi criado: isso
exigiria credenciais, organização e autorização de operação que não fazem parte da fundação local.

### 7. CI e governança

O workflow `.github/workflows/ci.yml` possui três gates:

1. instalação pelo lockfile, título do PR, formato, lint, tipos, Vitest e build;
2. Supabase local, reset integral e pgTAP;
3. varredura do histórico por segredos.

O job de banco inicia somente o container PostgreSQL, suficiente para migrations, seed e pgTAP. O
setup de desenvolvimento continua usando `pnpm db:start` para disponibilizar a pilha completa; a
separação reduz tempo e superfície do gate automatizado sem mudar o que é testado.

Também foram criados templates de bug, melhoria, ADR, PR e checklist de segurança.

### 8. Setup para outra pessoa

`README.md` oferece o caminho curto. `docs/runbooks/setup-local.md` detalha pré-requisitos, instalação,
variáveis, reset, personas, validações, inicialização e erros comuns. Os comandos esperados são:

```bash
cp .env.example .env.local
pnpm install --frozen-lockfile
pnpm db:start
pnpm db:reset
pnpm db:test
pnpm validate
pnpm dev
```

## Rastreabilidade dos entregáveis

| Entregável da etapa 1          | Evidência principal                                                |
| ------------------------------ | ------------------------------------------------------------------ |
| Next.js/TypeScript estrito     | `package.json`, `tsconfig.json`, `src/app`                         |
| Gerenciador e lockfile únicos  | `packageManager`, `.npmrc`, `pnpm-lock.yaml`                       |
| Alias, lint, formato e imports | `tsconfig.json`, `eslint.config.mjs`, `.prettierrc.json`           |
| Estrutura e ADR                | `src/modules`, ADR 0001                                            |
| Supabase, migrations e seed    | `supabase/config.toml`, `supabase/migrations`, `supabase/seed.sql` |
| Ambiente validado              | `.env.example`, `src/shared/config`                                |
| Quatro ambientes separados     | `docs/runbooks/environments.md`                                    |
| Seeds por papel                | `supabase/seed.sql` e pgTAP                                        |
| CI reproduzível                | `.github/workflows/ci.yml`                                         |
| Templates e segurança          | `.github`, ADR 0000, runbook de segurança                          |

## Resultado das validações

Os resultados abaixo vêm de comandos executados em 2026-07-20 dentro de `canarinho2.0`, e não
apenas da configuração do workflow:

| Comando                          | Resultado observado                                  |
| -------------------------------- | ---------------------------------------------------- |
| `pnpm install --frozen-lockfile` | passou; lockfile já atualizado, sem alteração        |
| `pnpm format:check`              | passou; todos os arquivos cobertos seguem Prettier   |
| `pnpm lint`                      | passou; zero erro e zero warning                     |
| `pnpm typecheck`                 | passou em TypeScript estrito                         |
| `pnpm test`                      | passou; 1 arquivo e 5 testes unitários               |
| `pnpm build`                     | passou; `/` e `/_not-found` geradas estaticamente    |
| `pnpm validate`                  | passou de ponta a ponta após todos os ajustes        |
| `pnpm start` + HTTP `/`          | servidor pronto em 396 ms; resposta `200 OK`         |
| `pnpm db:reset`                  | passou; banco recriado, migration e seed reaplicados |
| `pnpm db:test`                   | passou; 1 arquivo e 12 testes pgTAP                  |

O build também foi executado sem variáveis de ambiente e falhou antes da compilação, como esperado.
Isso confirmou o fail-fast; em seguida, o mesmo build passou com os valores locais válidos.

Para a validação de banco, o Docker Desktop 4.54 já existente no Windows foi iniciado e sua
integração WSL ficou ativa (Engine 29.1.2). O Supabase CLI 2.109.1 foi instalado pelo lockfile do
projeto. A primeira imagem PostgreSQL foi baixada e a pilha mínima de teste foi iniciada por
`pnpm db:start:test`. O comando exclui serviços sem participação em migration, seed ou pgTAP; o
setup cotidiano `pnpm db:start` continua disponível para iniciar Auth, API, Storage, Studio e os
demais componentes configurados. Depois dos testes, `pnpm db:stop` encerrou os containers do projeto
e preservou o banco local no volume de backup do Docker.

### Correções feitas a partir da execução real

1. ESLint 10 foi substituído por 9.39.5, pois plugins transitivos do `eslint-config-next` ainda
   declaram compatibilidade até a versão 9. `pnpm peers check` terminou sem pendências depois do
   ajuste.
2. O pnpm 11.13 exige aprovação explícita dos scripts nativos. `pnpm-workspace.yaml` permite apenas
   `sharp` e `unrs-resolver`; ambos foram reconstruídos com sucesso.
3. Os nomes aceitos por `supabase start --exclude` diferem dos nomes amigáveis do config. O script
   mínimo e a CI foram corrigidos conforme a lista fornecida pelo CLI 2.109.1.
4. O Next.js 16 referencia tipos de rotas gerados em `.next`. `typecheck` passou a executar
   `next typegen` antes de `tsc`, permitindo a checagem em um clone limpo antes do build.
5. A restrição informada durante a execução foi aplicada: aplicação, Supabase, dependências e esta
   documentação ficam em `canarinho2.0/`. Apenas `.github/` permanece na raiz, porque workflows e
   templates só são reconhecidos pelo GitHub nessa posição; todos os comandos do workflow usam
   `canarinho2.0` como diretório de trabalho.

O workflow remoto será executado quando estes arquivos forem enviados ao GitHub. Localmente, todos
os comandos funcionais equivalentes aos jobs de aplicação e banco passaram; a ação hospedada do
Gitleaks só existe no runner do GitHub.
