# Runbook — ambientes e promoção

O projeto usa quatro ambientes isolados. Nenhuma base ou credencial é compartilhada entre eles.

| Ambiente        | Aplicação                     | Supabase                   | Dados permitidos                                | Promoção                                       |
| --------------- | ----------------------------- | -------------------------- | ----------------------------------------------- | ---------------------------------------------- |
| Local           | processo do desenvolvedor     | containers locais          | seed fictício                                   | livre e descartável                            |
| Desenvolvimento | deploy compartilhado          | projeto Supabase próprio   | sintéticos ou anonimizados                      | automática após integração, quando configurada |
| Staging         | deploy equivalente à produção | projeto Supabase próprio   | ensaio controlado, sem cópia pessoal irrestrita | migrations primeiro; aplicação depois          |
| Produção        | deploy público                | projeto Supabase exclusivo | dados reais conforme política                   | aprovação humana e checklist                   |

## Variáveis por ambiente

Cada plataforma de deploy armazena, no mínimo:

- `NEXT_PUBLIC_APP_ENV`: `development`, `staging` ou `production`;
- `NEXT_PUBLIC_SITE_URL`: URL canônica daquele deploy;
- `NEXT_PUBLIC_SUPABASE_URL`: URL do projeto Supabase correspondente;
- `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`: chave pública daquele projeto;
- `SUPABASE_SERVICE_ROLE_KEY`: somente quando uma operação de servidor realmente exigir, sempre no
  cofre de segredos da plataforma.

Variáveis remotas nunca são copiadas para arquivos versionados. A service role não é necessária no
navegador e qualquer prefixo `NEXT_PUBLIC_` nela faz a validação falhar.

## Ordem de promoção

1. CI valida aplicação, reset do banco, pgTAP, build e segredos.
2. Migrations forward-only são aplicadas em desenvolvimento.
3. A mesma revisão é promovida a staging; migrations entram antes do código que depende delas.
4. Smoke tests e critérios de homologação são executados em staging.
5. Produção exige aprovação humana; migration, aplicação e verificação de saúde são registradas.
6. Uma falha usa correção forward. Mudança destrutiva exige backup e plano específico antes da
   execução.

IDs de projetos, URLs administrativas, responsáveis e procedimentos de acesso devem ser
preenchidos quando os ambientes remotos forem provisionados. A etapa 1 define a separação; não cria
recursos remotos sem autorização explícita.
