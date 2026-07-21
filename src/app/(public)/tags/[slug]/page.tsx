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
    title: `#${label}`,
    description: `Conteúdos publicados com a tag ${label}.`,
    alternates: { canonical: `/tags/${slug}` },
  };
}

export default async function TagPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const label = labelFromSlug(slug);
  return (
    <FilteredArchive
      eyebrow="Tag"
      title={`#${label}`}
      description="Uma trilha de leitura conectada por este assunto."
      filters={{ tag: slug }}
    />
  );
}
