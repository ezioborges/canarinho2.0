import type { Metadata } from 'next';
import Link from 'next/link';

import {
  editorialStatusLabels,
  listOwnSubmissions,
  submissionContentTypeLabels,
  type EditorialStatus,
  type SubmissionContentType,
} from '@/modules/editorial';

export const metadata: Metadata = { title: 'Minhas submissões', robots: { index: false } };

export default async function SubmissionsPage() {
  const submissions = await listOwnSubmissions();
  return (
    <main id="conteudo-principal" className="account-page">
      <header className="page-heading page-heading--actions">
        <div>
          <p className="eyebrow">Área do autor</p>
          <h1>Minhas submissões</h1>
          <p>Acompanhe rascunhos, retornos da revisão e matérias já enviadas.</p>
        </div>
        <Link className="button button--primary" href="/submissoes/nova">
          Nova submissão
        </Link>
      </header>
      {submissions.length ? (
        <div className="submission-list">
          {submissions.map((submission) => (
            <article className="submission-card" key={submission.id}>
              <div>
                <p className="submission-card__meta">
                  {submissionContentTypeLabels[submission.type as SubmissionContentType] ??
                    submission.type}
                </p>
                <h2>
                  <Link href={`/submissoes/${submission.id}`}>{submission.title}</Link>
                </h2>
                <p>
                  Atualizada em{' '}
                  {new Intl.DateTimeFormat('pt-BR', {
                    dateStyle: 'medium',
                    timeStyle: 'short',
                  }).format(new Date(submission.updated_at))}
                </p>
              </div>
              <span className={`status-pill status-pill--${submission.status}`}>
                {editorialStatusLabels[submission.status as EditorialStatus] ?? submission.status}
              </span>
            </article>
          ))}
        </div>
      ) : (
        <section className="empty-state">
          <h2>Sua primeira pauta começa aqui</h2>
          <p>Crie um rascunho; ele será salvo automaticamente enquanto você escreve.</p>
          <Link className="button button--primary" href="/submissoes/nova">
            Começar uma submissão
          </Link>
        </section>
      )}
    </main>
  );
}
