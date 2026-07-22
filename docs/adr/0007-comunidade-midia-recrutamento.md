# ADR 0007 — Comunidade, mídia e dados de recrutamento

- Status: aceito
- Data: 2026-07-22

## Contexto

A Etapa 6 acrescenta escrita pública autenticada, moderação, favoritos, apresentação da equipe e
dados pessoais de candidaturas. Esses dados têm níveis de exposição e ciclos de vida diferentes.

## Decisão

- comentários são criados por RPC idempotente, com limites de 5 por 10 minutos e 30 por dia;
- denúncias e moderação usam comandos protegidos; ocultação, restauração e remoção lógica geram
  histórico append-only e auditoria;
- favoritos são uma relação privada por usuário e conteúdo publicado;
- galeria e produções artísticas reutilizam `content_items`, autoria, tags e `media_assets`, sem um
  segundo catálogo divergente;
- equipe é organizada por eixos extensíveis, com read model público que devolve somente campos
  aprovados;
- candidatura pode ser enviada sem conta, mas não recebe grant público de leitura; somente Diretor
  acessa ou altera o registro;
- cada candidatura guarda versão de consentimento e `retention_expires_at`; um job exclusivo de
  serviço elimina dados expirados em lotes.

## Consequências

O fluxo público continua simples, mas regras de abuso e autorização permanecem no PostgreSQL.
Remoção de comentário não significa destruição da evidência. Candidaturas exigem agendamento do
job de retenção e acompanhamento operacional. Rate limiting por identidade/email é a proteção
básica desta etapa; proteção por borda/IP pode ser acrescentada no hardening da Etapa 9.
