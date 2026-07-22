import type { Metadata } from 'next';

import { ContentGrid, listPublishedContent } from '@/modules/public-portal';

export const metadata: Metadata = {
  title: 'Galeria',
  description: 'Fotografias, ilustrações e produções visuais da comunidade Canarinho.',
  alternates: { canonical: '/galeria' },
};

export default async function GalleryPage() {
  const gallery = await listPublishedContent({ type: 'artwork' });
  return (
    <main id="conteudo-principal" className="listing-page gallery-page">
      <header className="page-intro">
        <p className="eyebrow">Olhares da comunidade</p>
        <h1>Galeria</h1>
        <p>
          Ensaios visuais, fotografia e arte com autoria, contexto, crédito, licença e descrição
          acessível.
        </p>
      </header>
      <ContentGrid
        contents={gallery.items}
        emptyDescription="A primeira produção visual está sendo preparada."
      />
    </main>
  );
}
