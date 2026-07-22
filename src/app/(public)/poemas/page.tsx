import type { Metadata } from 'next';

import { ContentGrid, listPublishedContent } from '@/modules/public-portal';

export const metadata: Metadata = {
  title: 'Poemas e literatura',
  description: 'Poemas e produções literárias publicados pelo Canarinho.',
  alternates: { canonical: '/poemas' },
};

export default async function PoemsPage() {
  const poems = await listPublishedContent({ type: 'poem' });
  return (
    <main id="conteudo-principal" className="listing-page literary-page">
      <header className="page-intro">
        <p className="eyebrow">Literatura</p>
        <h1>Poemas para guardar</h1>
        <p>Palavras, ritmos e outras formas de perceber a vida universitária.</p>
      </header>
      <ContentGrid contents={poems.items} emptyDescription="Novos poemas chegam em breve." />
    </main>
  );
}
