import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';

import {
  editorialStatusLabels,
  getEditorialSession,
  listReviewQueue,
  submissionContentTypeLabels,
  type EditorialStatus,
  type SubmissionContentType,
} from '@/modules/editorial';
import { WorkflowFeedback } from '@/modules/editorial/presentation/workflow-panels';

export const metadata: Metadata = { title: 'Fila de revisão', robots: { index: false } };

type PageProperties = { searchParams: Promise<{ sucesso?: string; erro?: string }> };

export default async function ReviewQueuePage({ searchParams }: PageProperties) {
  const session = await getEditorialSession('/admin/revisao');
  if (!session.roles.some((role) => role === 'revisor' || role === 'diretor')) notFound();
  const feedback = await searchParams;
  const queue = await listReviewQueue();

  return (
    <main id="conteudo-principal" className="account-page admin-page">
      <WorkflowFeedback success={feedback.sucesso} error={feedback.erro} />
      <header className="page-heading">
        <p className="eyebrow">Operação editorial</p>
        <h1>Fila de revisão</h1>
        <p>Assuma uma pauta, registre o parecer na versão correta e encaminhe a decisão.</p>
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
                  <Link href={`/admin/revisao/${content.id}`}>{content.title}</Link>
                </h2>
                <p>
                  {content.reviewer_id
                    ? content.reviewer_id === session.userId
                      ? 'Atribuída a você'
                      : 'Atribuída a outra pessoa'
                    : 'Sem responsável'}
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
          <h2>Fila em dia</h2>
          <p>Não há matérias aguardando revisão neste momento.</p>
        </section>
      )}
    </main>
  );
}
