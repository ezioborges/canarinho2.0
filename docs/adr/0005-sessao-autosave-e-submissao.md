# ADR 0005 — Sessão, autosave e fronteira transacional de submissão

- Status: aceito
- Data: 2026-07-21

## Contexto

A Etapa 4 precisa combinar sessão segura no Next.js, edição frequente no navegador, arquivos
privados e uma transição editorial que não pode ser duplicada por duplo clique ou retry. As tabelas
e a máquina de estados da Etapa 2 já existiam, mas atualizações independentes do conteúdo e de suas
relações deixariam janelas de inconsistência.

## Decisão

- A sessão usa clientes Supabase próprios para navegador e servidor. Um `proxy.ts` renova cookies e
  protege `/conta` e `/submissoes`; toda autorização final continua em RLS/RPC.
- Retornos pós-login aceitam apenas caminhos relativos internos. Callback, cadastro, login,
  recuperação e troca de senha usam Supabase Auth sem transportar segredo pela URL.
- `save_own_content_draft` grava conteúdo, autores ordenados, categoria principal e tags em uma
  transação. `lock_version` detecta outra aba desatualizada.
- Cada autosave recebe UUID de idempotência e gera recibo interno. Em indisponibilidade, o editor
  preserva uma cópia no `localStorage` identificada pelo UUID do conteúdo e informa o estado ao
  autor.
- `submit_own_content` registra versão dos termos e data, valida o agregado e delega a transição à
  máquina editorial. Versão, histórico, auditoria e outbox nascem na mesma transação. Um estado já
  `submitted` converge sem criar novo evento, mesmo com uma segunda chave.
- Rich text é documento JSON estruturado por TipTap. A validação de submissão exige texto real, e
  não apenas um objeto de documento vazio.
- Arquivos usam `content-drafts`, que é privado, no caminho
  `<user-id>/<content-id>/<asset-id>.<extensão>`. API, bucket, trigger de metadados e RLS validam
  tamanho, allowlist de MIME, extensão, propriedade e conteúdo editável. Imagem exige texto
  alternativo.

## Consequências

O autor recebe autosave resiliente e conflito explícito, enquanto o banco mantém a fonte de verdade.
Recibos crescem com o uso e precisarão de retenção operacional posterior. O fallback local não
substitui o banco nem é enviado automaticamente sem uma nova ação do usuário. Comentários editoriais
continuam fora deste escopo e entram na Etapa 5.
