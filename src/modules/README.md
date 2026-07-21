# Módulos de domínio

Cada diretório é uma fronteira de negócio. O arquivo `index.ts` é a única API que outro módulo ou
uma rota pode importar. Importações profundas por alias são bloqueadas no ESLint.

Regras de dependência:

- `app` pode orquestrar módulos e usar `shared`;
- um módulo pode usar `shared` e a API pública de outro módulo;
- `shared` não conhece módulos nem rotas;
- módulos e `shared` não importam arquivos de `app`;
- regra de negócio permanece no módulo que a possui.

As camadas `domain`, `application`, `infrastructure`, `presentation`, `schemas` e `tests` devem ser
criadas somente quando aparecer um caso de uso real. O ADR 0001 explica a decisão completa.
