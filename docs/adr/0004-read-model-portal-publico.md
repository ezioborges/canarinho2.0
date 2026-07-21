# ADR 0004 — read model e cache do portal público

- Status: aceita
- Data: 2026-07-21
- Responsáveis: equipe de desenvolvimento do Canarinho

## Contexto

Home, listagem, busca, detalhe, sitemap e metadados precisam aplicar exatamente a mesma fronteira:
somente conteúdo `published`, com visibilidade `public` e sem soft delete. Repetir joins e filtros em
cada rota aumentaria o risco de um rascunho aparecer em uma superfície secundária como busca ou
Open Graph.

O portal também precisa buscar em português, montar autores/taxonomia/mídia sem N+1 e preservar
URLs antigas quando o slug de algo já publicado mudar.

## Decisão

O PostgreSQL expõe quatro funções de leitura específicas: home, listagem/busca, detalhe e resolução
de slug. Elas são `security definer`, fixam `search_path` vazio e repetem explicitamente a condição
pública; não concedem acesso genérico a conteúdo privado. O cliente Next.js usa somente a chave
pública e nunca `service_role`.

A busca usa `tsvector` gerado, configuração `portuguese`, pesos por campo e índice GIN parcial. O
título recebe peso A, subtítulo/resumo peso B e corpo peso C. Filtros de categoria, tipo, período,
autor, tag e edição são aplicados no mesmo comando paginado.

`content_placements` representa hero, destaques e galeria sem adicionar booleanos ao conteúdo.
`content_relationships` guarda sugestões editoriais ordenadas. Ambas as relações têm RLS. Um
trigger registra o slug anterior quando um item que já foi publicado muda e outro impede reutilizar
um slug reservado por redirect de conteúdo diferente.

Home e listagens públicas revalidam em 5 minutos; detalhes e redirects em 1 hora; buscas livres não
são armazenadas. Uma futura operação de publicação poderá invalidar as tags do cache imediatamente,
sem mudar a API das páginas.

O rich text é transformado em elementos React por uma allowlist de nós e protocolos. HTML salvo no
documento nunca é injetado na página.

## Alternativas consideradas

- Montar todos os joins via PostgREST em cada rota: menos SQL inicial, mas duplica a fronteira de
  publicação e aumenta consultas e mapeamentos.
- Buscar com `ilike`: simples, porém sem relevância, stemming ou índice adequado para o volume
  esperado.
- Gerar HTML e usar `dangerouslySetInnerHTML`: reduz código de apresentação, mas amplia a superfície
  de XSS e mistura sanitização com renderização.
- Cache permanente por página: rápido, mas deixa publicação, arquivamento e correção editorial
  defasados sem uma invalidação já integrada ao fluxo da etapa 5.

## Consequências

- Superfícies públicas compartilham uma única regra testável de exposição.
- Alterações no formato do read model exigem migration e ajuste dos tipos TypeScript.
- A busca livre sempre consulta o banco; limites e paginação controlam o custo.
- Invalidação imediata será ligada à publicação/arquivamento na etapa 5; até lá vale a janela de
  revalidação documentada.
