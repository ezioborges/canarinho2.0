# Canarinho 2.0

Aplicacao web do Canarinho organizada como monolito modular: um unico deploy Next.js e fronteiras
explicitas entre os dominios de negocio.

## Setup rapido

Pre-requisitos:

- Node.js `22.12` ou superior (abaixo da versao 25);
- pnpm `11.13.0`;
- Docker com o daemon ativo;
- Git.

Na raiz do repositorio:

```bash
cp .env.example .env.local
pnpm install --frozen-lockfile
pnpm db:start
pnpm db:reset
pnpm db:test
pnpm dev
```

A aplicacao estara em `http://localhost:3000` e o Supabase Studio em
`http://127.0.0.1:54323`. O guia completo, inclusive a obtencao da chave publica local e a solucao
de problemas, esta em [`docs/runbooks/setup-local.md`](docs/runbooks/setup-local.md).

## Verificacoes

```bash
pnpm format:check
pnpm lint
pnpm typecheck
pnpm test
pnpm build
```

`pnpm validate` executa as cinco verificacoes da aplicacao em sequencia. O reset e os testes do
banco ficam separados porque dependem do Docker:

```bash
pnpm db:reset
pnpm db:test
```

## Documentacao essencial

- [`docs/requirements/etapa-1-fundacao.md`](docs/requirements/etapa-1-fundacao.md): relato passo a
  passo da etapa 1;
- [`docs/adr/0001-monolito-modular.md`](docs/adr/0001-monolito-modular.md): limites e dependencias
  da arquitetura;
- [`docs/runbooks/environments.md`](docs/runbooks/environments.md): separacao e promocao de
  ambientes;
- [`CONTRIBUTING.md`](CONTRIBUTING.md): commits, branches, pull requests e qualidade;
- [`SECURITY.md`](SECURITY.md): tratamento de vulnerabilidades e segredos.

## Comandos principais

| Comando         | Finalidade                                    |
| --------------- | --------------------------------------------- |
| `pnpm dev`      | Inicia a aplicacao em modo de desenvolvimento |
| `pnpm build`    | Gera o bundle de producao e valida o ambiente |
| `pnpm test`     | Executa testes unitarios com Vitest           |
| `pnpm lint`     | Valida codigo e fronteiras entre modulos      |
| `pnpm db:start` | Inicia a pilha Supabase local                 |
| `pnpm db:reset` | Recria o banco pelas migrations e pelo seed   |
| `pnpm db:test`  | Executa a suite pgTAP                         |
| `pnpm validate` | Executa todas as verificacoes da aplicacao    |
