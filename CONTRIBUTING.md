# Como contribuir

## Fluxo de trabalho

1. Atualize `main` e crie uma branch curta, por exemplo `feat/editorial-submission`.
2. Faça uma alteração coesa e inclua testes na mesma branch.
3. Rode `pnpm validate`, `pnpm db:reset` e `pnpm db:test` quando houver Docker disponível.
4. Abra o pull request pelo template e registre riscos, migration e evidências de teste.
5. Aguarde CI verde e revisão antes do merge.

## Commits e título do PR

Usamos Conventional Commits. O título do PR também precisa seguir o padrão, pois é validado na CI:

```text
<tipo>(<escopo opcional>): <descrição no imperativo>
```

Exemplos:

```text
feat(editorial): adiciona criação de rascunho
fix(supabase): impede papel duplicado
docs: detalha setup local
```

Tipos comuns: `feat`, `fix`, `docs`, `test`, `refactor`, `build`, `ci`, `chore`, `perf` e
`revert`. Os escopos permitidos ficam em `commitlint.config.mjs`.

## Fronteiras de código

- Rotas em `src/app` orquestram módulos e componentes compartilhados.
- Cada módulo expõe somente seu `index.ts` para consumidores externos.
- Um módulo nunca importa uma rota.
- `src/shared` nunca conhece módulos ou rotas.
- Regras de negócio não são colocadas em `shared`.

O ESLint bloqueia violações conhecidas. Dependências novas entre domínios também precisam ser
explicadas na revisão, mesmo quando tecnicamente permitidas.

## Migrations

- Migrations são forward-only e recebem o prefixo temporal `YYYYMMDDHHMMSS`.
- Dados de referência necessários em todos os ambientes pertencem à migration.
- Personas e dados fictícios pertencem a `supabase/seed.sql` e nunca chegam a produção.
- Alterações de schema devem incluir pgTAP e, na etapa apropriada, testes positivos e negativos de
  RLS.
