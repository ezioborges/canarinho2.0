import type { Metadata } from 'next';

import { FilteredArchive } from '@/modules/public-portal';

function labelFromSlug(slug: string): string {
  return slug
    .split('-')
    .map((word) => `${word.charAt(0).toUpperCase()}${word.slice(1)}`)
    .join(' ');
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ slug: string }>;
}): Promise<Metadata> {
  const { slug } = await params;
  const label = labelFromSlug(slug);
  return {
    title: label,
    description: `Conteúdos publicados na categoria ${label}.`,
    alternates: { canonical: `/categorias/${slug}` },
  };
}

export default async function CategoryPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const label = labelFromSlug(slug);
  return (
    <FilteredArchive
      eyebrow="Categoria"
      title={label}
      description={`Histórias reunidas sob o tema ${label.toLocaleLowerCase('pt-BR')}.`}
      filters={{ category: slug }}
    />
  );
}
