import { notFound } from 'next/navigation';

import { listModerationQueue, moderateCommentAction } from '@/modules/community';
import { getEditorialSession } from '@/modules/editorial';

function single(value: string | string[] | undefined) {
  return Array.isArray(value) ? value[0] : value;
}

export default async function CommunityAdminPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const [session, query] = await Promise.all([
    getEditorialSession('/admin/comunidade'),
    searchParams,
  ]);
  if (!session.roles.some((role) => role === 'editor' || role === 'diretor')) notFound();
  const comments = await listModerationQueue();

  return (
    <main id="conteudo-principal" className="editor-page admin-community-page">
      <header className="page-intro">
        <p className="eyebrow">Moderação</p>
        <h1>Conversa da comunidade</h1>
        <p>Ocultar, restaurar ou remover nunca apaga a autoria da decisão.</p>
      </header>
      {single(query.sucesso) ? (
        <p className="form-message form-message--success">{single(query.sucesso)}</p>
      ) : null}
      {single(query.erro) ? (
        <p className="form-message form-message--error">{single(query.erro)}</p>
      ) : null}
      <div className="moderation-list">
        {comments.map((comment) => (
          <article className="moderation-card" key={comment.id}>
            <header>
              <span className="status-pill">{comment.status}</span>
              <time dateTime={comment.created_at}>
                {new Date(comment.created_at).toLocaleString('pt-BR')}
              </time>
            </header>
            <p>{comment.body}</p>
            {comment.comment_reports.length ? (
              <div className="report-list">
                <strong>{comment.comment_reports.length} denúncia(s)</strong>
                {comment.comment_reports.map((report) => (
                  <p key={report.id}>{report.reason}</p>
                ))}
              </div>
            ) : (
              <small>Sem denúncias.</small>
            )}
            <form className="moderation-form" action={moderateCommentAction}>
              <input type="hidden" name="commentId" value={comment.id} />
              <label>
                Decisão
                <select
                  name="action"
                  defaultValue={comment.status === 'visible' ? 'hide' : 'restore'}
                >
                  <option value="hide">Ocultar</option>
                  <option value="restore">Restaurar</option>
                  <option value="remove">Remover logicamente</option>
                </select>
              </label>
              <label>
                Motivo
                <input name="reason" minLength={3} maxLength={1000} required />
              </label>
              <button className="button button--secondary" type="submit">
                Registrar moderação
              </button>
            </form>
          </article>
        ))}
        {!comments.length ? (
          <div className="empty-state">
            <p>Nenhum comentário para moderar.</p>
          </div>
        ) : null}
      </div>
    </main>
  );
}
