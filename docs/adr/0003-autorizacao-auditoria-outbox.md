# ADR 0003 — RBAC relacional, RLS, auditoria e outbox

- Status: aceita
- Data: 2026-07-21
- Responsáveis: equipe de desenvolvimento do Canarinho

## Contexto

O Canarinho precisa aceitar múltiplos papéis sem confiar em metadados alteráveis pelo cliente. A
mesma operação pode ainda gerar uma mudança de negócio, auditoria e notificação, mas uma falha do
provedor de email não pode desfazer a mudança editorial.

## Decisão

Papéis permanecem na relação N:N `user_roles`. Helpers `security definer` pequenos consultam essa
relação com `search_path` vazio; nenhum helper confia em `raw_user_meta_data`. Grants de tabela são
mínimos e todas as tabelas expostas têm RLS. Policies concedem acesso pela união explícita dos
papéis do usuário.

Atribuição e revogação de papéis passam por RPCs exclusivas de Diretor, exigem justificativa,
registram auditoria e impedem remover o último Diretor. Escritas diretas em `user_roles` não são
concedidas à API.

`audit_logs`, `content_versions` e `editorial_status_history` são append-only para a aplicação e
possuem trigger que também rejeita alteração pelo owner em uso normal. Somente Diretor lê a
auditoria. `outbox_events` recebe chaves de idempotência e estado/tentativas; somente o processador
privilegiado futuro poderá alterar a fila. O payload guarda identificadores e estado, não corpo
editorial, email ou tokens.

No Storage, arquivos de rascunho ficam no bucket privado `content-drafts`; o primeiro segmento do
caminho deve ser o UUID do proprietário. O bucket `content-public` aceita escrita apenas de Editor
ou Diretor. Ambos limitam MIME e tamanho, e metadados de imagem exigem texto alternativo.

## Alternativas consideradas

- Papel em JWT ou metadado editável: leitura rápida, porém sujeito a defasagem/revogação e, no caso
  de metadado do usuário, elevação indevida.
- Hierarquia numérica de papel: não representa corretamente permissões independentes como
  Conexões.
- Enviar email dentro da transação: acopla disponibilidade externa ao comando editorial.

## Consequências

- Uma pessoa com vários papéis recebe a união das policies aplicáveis.
- Novas tabelas nascem sem acesso até grants e policies explícitas serem revisados.
- O worker da outbox deve usar idempotência, lotes e retry; ele será implementado quando o primeiro
  canal de notificação entrar no escopo.
- Mudança de papel e transição editorial sempre deixam evidência consultável por Diretor.
