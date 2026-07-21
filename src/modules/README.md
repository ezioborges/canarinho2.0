# Modulos de dominio

Cada diretorio e uma fronteira de negocio. O arquivo `index.ts` e a unica API que outro modulo ou
uma rota pode importar. Importacoes profundas por alias sao bloqueadas no ESLint.

Regras de dependencia:

- `app` pode orquestrar modulos e usar `shared`;
- um modulo pode usar `shared` e a API publica de outro modulo;
- `shared` nao conhece modulos nem rotas;
- modulos e `shared` nao importam arquivos de `app`;
- regra de negocio permanece no modulo que a possui.

As camadas `domain`, `application`, `infrastructure`, `presentation`, `schemas` e `tests` devem ser
criadas somente quando aparecer um caso de uso real. O ADR 0001 explica a decisao completa.
