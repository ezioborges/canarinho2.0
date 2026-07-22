import type { Metadata } from 'next';
import Link from 'next/link';

import {
  editableStatuses,
  editorialStatusLabels,
  getOwnSubmission,
  submissionContentTypeLabels,
  type EditorialStatus,
  type SubmissionContentType,
} from '@/modules/editorial';

export const metadata: Metadata = { title: 'Detalhe da submissão', robots: { index: false } };
type PageProperties = {
  params: Promise<{ id: string }>;
  searchParams: Promise<Record<string, string | string[] | undefined>>;
};

export default async function SubmissionDetailPage({ params, searchParams }: PageProperties) {
  const { id } = await params;
  const submission = await getOwnSubmission(id);
  const parameters = await searchParams;
  const status = submission.content.status as EditorialStatus;
  const editable = editableStatuses.includes(status as (typeof editableStatuses)[number]);
  return (
    <main id="conteudo-principal" className="account-page">
      {parameters.enviada === '1' ? (
        <p className="form-message form-message--success">Submissão enviada para revisão.</p>
      ) : null}
      <header className="page-heading page-heading--actions">
        <div>
          <p className="eyebrow">
            {submissionContentTypeLabels[submission.content.type as SubmissionContentType]}
          </p>
          <h1>{submission.content.title}</h1>
          <span className={`status-pill status-pill--${status}`}>
            {editorialStatusLabels[status]}
          </span>
        </div>
        {editable ? (
          <Link className="button button--primary" href={`/submissoes/${id}/editar`}>
            Editar rascunho
          </Link>
        ) : null}
      </header>
      {submission.comments.length ? (
        <section className="workflow-panel" aria-labelledby="comentarios-editoriais-titulo">
          <h2 id="comentarios-editoriais-titulo">Comentários da revisão</h2>
          <ol className="comment-list">
            {submission.comments.map((comment) => (
              <li key={comment.id}>
                <strong>Equipe editorial</strong>
                <time dateTime={comment.created_at}>
                  {new Intl.DateTimeFormat('pt-BR', {
                    dateStyle: 'medium',
                    timeStyle: 'short',
                  }).format(new Date(comment.created_at))}
                </time>
                <p>{comment.body}</p>
              </li>
            ))}
          </ol>
        </section>
      ) : null}
      <section className="history-panel" aria-labelledby="historico-titulo">
        <h2 id="historico-titulo">Histórico editorial</h2>
        {submission.history.length ? (
          <ol className="timeline">
            {submission.history.map((entry) => (
              <li key={entry.id}>
                <strong>
                  {editorialStatusLabels[entry.to_status as EditorialStatus] ?? entry.to_status}
                </strong>
                <time dateTime={entry.created_at}>
                  {new Intl.DateTimeFormat('pt-BR', {
                    dateStyle: 'long',
                    timeStyle: 'short',
                  }).format(new Date(entry.created_at))}
                </time>
                <p>{entry.reason}</p>
              </li>
            ))}
          </ol>
        ) : (
          <p>O histórico será iniciado quando o rascunho for enviado.</p>
        )}
      </section>
    </main>
  );
}
