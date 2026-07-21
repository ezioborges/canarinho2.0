# Checklist de segurança para mudanças

Use os itens aplicáveis no pull request.

## Autorização e dados

- [ ] Toda tabela exposta possui RLS habilitada e policies mínimas.
- [ ] Há testes positivos e negativos para cada ator afetado.
- [ ] A autorização está no banco/operação protegida, não apenas na interface.
- [ ] Funções privilegiadas fixam `search_path` e grants mínimos.
- [ ] Logs, analytics e erros não recebem token nem dado pessoal desnecessário.

## Aplicação e segredos

- [ ] Nenhum segredo usa prefixo `NEXT_PUBLIC_`.
- [ ] Entradas e rich text são validados/sanitizados no limite confiável.
- [ ] Redirecionamentos e URLs externas usam allowlist quando aplicável.
- [ ] A mudança não registra corpo privado, email completo ou credencial em log.
- [ ] Dependências novas possuem origem, manutenção e necessidade revisadas.

## Banco e operação

- [ ] A migration funciona em `pnpm db:reset` a partir de zero.
- [ ] O seed usa apenas dados fictícios.
- [ ] Alteração destrutiva possui backup, retorno e aprovação explícita.
- [ ] Retry/reprocessamento é idempotente quando existe operação assíncrona.
- [ ] O PR informa impacto de privacidade, retenção e auditoria.
