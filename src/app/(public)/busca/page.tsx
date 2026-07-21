import type { Metadata } from 'next';
import Link from 'next/link';

import { ContentGrid, listPublishedContent } from '@/modules/public-portal';

export const metadata: Metadata = {
  title: 'Busca',
  description: 'Busque no conteúdo publicado do Canarinho.',
  alternates: { canonical: '/busca' },
};

export default async function SearchPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string }>;
}) {
  const { q = '' } = await searchParams;
  const query = q.trim();
  const listing = query ? await listPublishedContent({ query }) : { items: [], total: 0 };

  return (
    <main id="conteudo-principal" className="listing-page search-page">
      <header className="page-intro">
        <p className="eyebrow">Busca</p>
        <h1>Encontre uma história</h1>
      </header>
      <form className="big-search" action="/busca" role="search">
        <label className="sr-only" htmlFor="search-query">
          Termo de busca
        </label>
        <input
          id="search-query"
          name="q"
          type="search"
          defaultValue={query}
          autoFocus
          placeholder="Ciência, cultura, campus…"
        />
        <button type="submit">
          Buscar <span aria-hidden="true">→</span>
        </button>
      </form>
      {query ? (
        <>
          <div className="listing-summary" aria-live="polite">
            <p>
              <strong>{listing.total}</strong> resultados para “{query}”
            </p>
            <Link href="/materias">Explorar todo o arquivo</Link>
          </div>
          <ContentGrid
            contents={listing.items}
            emptyDescription="Tente uma palavra mais ampla ou explore todas as matérias publicadas."
          />
        </>
      ) : (
        <div className="empty-state">
          <span aria-hidden="true">⌕</span>
          <h2>Por onde começamos?</h2>
          <p>Digite um assunto, título ou palavra presente na matéria.</p>
        </div>
      )}
    </main>
  );
}
