export const editableStatuses = ['draft', 'changes_requested'] as const;
export const editorialStatuses = [
  'draft',
  'submitted',
  'under_review',
  'changes_requested',
  'approved',
  'in_editing',
  'scheduled',
  'published',
  'rejected',
  'archived',
] as const;
export const submissionContentTypes = [
  'news',
  'weekly_article',
  'column',
  'poem',
  'essay',
  'short_story',
  'artwork',
  'notice',
] as const;

export type EditorialStatus = (typeof editorialStatuses)[number];
export type SubmissionContentType = (typeof submissionContentTypes)[number];

export const editorialStatusLabels: Record<EditorialStatus, string> = {
  draft: 'Rascunho',
  submitted: 'Enviada',
  under_review: 'Em revisão',
  changes_requested: 'Ajustes solicitados',
  approved: 'Aprovada',
  in_editing: 'Em edição',
  scheduled: 'Agendada',
  published: 'Publicada',
  rejected: 'Recusada',
  archived: 'Arquivada',
};

export const submissionContentTypeLabels: Record<SubmissionContentType, string> = {
  news: 'Notícia',
  weekly_article: 'Artigo semanal',
  column: 'Coluna',
  poem: 'Poema',
  essay: 'Ensaio',
  short_story: 'Conto',
  artwork: 'Arte ou fotografia',
  notice: 'Informe',
};

export function slugForDraft(title: string, contentId: string): string {
  const normalized = title
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
    .slice(0, 72)
    .replace(/-$/g, '');
  return `${normalized || 'rascunho'}-${contentId.slice(0, 8)}`;
}

export function richTextHasContent(body: unknown): boolean {
  if (!body || typeof body !== 'object') return false;
  const document = body as { text?: unknown; content?: unknown[] };
  if (typeof document.text === 'string' && document.text.trim().length > 0) return true;
  return Array.isArray(document.content) && document.content.some(richTextHasContent);
}
