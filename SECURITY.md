# Segurança

## Relato de vulnerabilidade

Não publique uma vulnerabilidade em issue aberta. Envie o relato pelo canal privado definido pela
organização mantenedora do repositório, com impacto, reprodução e versão afetada. Enquanto esse
canal não estiver configurado na plataforma Git, procure diretamente a Direção técnica do projeto.

## Segredos

- Somente variáveis `NEXT_PUBLIC_*` podem entrar no bundle do navegador.
- `SUPABASE_SERVICE_ROLE_KEY` e credenciais de provedores ficam apenas no ambiente protegido.
- `.env*` é ignorado; somente `.env.example`, com valores fictícios, é versionado.
- Se um segredo for commitado, ele deve ser revogado e rotacionado antes de apenas remover o texto
  do Git.
- A CI executa uma varredura do histórico com Gitleaks.

O checklist operacional está em
[`docs/runbooks/security-checklist.md`](docs/runbooks/security-checklist.md).
