import Link from 'next/link';

import { listPublicNotices, NewsletterForm } from '@/modules/communications';

function single(value: string | string[] | undefined) {
  return Array.isArray(value) ? value[0] : value;
}

export const revalidate = 120;

export default async function NoticesPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const [notices, query] = await Promise.all([listPublicNotices(), searchParams]);
  return (
    <main id="conteudo-principal" className="notices-page">
      <header className="page-intro">
        <p className="eyebrow">Comunidade</p>
        <h1>Quadro de informes</h1>
        <p>Chamadas, oportunidades, eventos e recados que ajudam a comunidade a se encontrar.</p>
      </header>
      <section className="notice-grid" aria-label="Informes publicados">
        {notices.map((notice) => (
          <article
            className={`notice-card${notice.pinned ? ' notice-card--pinned' : ''}`}
            key={notice.id}
          >
            <div>
              {notice.pinned ? <span className="status-pill">Fixado</span> : null}
              <span className="notice-card__audience">{notice.audience}</span>
            </div>
            <h2>
              <Link href={`/informes/${notice.slug}`}>{notice.title}</Link>
            </h2>
            <p>{notice.summary}</p>
            <time dateTime={notice.published_at}>
              {new Date(notice.published_at).toLocaleDateString('pt-BR')}
            </time>
          </article>
        ))}
        {!notices.length ? <p className="empty-state">Nenhum informe publicado agora.</p> : null}
      </section>
      <section className="newsletter-panel" aria-labelledby="newsletter-title">
        <div>
          <p className="eyebrow">Carta do Canarinho</p>
          <h2 id="newsletter-title">Novidades com consentimento e sem ruído.</h2>
          <p>Você confirma o endereço antes do primeiro envio e pode sair por qualquer mensagem.</p>
        </div>
        <div>
          {single(query.newsletter) ? (
            <p className="form-message" role="status">
              {single(query.newsletter)}
            </p>
          ) : null}
          <NewsletterForm returnPath="/informes" />
        </div>
      </section>
    </main>
  );
}
