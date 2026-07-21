import type { Metadata } from 'next';

import { FilteredArchive } from '@/modules/public-portal';

function titleFromSlug(slug: string): string {
  const words = slug.replace(/-\d+$/u, '').split('-').join(' ');
  return words.charAt(0).toUpperCase() + words.slice(1);
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ slug: string }>;
}): Promise<Metadata> {
  const { slug } = await params;
  const title = titleFromSlug(slug);
  return {
    title: `Edição — ${title}`,
    description: `Conteúdos da edição ${title}.`,
    alternates: { canonical: `/edicoes/${slug}` },
  };
}

export default async function EditionPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const title = titleFromSlug(slug);
  return (
    <FilteredArchive
      eyebrow="Edição"
      title={title}
      description="Uma seleção editorial para ler no seu tempo."
      filters={{ edition: slug }}
    />
  );
}
