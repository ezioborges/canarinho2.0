import Link from 'next/link';

import type { ContentCommunity } from '../infrastructure/community.repository';
import { addPublicCommentAction, reportCommentAction } from '../application/community-actions';

const dateFormatter = new Intl.DateTimeFormat('pt-BR', {
  dateStyle: 'medium',
  timeStyle: 'short',
});

export function CommentSection({
  contentId,
  slug,
  community,
  message,
  error,
}: {
  contentId: string;
  slug: string;
  community: ContentCommunity;
  message?: string | undefined;
  error?: string | undefined;
}) {
  const lastComment = community.comments.at(-1);
  return (
    <section className="comments-section" id="comentarios" aria-labelledby="comments-title">
      <div className="section-heading">
        <div>
          <p className="eyebrow">Comunidade</p>
          <h2 id="comments-title">Comentários</h2>
        </div>
      </div>
      {message ? <p className="form-message form-message--success">{message}</p> : null}
      {error ? <p className="form-message form-message--error">{error}</p> : null}
      <div className="community-guidelines">
        <strong>Converse com cuidado.</strong> Ataques pessoais, discriminação, spam e exposição de
        dados pessoais serão moderados. Denúncias são analisadas pela equipe.
      </div>
      {community.authenticated ? (
        <form className="comment-form" action={addPublicCommentAction}>
          <input type="hidden" name="contentId" value={contentId} />
          <input type="hidden" name="slug" value={slug} />
          <input type="hidden" name="idempotencyKey" value={crypto.randomUUID()} />
          <label htmlFor="new-comment">Participe da conversa</label>
          <textarea id="new-comment" name="body" minLength={3} maxLength={2000} required />
          <button className="button button--primary" type="submit">
            Publicar comentário
          </button>
        </form>
      ) : (
        <p>
          <Link href={`/entrar?retorno=/materias/${slug}`}>Entre na sua conta</Link> para comentar.
        </p>
      )}
      <div className="comment-list">
        {community.comments.map((comment) => (
          <article className="public-comment" key={comment.id}>
            <header>
              <strong>{comment.authorName}</strong>
              <time dateTime={comment.createdAt}>
                {dateFormatter.format(new Date(comment.createdAt))}
              </time>
            </header>
            <p>{comment.body}</p>
            {community.authenticated ? (
              <details>
                <summary>Denunciar</summary>
                <form action={reportCommentAction}>
                  <input type="hidden" name="commentId" value={comment.id} />
                  <input type="hidden" name="slug" value={slug} />
                  <label>
                    Motivo da denúncia
                    <input name="reason" minLength={3} maxLength={1000} required />
                  </label>
                  <button className="button button--text" type="submit">
                    Enviar denúncia
                  </button>
                </form>
              </details>
            ) : null}
          </article>
        ))}
        {!community.comments.length ? <p>A conversa ainda não começou.</p> : null}
      </div>
      {community.hasMore && lastComment ? (
        <Link
          className="button button--secondary"
          href={`/materias/${slug}?comentarios_antes=${encodeURIComponent(lastComment.createdAt)}&comentario_id=${lastComment.id}#comentarios`}
        >
          Ver comentários anteriores
        </Link>
      ) : null}
    </section>
  );
}
