import type { Metadata } from 'next';

import { FilteredArchive, listPublishedContent } from '@/modules/public-portal';

async function authorName(id: string): Promise<string> {
  const listing = await listPublishedContent({ authorId: id });
  return (
    listing.items.flatMap((content) => content.authors).find((author) => author.id === id)?.name ??
    'Autor do Canarinho'
  );
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ id: string }>;
}): Promise<Metadata> {
  const { id } = await params;
  const name = await authorName(id);
  return {
    title: name,
    description: `Publicações de ${name} no Canarinho.`,
    alternates: { canonical: `/autores/${id}` },
  };
}

export default async function AuthorPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const name = await authorName(id);
  return (
    <FilteredArchive
      eyebrow="Autoria"
      title={name}
      description="Textos e produções publicados por esta pessoa."
      filters={{ authorId: id }}
    />
  );
}
