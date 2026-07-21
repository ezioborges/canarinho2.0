# Runbook — setup local do zero

Este procedimento parte de uma máquina limpa e termina com aplicação, banco e testes funcionando.

## 1. Instalar os pré-requisitos

- Git;
- Node.js entre `22.12` e `24.x`;
- pnpm `11.13.0`;
- Docker Engine ou Docker Desktop com o daemon ativo.

Confirme:

```bash
git --version
node --version
pnpm --version
docker version
```

No Windows com WSL 2, habilite a integração da distribuição em **Docker Desktop > Settings >
Resources > WSL Integration**. O comando `docker version` dentro do WSL deve mostrar cliente e
servidor.

## 2. Clonar e instalar de forma reproduzível

```bash
git clone <url-do-repositorio> canarinho
cd canarinho
pnpm install --frozen-lockfile
```

`--frozen-lockfile` impede que a instalação altere silenciosamente as versões aprovadas.

## 3. Preparar as variáveis locais

```bash
cp .env.example .env.local
```

O exemplo já aponta para as portas locais. Depois de iniciar o Supabase no próximo passo, rode
`pnpm db:status` e copie a chave pública/anon local para
`NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`. Nunca copie a `service_role` para uma variável
`NEXT_PUBLIC_*`.

## 4. Subir e recriar o Supabase

```bash
pnpm db:start
pnpm db:reset
pnpm db:status
```

O reset apaga somente o banco Docker local do projeto, reaplica todas as migrations e executa
`supabase/seed.sql`. Ele pode ser repetido sempre que for necessário voltar a um estado conhecido.

Endpoints padrão:

- API: `http://127.0.0.1:54321`;
- PostgreSQL: `127.0.0.1:54322`;
- Studio: `http://127.0.0.1:54323`;
- caixa de email local: `http://127.0.0.1:54324`.

## 5. Conferir as personas fictícias

O seed cria uma conta para cada papel. Todas usam a senha local `CanarinhoLocal123!`:

| Papel    | Email local                     |
| -------- | ------------------------------- |
| Leitor   | `leitor@local.canarinho.test`   |
| Revisor  | `revisor@local.canarinho.test`  |
| Editor   | `editor@local.canarinho.test`   |
| Conexões | `conexoes@local.canarinho.test` |
| Diretor  | `diretor@local.canarinho.test`  |

Essas identidades são deliberadamente fictícias e não podem ser promovidas a nenhum ambiente
remoto.

## 6. Validar banco e aplicação

```bash
pnpm db:test
pnpm validate
```

O primeiro comando executa pgTAP. O segundo valida formato, lint/fronteiras, tipos, testes unitários
e build de produção.

## 7. Iniciar o desenvolvimento

```bash
pnpm dev
```

Abra `http://localhost:3000`. Para encerrar a infraestrutura local:

```bash
pnpm db:stop
```

## Problemas comuns

### `Cannot connect to the Docker daemon`

Inicie o Docker. Em WSL 2, habilite a integração da distribuição e reabra o terminal.

### Porta já ocupada

Use `pnpm db:status` para descobrir uma pilha antiga. Encerre-a com `pnpm db:stop`; só altere as
portas em `supabase/config.toml` de forma versionada e coordenada.

### Falha de variável na inicialização

Compare `.env.local` com `.env.example`. A aplicação falha cedo quando ambiente, URLs ou chave
pública estão ausentes ou inválidos.

### Reset falha depois de alterar SQL

Leia a primeira migration que falhou, corrija a migration ainda não integrada e repita
`pnpm db:reset`. Não ajuste manualmente o banco local para esconder a divergência.
