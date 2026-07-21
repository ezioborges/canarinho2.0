import type { MetadataRoute } from 'next';

import { listPublishedContent, publicListingPageSize } from '@/modules/public-portal';
import { publicEnvironment } from '@/shared/config/public-environment';

export const revalidate = 3600;

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const firstPage = await listPublishedContent({ page: 1 });
  const pageCount = Math.ceil(firstPage.total / publicListingPageSize);
  const additionalPages = await Promise.all(
    Array.from({ length: Math.max(0, pageCount - 1) }, (_, index) =>
      listPublishedContent({ page: index + 2 }),
    ),
  );
  const contents = [firstPage, ...additionalPages].flatMap((page) => page.items);
  const baseUrl = publicEnvironment.NEXT_PUBLIC_SITE_URL;
  const entries = new Map<string, MetadataRoute.Sitemap[number]>();

  const addEntry = (path: string, entry: Omit<MetadataRoute.Sitemap[number], 'url'>): void => {
    const url = new URL(path, baseUrl).toString();
    entries.set(url, { url, ...entry });
  };

  addEntry('/', { changeFrequency: 'daily', priority: 1 });
  addEntry('/materias', { changeFrequency: 'daily', priority: 0.9 });

  for (const content of contents) {
    addEntry(`/materias/${content.slug}`, {
      changeFrequency: 'weekly',
      lastModified: new Date(content.publishedAt),
      priority: 0.8,
    });
    for (const category of content.categories)
      addEntry(`/categorias/${category.slug}`, { changeFrequency: 'weekly', priority: 0.6 });
    for (const tag of content.tags)
      addEntry(`/tags/${tag.slug}`, { changeFrequency: 'weekly', priority: 0.5 });
    for (const author of content.authors) {
      if (author.id)
        addEntry(`/autores/${author.id}`, { changeFrequency: 'weekly', priority: 0.5 });
    }
  }

  return [...entries.values()];
}
