import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';

import {
  editorialStatusLabels,
  getEditorialSession,
  listEditorQueue,
  submissionContentTypeLabels,
  type EditorialStatus,
  type SubmissionContentType,
} from '@/modules/editorial';

export const metadata: Metadata = { title: 'Edição e publicação', robots: { index: false } };

export default async function EditorQueuePage() {
  const session = await getEditorialSession('/admin/editorial');
  if (!session.roles.some((role) => role === 'editor' || role === 'diretor')) notFound();
  const queue = await listEditorQueue();

  return (
    <main id="conteudo-principal" className="account-page admin-page">
      <header className="page-heading">
        <p className="eyebrow">Operação editorial</p>
        <h1>Edição e publicação</h1>
        <p>Prepare metadados, compare versões, agende, publique e organize os destaques.</p>
      </header>
      {queue.length ? (
        <div className="submission-list">
          {queue.map((content) => (
            <article className="submission-card" key={content.id}>
              <div>
                <p className="submission-card__meta">
                  {submissionContentTypeLabels[content.type as SubmissionContentType] ??
                    content.type}
                </p>
                <h2>
                  <Link href={`/admin/editorial/${content.id}`}>{content.title}</Link>
                </h2>
                <p>
                  {content.scheduled_at
                    ? `Agendada para ${new Intl.DateTimeFormat('pt-BR', {
                        dateStyle: 'medium',
                        timeStyle: 'short',
                      }).format(new Date(content.scheduled_at))}`
                    : `Atualizada em ${new Intl.DateTimeFormat('pt-BR', {
                        dateStyle: 'medium',
                        timeStyle: 'short',
                      }).format(new Date(content.updated_at))}`}
                </p>
              </div>
              <span className={`status-pill status-pill--${content.status}`}>
                {editorialStatusLabels[content.status as EditorialStatus] ?? content.status}
              </span>
            </article>
          ))}
        </div>
      ) : (
        <section className="empty-state">
          <h2>Nenhuma matéria em edição</h2>
          <p>Conteúdos aprovados aparecerão aqui automaticamente.</p>
        </section>
      )}
    </main>
  );
}
