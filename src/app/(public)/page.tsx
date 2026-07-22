import Link from 'next/link';

import { NewsletterForm } from '@/modules/communications';
import { ContentCard, getPublicHomepage } from '@/modules/public-portal';

export const revalidate = 300;

export default async function HomePage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const [homepage, query] = await Promise.all([getPublicHomepage(), searchParams]);
  const hero = homepage.hero;

  return (
    <main id="conteudo-principal">
      {hero ? (
        <section className="home-hero" aria-labelledby="home-hero-title">
          <div className="section-label">
            <span>Edição em movimento</span>
            <span>01 / 2026</span>
          </div>
          <ContentCard content={hero} variant="feature" imagePriority />
        </section>
      ) : (
        <section className="home-hero empty-state" aria-labelledby="home-hero-title">
          <h1 id="home-hero-title">A próxima história começa aqui.</h1>
          <p>Assim que a primeira matéria for publicada, ela aparecerá neste espaço.</p>
        </section>
      )}

      <section className="home-section" aria-labelledby="featured-title">
        <div className="section-heading">
          <div>
            <p className="eyebrow">Seleção editorial</p>
            <h2 id="featured-title">Para começar por aqui</h2>
          </div>
          <Link href="/materias">
            Ver todas as matérias <span aria-hidden="true">→</span>
          </Link>
        </div>
        <div className="feature-grid">
          {homepage.featured.map((content) => (
            <ContentCard key={content.id} content={content} />
          ))}
        </div>
      </section>

      <section className="home-section home-section--ink" aria-labelledby="weekly-title">
        <div className="section-heading section-heading--light">
          <div>
            <p className="eyebrow">Ideias em circulação</p>
            <h2 id="weekly-title">Artigos da semana</h2>
          </div>
          <Link href="/materias?tipo=weekly_article">
            Explorar artigos <span aria-hidden="true">→</span>
          </Link>
        </div>
        <div className="weekly-list">
          {homepage.weekly.map((content, index) => (
            <div className="weekly-list__item" key={content.id}>
              <span aria-hidden="true">0{index + 1}</span>
              <ContentCard content={content} variant="compact" />
            </div>
          ))}
        </div>
      </section>

      <section className="home-section" aria-labelledby="poems-title">
        <div className="section-heading">
          <div>
            <p className="eyebrow">Literatura</p>
            <h2 id="poems-title">Palavras para guardar</h2>
          </div>
          <Link href="/materias?tipo=poem">
            Ler mais poemas <span aria-hidden="true">→</span>
          </Link>
        </div>
        <div className="literary-grid">
          {homepage.poems.map((content) => (
            <ContentCard key={content.id} content={content} />
          ))}
        </div>
      </section>

      {homepage.gallery.length > 0 && (
        <section className="home-section" aria-labelledby="gallery-title">
          <div className="section-heading">
            <div>
              <p className="eyebrow">Galeria</p>
              <h2 id="gallery-title">Olhares da comunidade</h2>
            </div>
            <Link href="/materias?tipo=artwork">
              Abrir galeria <span aria-hidden="true">→</span>
            </Link>
          </div>
          <div className="gallery-grid">
            {homepage.gallery.map((content) => (
              <ContentCard key={content.id} content={content} variant="gallery" />
            ))}
          </div>
        </section>
      )}

      <section className="edition-newsletter" aria-label="Edições e newsletter">
        <div className="edition-callout">
          <p className="eyebrow">Edição atual</p>
          {homepage.editions[0] ? (
            <>
              <p className="edition-number">
                #{String(homepage.editions[0].issueNumber ?? 1).padStart(2, '0')}
              </p>
              <h2>{homepage.editions[0].title}</h2>
              <p>{homepage.editions[0].summary}</p>
              <Link href={`/edicoes/${homepage.editions[0].slug}`}>Conhecer esta edição →</Link>
            </>
          ) : (
            <p>A primeira edição está sendo preparada.</p>
          )}
        </div>
        <div className="newsletter-callout">
          <p className="eyebrow">Carta do Canarinho</p>
          <h2>Histórias novas, sem barulho.</h2>
          <p>Receba uma mensagem quando uma nova edição pousar por aqui.</p>
          {query.newsletter ? (
            <p className="form-message" role="status">
              {Array.isArray(query.newsletter) ? query.newsletter[0] : query.newsletter}
            </p>
          ) : null}
          <NewsletterForm />
        </div>
      </section>
    </main>
  );
}
