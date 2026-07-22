import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound, permanentRedirect } from 'next/navigation';

import { CommentSection, FavoriteButton, getContentCommunity } from '@/modules/community';
import {
  ContentCard,
  contentTypeLabels,
  CoverImage,
  getPublishedContent,
  primaryCategory,
  readingTimeInMinutes,
  resolvePublishedContentSlug,
  RichText,
} from '@/modules/public-portal';
import { publicEnvironment } from '@/shared/config/public-environment';

type ContentPageProperties = {
  params: Promise<{ slug: string }>;
  searchParams?: Promise<Record<string, string | string[] | undefined>>;
};

function singleValue(value: string | string[] | undefined): string | undefined {
  return Array.isArray(value) ? value[0] : value;
}

const dateFormatter = new Intl.DateTimeFormat('pt-BR', {
  day: '2-digit',
  month: 'long',
  year: 'numeric',
});

export async function generateMetadata({ params }: ContentPageProperties): Promise<Metadata> {
  const { slug } = await params;
  const content = await getPublishedContent(slug);

  if (!content)
    return { title: 'Conteúdo não encontrado', robots: { index: false, follow: false } };

  const canonicalPath = `/materias/${content.slug}`;
  const image = content.cover
    ? `/images/editorial/${content.cover.objectPath.split('/').at(-1)}`
    : undefined;

  return {
    title: content.seoTitle ?? content.title,
    description: content.seoDescription ?? content.summary ?? undefined,
    alternates: { canonical: canonicalPath },
    openGraph: {
      type: 'article',
      locale: 'pt_BR',
      title: content.seoTitle ?? content.title,
      description: content.seoDescription ?? content.summary ?? undefined,
      url: canonicalPath,
      publishedTime: content.publishedAt,
      authors: content.authors.map((author) => author.name),
      ...(image ? { images: [{ url: image, alt: content.cover?.alt }] } : {}),
    },
    twitter: {
      card: 'summary_large_image',
      title: content.seoTitle ?? content.title,
      description: content.seoDescription ?? content.summary ?? undefined,
      ...(image ? { images: [image] } : {}),
    },
  };
}

export default async function ContentDetailPage({ params, searchParams }: ContentPageProperties) {
  const { slug } = await params;
  const query = (await searchParams) ?? {};
  const content = await getPublishedContent(slug);

  if (!content) {
    const canonicalSlug = await resolvePublishedContentSlug(slug);
    if (canonicalSlug) permanentRedirect(`/materias/${canonicalSlug}`);
    notFound();
  }

  const beforeCreatedAt = singleValue(query.comentarios_antes);
  const beforeId = singleValue(query.comentario_id);
  const community = await getContentCommunity(
    content.id,
    beforeCreatedAt && beforeId ? { createdAt: beforeCreatedAt, id: beforeId } : undefined,
  );

  const category = primaryCategory(content);
  const readingTime = readingTimeInMinutes(content.body);
  const canonicalUrl = new URL(
    `/materias/${content.slug}`,
    publicEnvironment.NEXT_PUBLIC_SITE_URL,
  ).toString();
  const structuredData = {
    '@context': 'https://schema.org',
    '@type': 'Article',
    headline: content.title,
    description: content.seoDescription ?? content.summary,
    datePublished: content.publishedAt,
    mainEntityOfPage: canonicalUrl,
    author: content.authors.map((author) => ({ '@type': 'Person', name: author.name })),
  };

  return (
    <main id="conteudo-principal" className="article-page">
      <article>
        <header className="article-header">
          <div className="article-header__kicker">
            {category ? (
              <Link href={`/categorias/${category.slug}`}>{category.name}</Link>
            ) : (
              <span>{contentTypeLabels[content.type]}</span>
            )}
            <span aria-hidden="true">·</span>
            <span>{contentTypeLabels[content.type]}</span>
          </div>
          <h1>{content.title}</h1>
          {content.subtitle && <p className="article-deck">{content.subtitle}</p>}
          <div className="article-meta">
            <p>
              Por{' '}
              {content.authors.map((author, index) => (
                <span key={author.id ?? author.name}>
                  {index > 0 && ', '}
                  {author.id ? (
                    <Link href={`/autores/${author.id}`}>{author.name}</Link>
                  ) : (
                    author.name
                  )}
                </span>
              ))}
            </p>
            <p>
              <time dateTime={content.publishedAt}>
                {dateFormatter.format(new Date(content.publishedAt))}
              </time>
              <span aria-hidden="true"> · </span>
              {readingTime} min de leitura
            </p>
          </div>
          <FavoriteButton
            contentId={content.id}
            slug={content.slug}
            favorite={community.favorite}
            authenticated={community.authenticated}
          />
        </header>

        <figure className="article-cover">
          <CoverImage cover={content.cover} priority sizes="(max-width: 80rem) 100vw, 76rem" />
          {content.cover && (
            <figcaption>
              {content.cover.credit}
              {content.cover.license ? ` · ${content.cover.license}` : ''}
            </figcaption>
          )}
        </figure>

        <div className="article-layout">
          <aside className="share-links" aria-label="Compartilhar matéria">
            <span>Compartilhar</span>
            <a
              href={`https://wa.me/?text=${encodeURIComponent(`${content.title} ${canonicalUrl}`)}`}
              target="_blank"
              rel="noreferrer"
              aria-label="Compartilhar no WhatsApp"
            >
              WA
            </a>
            <a
              href={`https://www.linkedin.com/sharing/share-offsite/?url=${encodeURIComponent(canonicalUrl)}`}
              target="_blank"
              rel="noreferrer"
              aria-label="Compartilhar no LinkedIn"
            >
              in
            </a>
            <a
              href={`mailto:?subject=${encodeURIComponent(content.title)}&body=${encodeURIComponent(canonicalUrl)}`}
              aria-label="Compartilhar por email"
            >
              @
            </a>
          </aside>
          <RichText document={content.body} />
          <aside className="article-taxonomy" aria-label="Assuntos desta matéria">
            {content.tags.length > 0 && (
              <>
                <span>Assuntos</span>
                <ul>
                  {content.tags.map((tag) => (
                    <li key={tag.slug}>
                      <Link href={`/tags/${tag.slug}`}>#{tag.name}</Link>
                    </li>
                  ))}
                </ul>
              </>
            )}
            {content.editions.map((edition) => (
              <Link className="edition-chip" href={`/edicoes/${edition.slug}`} key={edition.slug}>
                Edição #{edition.issueNumber}: {edition.title}
              </Link>
            ))}
          </aside>
        </div>
      </article>

      {content.related.length > 0 && (
        <section className="related-section" aria-labelledby="related-title">
          <div className="section-heading">
            <div>
              <p className="eyebrow">Continue lendo</p>
              <h2 id="related-title">Histórias relacionadas</h2>
            </div>
          </div>
          <div className="feature-grid">
            {content.related.map((related) => (
              <ContentCard content={related} key={related.id} />
            ))}
          </div>
        </section>
      )}
      <CommentSection
        contentId={content.id}
        slug={content.slug}
        community={community}
        message={singleValue(query.sucesso)}
        error={singleValue(query.erro)}
      />
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{
          __html: JSON.stringify(structuredData).replaceAll('<', '\\u003c'),
        }}
      />
    </main>
  );
}
