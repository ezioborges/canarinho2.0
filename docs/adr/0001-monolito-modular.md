# ADR 0001 — Monólito modular e regras de dependência

- Status: aceita
- Data: 2026-07-20
- Responsáveis: equipe de desenvolvimento do Canarinho

## Contexto

O Canarinho reúne portal público, fluxo editorial, comunidade, comunicação e administração. Esses
domínios compartilham autenticação, banco e ciclo de entrega, mas possuem regras e permissões
diferentes. Separá-los em serviços agora aumentaria operação e coordenação; misturá-los por camada
técnica dificultaria autorização, manutenção e uma extração futura.

## Decisão

Manteremos um único repositório e uma aplicação Next.js implantável. O Supabase fornece Auth,
PostgreSQL, Storage e Edge Functions versionados no mesmo repositório.

O código da aplicação segue esta direção de dependências:

```text
src/app  ───────> src/modules/<dominio>/index.ts
   │                         │
   └────────────> src/shared <┘
```

Regras obrigatórias:

1. `src/app` contém rotas, layouts e coordenação de tela; não possui regra de negócio.
2. Cada domínio vive em `src/modules/<dominio>` e expõe uma API pequena no próprio `index.ts`.
3. Importações profundas entre módulos são proibidas. Um consumidor usa apenas a API pública.
4. Um módulo pode depender de `shared` ou da API pública de outro módulo, nunca de `app`.
5. `shared` contém somente UI sem regra de negócio, infraestrutura transversal, configuração e
   tipos genuinamente compartilhados; não depende de módulos nem de `app`.
6. Camadas internas (`domain`, `application`, `infrastructure`, `presentation`, `schemas`) só são
   criadas quando um caso de uso justificar a separação.
7. Schema, RLS, funções, seed e testes de banco permanecem em `supabase/` e evoluem por migrations.

O ESLint aplica os itens 3, 4 e 5 para imports resolvíveis. A revisão de PR verifica dependências
conceituais que uma regra estática não consegue detectar.

## Alternativas consideradas

- Microserviços desde o início: permitiriam deploy independente, mas acrescentariam contratos,
  observabilidade distribuída e operação sem uma necessidade de escala demonstrada.
- Organização global por tipo técnico: começaria simples, mas espalharia cada caso de uso por
  pastas globais e enfraqueceria a propriedade das regras.
- API Node paralela ao Supabase: duplicaria autenticação e acesso a dados sem necessidade atual.

## Consequências

### Positivas

- Setup e deploy únicos.
- Regras próximas ao domínio que as possui.
- Fronteiras verificáveis e caminho de extração futuro.
- Infraestrutura e aplicação mudam no mesmo pull request.

### Negativas e riscos

- Um build ainda integra todos os módulos.
- Dependências indevidas por caminhos relativos exigem atenção de revisão.
- `shared` pode virar um depósito genérico; toda inclusão precisa demonstrar uso transversal.

## Como validar ou revisar

Revisaremos esta decisão quando um domínio exigir escala, isolamento de segurança, cadência de
deploy ou responsabilidade operacional independente. Até lá, violações de fronteira devem falhar no
lint ou ser recusadas na revisão.
