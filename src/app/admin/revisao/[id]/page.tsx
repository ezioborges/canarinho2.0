import type { Metadata } from 'next';
import { notFound } from 'next/navigation';

import {
  addEditorialCommentAction,
  assignReviewerAction,
} from '@/modules/editorial/application/editorial-actions';
import {
  editorialStatusLabels,
  getEditorialDetail,
  submissionContentTypeLabels,
  type EditorialStatus,
  type SubmissionContentType,
} from '@/modules/editorial';
import {
  ReviewTransitions,
  WorkflowFeedback,
} from '@/modules/editorial/presentation/workflow-panels';
import { RichText, type RichTextDocument } from '@/modules/public-portal';

export const metadata: Metadata = { title: 'Revisão editorial', robots: { index: false } };

type PageProperties = {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ sucesso?: string; erro?: string }>;
};

export default async function ReviewDetailPage({ params, searchParams }: PageProperties) {
  const { id } = await params;
  const feedback = await searchParams;
  const detail = await getEditorialDetail(id);
  if (!detail.session.roles.some((role) => role === 'revisor' || role === 'diretor')) notFound();

  const status = detail.content.status as EditorialStatus;
  const canComment =
    status === 'under_review' &&
    (detail.session.roles.includes('diretor') ||
      detail.content.reviewer_id === detail.session.userId);
  const latestVersion = detail.versions[0];

  return (
    <main id="conteudo-principal" className="account-page admin-page">
      <WorkflowFeedback success={feedback.sucesso} error={feedback.erro} />
      <header className="page-heading page-heading--actions">
        <div>
          <p className="eyebrow">
            {submissionContentTypeLabels[detail.content.type as SubmissionContentType] ??
              detail.content.type}
          </p>
          <h1>{detail.content.title}</h1>
          <span className={`status-pill status-pill--${status}`}>
            {editorialStatusLabels[status]}
          </span>
        </div>
        <p className="lock-indicator">Revisão de concorrência #{detail.content.lock_version}</p>
      </header>

      {(status === 'submitted' || status === 'under_review') && detail.reviewers.length ? (
        <section className="workflow-panel" aria-labelledby="atribuicao-titulo">
          <h2 id="atribuicao-titulo">Responsável pela revisão</h2>
          <form className="workflow-action workflow-action--inline" action={assignReviewerAction}>
            <input type="hidden" name="contentId" value={id} />
            <input type="hidden" name="lockVersion" value={detail.content.lock_version} />
            <input type="hidden" name="area" value="revisao" />
            <label>
              Revisor
              <select
                name="reviewerId"
                defaultValue={detail.content.reviewer_id ?? detail.session.userId}
              >
                {detail.reviewers.map((reviewer) => (
                  <option key={reviewer.id} value={reviewer.id}>
                    {reviewer.display_name}
                  </option>
                ))}
              </select>
            </label>
            <label>
              Motivo da atribuição
              <input name="justification" minLength={3} maxLength={2000} required />
            </label>
            <button className="button button--secondary" type="submit">
              {detail.content.reviewer_id ? 'Reatribuir' : 'Assumir revisão'}
            </button>
          </form>
        </section>
      ) : null}

      <section className="editorial-preview" aria-labelledby="texto-titulo">
        <div>
          <p className="eyebrow">Versão em análise</p>
          <h2 id="texto-titulo">{detail.content.subtitle ?? detail.content.title}</h2>
          {detail.content.summary ? <p className="article-deck">{detail.content.summary}</p> : null}
          <p className="editorial-byline">
            Autoria:{' '}
            {detail.authors
              .map(
                (author) => author.display_name ?? author.profile_id ?? 'Autoria não identificada',
              )
              .join(', ')}
          </p>
        </div>
        <RichText document={detail.content.body as RichTextDocument} />
      </section>

      <section className="workflow-panel" aria-labelledby="parecer-titulo">
        <h2 id="parecer-titulo">Parecer e decisão</h2>
        {canComment && latestVersion ? (
          <form className="workflow-action" action={addEditorialCommentAction}>
            <input type="hidden" name="contentId" value={id} />
            <input type="hidden" name="versionId" value={latestVersion.id} />
            <input type="hidden" name="area" value="revisao" />
            <label>
              Comentário geral na versão {latestVersion.version_number}
              <textarea name="body" minLength={3} maxLength={4000} rows={4} required />
            </label>
            <button className="button button--secondary" type="submit">
              Registrar comentário
            </button>
          </form>
        ) : (
          <p className="empty-inline">
            Assuma a revisão para comentar. Comentários por trecho permanecem fora do MVP até a
            prova de conceito de âncoras estáveis.
          </p>
        )}
        {detail.comments.length ? (
          <ol className="comment-list">
            {detail.comments.map((comment) => {
              const version = detail.versions.find((entry) => entry.id === comment.version_id);
              return (
                <li key={comment.id}>
                  <strong>Versão {version?.version_number ?? '—'}</strong>
                  <time dateTime={comment.created_at}>
                    {new Intl.DateTimeFormat('pt-BR', {
                      dateStyle: 'medium',
                      timeStyle: 'short',
                    }).format(new Date(comment.created_at))}
                  </time>
                  <p>{comment.body}</p>
                </li>
              );
            })}
          </ol>
        ) : null}
        <ReviewTransitions
          contentId={id}
          lockVersion={detail.content.lock_version}
          status={status}
          roles={detail.session.roles}
        />
      </section>

      <section className="history-panel" aria-labelledby="historico-revisao-titulo">
        <h2 id="historico-revisao-titulo">Histórico editorial</h2>
        <ol className="timeline">
          {detail.history.map((entry) => (
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
      </section>
    </main>
  );
}
