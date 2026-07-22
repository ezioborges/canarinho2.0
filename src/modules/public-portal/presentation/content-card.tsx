import Link from 'next/link';

import { contentTypeLabels, primaryCategory, type PublicContentCard } from '../domain/content';
import { CoverImage } from './cover-image';

type ContentCardProperties = {
  content: PublicContentCard;
  imagePriority?: boolean;
  variant?: 'default' | 'compact' | 'feature' | 'gallery';
};

const dateFormatter = new Intl.DateTimeFormat('pt-BR', {
  day: '2-digit',
  month: 'short',
  year: 'numeric',
});

export function ContentCard({
  content,
  imagePriority = false,
  variant = 'default',
}: ContentCardProperties) {
  const category = primaryCategory(content);
  const authorNames = content.authors.map((author) => author.name).join(', ');

  return (
    <article className={`content-card content-card--${variant}`}>
      {variant !== 'compact' && (
        <Link className="content-card__media" href={`/materias/${content.slug}`} tabIndex={-1}>
          <CoverImage
            cover={content.cover}
            priority={imagePriority}
            sizes={
              variant === 'feature'
                ? '(max-width: 60rem) 100vw, 58vw'
                : '(max-width: 45rem) 100vw, 33vw'
            }
          />
        </Link>
      )}
      <div className="content-card__body">
        <div className="content-card__kicker">
          {category ? (
            <Link href={`/categorias/${category.slug}`}>{category.name}</Link>
          ) : (
            <span>{contentTypeLabels[content.type]}</span>
          )}
          <span aria-hidden="true">·</span>
          <time dateTime={content.publishedAt}>
            {dateFormatter.format(new Date(content.publishedAt))}
          </time>
        </div>
        <h3>
          <Link href={`/materias/${content.slug}`}>{content.title}</Link>
        </h3>
        {variant !== 'compact' && content.summary && <p>{content.summary}</p>}
        {authorNames && <p className="content-card__byline">Por {authorNames}</p>}
      </div>
    </article>
  );
}
