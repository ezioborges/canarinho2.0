import type { Metadata } from 'next';
import { notFound } from 'next/navigation';

import { addNoticeCommentAction, getPublicNotice } from '@/modules/communications';

type Properties = {
  params: Promise<{ slug: string }>;
  searchParams: Promise<Record<string, string | string[] | undefined>>;
};

function single(value: string | string[] | undefined) {
  return Array.isArray(value) ? value[0] : value;
}

export async function generateMetadata({ params }: Properties): Promise<Metadata> {
  const { slug } = await params;
  const result = await getPublicNotice(slug);
  if (!result) return { title: 'Informe não encontrado', robots: { index: false } };
  return {
    title: result.notice.title,
    description: result.notice.summary,
    alternates: { canonical: `/informes/${result.notice.slug}` },
  };
}

export default async function NoticeDetailPage({ params, searchParams }: Properties) {
  const [{ slug }, query] = await Promise.all([params, searchParams]);
  const result = await getPublicNotice(slug);
  if (!result) notFound();
  const { notice, comments } = result;
  return (
    <main id="conteudo-principal" className="notice-detail-page">
      <article className="notice-detail">
        <header>
          <p className="eyebrow">Informe · {notice.audience}</p>
          <h1>{notice.title}</h1>
          <p className="article-deck">{notice.summary}</p>
          <time dateTime={notice.published_at}>
            Publicado em {new Date(notice.published_at).toLocaleDateString('pt-BR')}
          </time>
        </header>
        <div className="notice-detail__body">
          {notice.body.split('\n').map((paragraph) => (
            <p key={paragraph}>{paragraph}</p>
          ))}
        </div>
      </article>
      {notice.comments_enabled ? (
        <section className="comments-section" aria-labelledby="notice-comments-title">
          <h2 id="notice-comments-title">Conversa sobre este informe</h2>
          {single(query.sucesso) ? (
            <p className="form-message form-message--success">{single(query.sucesso)}</p>
          ) : null}
          {single(query.erro) ? (
            <p className="form-message form-message--error">{single(query.erro)}</p>
          ) : null}
          <form className="comment-form" action={addNoticeCommentAction}>
            <input type="hidden" name="noticeId" value={notice.id} />
            <input type="hidden" name="slug" value={notice.slug} />
            <input type="hidden" name="idempotencyKey" value={crypto.randomUUID()} />
            <label>
              Participe da conversa
              <textarea name="body" minLength={3} maxLength={2000} required />
            </label>
            <button className="button button--secondary" type="submit">
              Publicar comentário
            </button>
          </form>
          <div className="comment-list">
            {comments.map((comment) => (
              <article className="public-comment" key={comment.id}>
                <header>
                  <strong>Pessoa da comunidade</strong>
                  <time dateTime={comment.created_at}>
                    {new Date(comment.created_at).toLocaleString('pt-BR')}
                  </time>
                </header>
                <p>{comment.body}</p>
              </article>
            ))}
          </div>
        </section>
      ) : null}
    </main>
  );
}
