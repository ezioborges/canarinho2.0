import Link from 'next/link';

import type { ContentFilters } from '../domain/content';
import { listPublishedContent } from '../infrastructure/public-content.repository';
import { ContentGrid } from './content-grid';

type FilteredArchiveProperties = {
  description: string;
  eyebrow: string;
  filters: ContentFilters;
  title: string;
};

export async function FilteredArchive({
  description,
  eyebrow,
  filters,
  title,
}: FilteredArchiveProperties) {
  const listing = await listPublishedContent(filters);

  return (
    <main id="conteudo-principal" className="listing-page">
      <header className="page-intro">
        <p className="eyebrow">{eyebrow}</p>
        <h1>{title}</h1>
        <p>{description}</p>
      </header>
      <div className="listing-summary">
        <p>
          <strong>{listing.total}</strong> {listing.total === 1 ? 'publicação' : 'publicações'}
        </p>
        <Link href="/materias">Voltar ao arquivo completo</Link>
      </div>
      <ContentGrid contents={listing.items} />
    </main>
  );
}
