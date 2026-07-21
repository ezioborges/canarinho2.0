# Canarinho 2.0

Aplicação web do Canarinho organizada como monolito modular: um único deploy Next.js e fronteiras
explícitas entre os domínios de negócio.

## Setup rápido

Pré-requisitos:

- Node.js `22.12` ou superior (abaixo da versão 25);
- pnpm `11.13.0`;
- Docker com o daemon ativo;
- Git.

Na raiz do repositório:

```bash
cp .env.example .env.local
pnpm install --frozen-lockfile
pnpm db:start
pnpm db:reset
pnpm db:test
pnpm dev
```

A aplicação estará em `http://localhost:3000` e o Supabase Studio em
`http://127.0.0.1:54323`. O guia completo, inclusive a obtenção da chave pública local e a solução
de problemas, está em [`docs/runbooks/setup-local.md`](docs/runbooks/setup-local.md).

## Verificações

```bash
pnpm format:check
pnpm lint
pnpm typecheck
pnpm test
pnpm build
```

`pnpm validate` executa as cinco verificações da aplicação em sequência. O reset e os testes do
banco ficam separados porque dependem do Docker:

```bash
pnpm db:reset
pnpm db:test
```

## Documentação essencial

- [`docs/requirements/etapa-1-fundacao.md`](docs/requirements/etapa-1-fundacao.md): relato passo a
  passo da etapa 1;
- [`docs/requirements/etapa-2-seguranca-dados.md`](docs/requirements/etapa-2-seguranca-dados.md):
  modelo, segurança e evidências da etapa 2;
- [`docs/requirements/etapa-2-matriz-acesso.md`](docs/requirements/etapa-2-matriz-acesso.md): grants e
  RLS por papel e operação;
- [`docs/adr/0001-monolito-modular.md`](docs/adr/0001-monolito-modular.md): limites e dependências
  da arquitetura;
- [`docs/runbooks/environments.md`](docs/runbooks/environments.md): separação e promoção de
  ambientes;
- [`CONTRIBUTING.md`](CONTRIBUTING.md): commits, branches, pull requests e qualidade;
- [`SECURITY.md`](SECURITY.md): tratamento de vulnerabilidades e segredos.

## Comandos principais

| Comando         | Finalidade                                    |
| --------------- | --------------------------------------------- |
| `pnpm dev`      | Inicia a aplicação em modo de desenvolvimento |
| `pnpm build`    | Gera o bundle de produção e valida o ambiente |
| `pnpm test`     | Executa testes unitários com Vitest           |
| `pnpm lint`     | Valida código e fronteiras entre módulos      |
| `pnpm db:start` | Inicia a pilha Supabase local                 |
| `pnpm db:reset` | Recria o banco pelas migrations e pelo seed   |
| `pnpm db:test`  | Executa a suíte pgTAP                         |
| `pnpm validate` | Executa todas as verificações da aplicação    |
