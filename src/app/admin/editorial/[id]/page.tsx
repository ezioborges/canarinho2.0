import type { Metadata } from 'next';
import { notFound } from 'next/navigation';

import { restoreEditorialVersionAction } from '@/modules/editorial/application/editorial-actions';
import {
  editorialStatusLabels,
  getEditorialDetail,
  submissionContentTypeLabels,
  type EditorialStatus,
  type SubmissionContentType,
} from '@/modules/editorial';
import { FinalEditor } from '@/modules/editorial/presentation/final-editor';
import {
  EditorTransitions,
  WorkflowFeedback,
} from '@/modules/editorial/presentation/workflow-panels';

export const metadata: Metadata = { title: 'Mesa de edição', robots: { index: false } };

type PageProperties = {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ sucesso?: string; erro?: string }>;
};

function snapshotValue(snapshot: Record<string, unknown> | undefined, key: string): string {
  const value = snapshot?.[key];
  return typeof value === 'string' && value.trim() ? value : '—';
}

export default async function EditorialDetailPage({ params, searchParams }: PageProperties) {
  const { id } = await params;
  const feedback = await searchParams;
  const detail = await getEditorialDetail(id);
  if (!detail.session.roles.some((role) => role === 'editor' || role === 'diretor')) notFound();
  const status = detail.content.status as EditorialStatus;
  const editable = status === 'in_editing' || status === 'published';
  const comparison = detail.versions.slice(0, 2);

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

      {editable ? (
        <FinalEditor detail={detail} />
      ) : (
        <section className="workflow-panel">
          <h2>Conteúdo protegido neste estado</h2>
          <p>
            Assuma a edição ou cancele o agendamento antes de alterar texto e metadados. Isso evita
            escrita silenciosa fora da máquina de estados.
          </p>
        </section>
      )}

      <section className="workflow-panel" aria-labelledby="publicacao-titulo">
        <h2 id="publicacao-titulo">Fluxo de publicação</h2>
        <p>
          Publicação e agendamento revalidam conteúdo, autoria, categoria, SEO e capa pública com
          texto alternativo no banco.
        </p>
        <EditorTransitions
          contentId={id}
          lockVersion={detail.content.lock_version}
          status={status}
          roles={detail.session.roles}
        />
      </section>

      <section className="workflow-panel" aria-labelledby="versoes-titulo">
        <h2 id="versoes-titulo">Versões e restauração</h2>
        {comparison.length >= 2 ? (
          <div
            className="version-comparison"
            aria-label="Comparação das duas versões mais recentes"
          >
            {comparison.map((version) => (
              <article key={version.id}>
                <p className="eyebrow">Versão {version.version_number}</p>
                <h3>{snapshotValue(version.snapshot.content, 'title')}</h3>
                <p>{snapshotValue(version.snapshot.content, 'summary')}</p>
                <small>
                  {version.reason} ·{' '}
                  {new Intl.DateTimeFormat('pt-BR', {
                    dateStyle: 'medium',
                    timeStyle: 'short',
                  }).format(new Date(version.created_at))}
                </small>
              </article>
            ))}
          </div>
        ) : (
          <p className="empty-inline">A comparação aparece após a segunda versão relevante.</p>
        )}
        {detail.versions.length ? (
          <ol className="version-list">
            {detail.versions.map((version) => (
              <li key={version.id}>
                <div>
                  <strong>Versão {version.version_number}</strong>
                  <span>{version.reason}</span>
                  <time dateTime={version.created_at}>
                    {new Intl.DateTimeFormat('pt-BR', {
                      dateStyle: 'medium',
                      timeStyle: 'short',
                    }).format(new Date(version.created_at))}
                  </time>
                </div>
                {status === 'in_editing' ? (
                  <form className="restore-form" action={restoreEditorialVersionAction}>
                    <input type="hidden" name="contentId" value={id} />
                    <input type="hidden" name="versionId" value={version.id} />
                    <input type="hidden" name="lockVersion" value={detail.content.lock_version} />
                    <label>
                      <span className="sr-only">
                        Motivo para restaurar versão {version.version_number}
                      </span>
                      <input
                        name="justification"
                        minLength={3}
                        maxLength={2000}
                        placeholder="Motivo da restauração"
                        required
                      />
                    </label>
                    <button className="button button--text" type="submit">
                      Restaurar
                    </button>
                  </form>
                ) : null}
              </li>
            ))}
          </ol>
        ) : (
          <p className="empty-inline">Nenhum snapshot editorial disponível.</p>
        )}
      </section>

      <section className="history-panel" aria-labelledby="historico-editor-titulo">
        <h2 id="historico-editor-titulo">Histórico de estados</h2>
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
              <p>
                {entry.reason}
                {entry.actor_kind === 'system' ? ` — ${entry.actor_label}` : ''}
              </p>
            </li>
          ))}
        </ol>
      </section>
    </main>
  );
}
