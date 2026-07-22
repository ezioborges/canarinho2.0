# Etapa 2 — Matriz de decisão de acesso

Esta matriz descreve grants e RLS implementados nas migrations da Etapa 2. “Próprio” inclui o
submetente ou perfil relacionado em `content_authors`. Toda operação não listada é negada.

## Identidade e administração

| Recurso/operação           | Visitante | Leitor                    | Revisor | Editor | Conexões | Diretor        |
| -------------------------- | --------- | ------------------------- | ------- | ------ | -------- | -------------- |
| Perfil ligado a publicação | ler       | ler                       | ler     | ler    | ler      | ler            |
| Próprio perfil             | —         | ler/editar campos básicos | igual   | igual  | igual    | igual          |
| Perfis internos            | —         | —                         | ler     | ler    | —        | ler            |
| Próprios papéis            | —         | ler                       | ler     | ler    | ler      | ler            |
| Papéis de outras pessoas   | —         | —                         | —       | —      | —        | ler            |
| Atribuir/revogar papel     | —         | —                         | —       | —      | —        | RPC com motivo |
| Auditoria e outbox         | —         | —                         | —       | —      | —        | ler            |

## Conteúdo editorial

| Recurso/operação                  | Visitante | Leitor      | Revisor                        | Editor                  | Conexões            | Diretor      |
| --------------------------------- | --------- | ----------- | ------------------------------ | ----------------------- | ------------------- | ------------ |
| Conteúdo público `published`      | ler       | ler         | ler                            | ler                     | ler                 | ler          |
| Próprio `draft/changes_requested` | —         | ler/editar  | ler/editar se autor            | ler/editar se autor     | ler/editar se autor | ler/editar   |
| Próprio em demais estados         | —         | ler         | ler                            | ler                     | ler                 | ler          |
| Fila de revisão                   | —         | —           | ler                            | —                       | —                   | ler          |
| Fila de edição                    | —         | —           | —                              | ler/editar conteúdo     | —                   | ler/editar   |
| Alterar status diretamente        | —         | —           | —                              | —                       | —                   | —            |
| Assumir/atribuir revisão          | —         | —           | RPC                            | —                       | —                   | RPC          |
| Aprovar/rejeitar/pedir ajustes    | —         | —           | RPC se responsável e não autor | —                       | —                   | RPC          |
| Editar/agendar/publicar/arquivar  | —         | —           | —                              | RPC nos estados válidos | —                   | RPC          |
| Exceção de publicação             | —         | —           | —                              | —                       | —                   | RPC auditada |
| Versões e histórico               | —         | próprios    | fila permitida                 | fila permitida          | próprios            | todos        |
| Comentário editorial por versão   | —         | ler próprio | RPC se responsável             | ler na fila             | —                   | RPC/ler      |
| Restaurar versão                  | —         | —           | —                              | RPC em `in_editing`     | —                   | RPC          |
| Trocar destaque principal         | —         | —           | —                              | RPC atômica             | —                   | RPC atômica  |
| Executar job de agendamento       | —         | —           | —                              | —                       | —                   | —            |

## Taxonomia, edições e Storage

| Recurso/operação                    | Visitante | Leitor  | Revisor        | Editor          | Conexões | Diretor         |
| ----------------------------------- | --------- | ------- | -------------- | --------------- | -------- | --------------- |
| Categoria/tag ativa                 | ler       | ler     | ler            | ler             | ler      | ler             |
| Criar/editar/arquivar categoria/tag | —         | —       | —              | sim             | —        | sim             |
| Edição publicada                    | ler       | ler     | ler            | ler             | ler      | ler             |
| Gerenciar edições                   | —         | —       | —              | sim             | —        | sim             |
| Upload privado no próprio caminho   | —         | sim     | sim            | sim             | sim      | sim             |
| Ler upload privado                  | —         | próprio | fila editorial | fila editorial  | próprio  | todos           |
| Upload público                      | —         | —       | —              | próprio caminho | —        | próprio caminho |

## Justificativa por tabela exposta

| Tabela                     | Leitura concedida                                | Escrita concedida/justificativa                    |
| -------------------------- | ------------------------------------------------ | -------------------------------------------------- |
| `profiles`                 | próprio, equipe editorial e autor público        | apenas campos básicos do próprio perfil            |
| `roles`                    | catálogo para autenticados                       | somente migration                                  |
| `user_roles`               | próprios ou todos para Diretor                   | somente RPC auditada de Diretor                    |
| `categories`               | ativas; arquivadas para Editor/Diretor           | Editor/Diretor; exclusão direta negada             |
| `tags`                     | ativas; arquivadas para Editor/Diretor           | Editor/Diretor; exclusão direta negada             |
| `editions`                 | publicadas ou todas para Editor/Diretor          | Editor/Diretor                                     |
| `media_assets`             | público, proprietário ou equipe editorial        | proprietário no privado; Editor/Diretor no público |
| `content_items`            | público, próprio ou fila correspondente ao papel | somente comandos transacionais versionados         |
| `content_authors`          | acompanha a visibilidade do conteúdo             | somente comandos do agregado                       |
| `content_categories`       | acompanha a visibilidade do conteúdo             | somente comandos do agregado                       |
| `content_tags`             | acompanha a visibilidade do conteúdo             | somente comandos do agregado                       |
| `edition_items`            | edição e conteúdo precisam ser visíveis          | Editor/Diretor                                     |
| `content_slug_redirects`   | somente se o destino for visível                 | somente comando privilegiado futuro                |
| `content_versions`         | quem pode ler o conteúdo, nunca Visitante        | somente comando transacional; append-only          |
| `editorial_status_history` | quem pode ler o conteúdo, nunca Visitante        | somente comando transacional; append-only          |
| `audit_logs`               | somente Diretor                                  | somente helpers protegidos; append-only            |
| `outbox_events`            | somente Diretor nesta fase                       | somente comandos protegidos/processador futuro     |
| `editorial_comments`       | quem pode ler o conteúdo, nunca Visitante        | somente RPC de Revisor responsável/Diretor         |

O job de agendamento não representa um papel humano: a API concede execução somente a
`service_role`, e histórico/versão registram `actor_kind = system`.

## Negativas automatizadas

`0002_stage_2_security_and_workflow.test.sql` comprova, entre outros casos:

- visitante não lê conteúdo não publicado nem versões;
- Leitor não lê fila interna, auditoria ou outbox e não altera conteúdo em revisão;
- Conexões não altera matéria;
- atualização direta de status e papel falha mesmo quando chamada no banco;
- Revisor não autoaprova e um lock obsoleto é rejeitado;
- Editor não publica conteúdo sem capa acessível e SEO;
- somente Diretor gerencia papéis, e o último Diretor não pode ser removido;
- versões e auditoria permanecem imutáveis.
