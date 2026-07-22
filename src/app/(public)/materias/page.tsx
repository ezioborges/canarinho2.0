import type { Metadata, Route } from 'next';
import Link from 'next/link';

import {
  ContentGrid,
  contentTypeLabels,
  contentTypes,
  isContentType,
  listPublishedContent,
  publicListingPageSize,
  type ContentFilters,
} from '@/modules/public-portal';

export const metadata: Metadata = {
  title: 'Matérias',
  description: 'Notícias, artigos, poemas e produções da comunidade Canarinho.',
  alternates: { canonical: '/materias' },
};

type ListingSearchParameters = Promise<Record<string, string | string[] | undefined>>;

function singleValue(value: string | string[] | undefined): string | undefined {
  return Array.isArray(value) ? value[0] : value;
}

function toFilters(parameters: Record<string, string | string[] | undefined>): ContentFilters {
  const type = singleValue(parameters.tipo);
  const requestedPage = Number(singleValue(parameters.pagina) ?? '1');
  const query = singleValue(parameters.q);
  const category = singleValue(parameters.categoria);
  const tag = singleValue(parameters.tag);
  const from = singleValue(parameters.de);
  const to = singleValue(parameters.ate);

  return {
    ...(query ? { query } : {}),
    ...(category ? { category } : {}),
    ...(tag ? { tag } : {}),
    ...(from ? { from } : {}),
    ...(to ? { to } : {}),
    ...(isContentType(type) ? { type } : {}),
    page: Number.isFinite(requestedPage) ? Math.max(1, Math.floor(requestedPage)) : 1,
  };
}

function pageHref(parameters: Record<string, string | string[] | undefined>, page: number): Route {
  const nextParameters = new URLSearchParams();
  for (const [key, value] of Object.entries(parameters)) {
    const selected = singleValue(value);
    if (selected && key !== 'pagina') nextParameters.set(key, selected);
  }
  if (page > 1) nextParameters.set('pagina', String(page));
  return `/materias${nextParameters.size > 0 ? `?${nextParameters}` : ''}` as Route;
}

export default async function ContentListingPage({
  searchParams,
}: {
  searchParams: ListingSearchParameters;
}) {
  const parameters = await searchParams;
  const filters = toFilters(parameters);
  const listing = await listPublishedContent(filters);
  const currentPage = filters.page ?? 1;
  const pageCount = Math.max(1, Math.ceil(listing.total / publicListingPageSize));

  return (
    <main id="conteudo-principal" className="listing-page">
      <header className="page-intro">
        <p className="eyebrow">Arquivo aberto</p>
        <h1>Todas as histórias</h1>
        <p>Explore notícias, ideias, poemas e imagens que circulam pela comunidade.</p>
      </header>

      <form className="content-filters" action="/materias" method="get" role="search">
        <div className="field field--wide">
          <label htmlFor="listing-query">O que você procura?</label>
          <input
            id="listing-query"
            name="q"
            type="search"
            defaultValue={filters.query}
            placeholder="Digite um tema ou palavra"
          />
        </div>
        <div className="field">
          <label htmlFor="listing-type">Formato</label>
          <select id="listing-type" name="tipo" defaultValue={filters.type ?? ''}>
            <option value="">Todos</option>
            {contentTypes.map((type) => (
              <option value={type} key={type}>
                {contentTypeLabels[type]}
              </option>
            ))}
          </select>
        </div>
        <div className="field">
          <label htmlFor="listing-from">A partir de</label>
          <input id="listing-from" name="de" type="date" defaultValue={filters.from} />
        </div>
        <button className="button" type="submit">
          Aplicar filtros
        </button>
      </form>

      <div className="listing-summary" aria-live="polite">
        <p>
          <strong>{listing.total}</strong>{' '}
          {listing.total === 1 ? 'resultado publicado' : 'resultados publicados'}
        </p>
        {(filters.query || filters.type || filters.from) && (
          <Link href="/materias">Limpar filtros</Link>
        )}
      </div>

      <ContentGrid contents={listing.items} />

      {pageCount > 1 && (
        <nav className="pagination" aria-label="Paginação">
          {currentPage > 1 && <Link href={pageHref(parameters, currentPage - 1)}>← Anterior</Link>}
          <span>
            Página {currentPage} de {pageCount}
          </span>
          {currentPage < pageCount && (
            <Link href={pageHref(parameters, currentPage + 1)}>Próxima →</Link>
          )}
        </nav>
      )}
    </main>
  );
}
