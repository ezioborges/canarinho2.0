import 'server-only';

import { publicEnvironment } from '@/shared/config/public-environment';

import type {
  ContentFilters,
  ContentListing,
  PublicContentDetail,
  PublicHomepage,
} from '../domain/content';

const PAGE_SIZE = 12;

type CachePolicy = {
  revalidate: number | false;
  tags: string[];
};

function appendParameter(parameters: URLSearchParams, name: string, value: unknown): void {
  if (value !== undefined && value !== null && value !== '') {
    parameters.set(name, String(value));
  }
}

async function callPublicRpc<Result>(
  functionName: string,
  parameters: URLSearchParams,
  cachePolicy: CachePolicy,
): Promise<Result> {
  const url = new URL(`/rest/v1/rpc/${functionName}`, publicEnvironment.NEXT_PUBLIC_SUPABASE_URL);
  url.search = parameters.toString();

  const response = await fetch(url, {
    headers: {
      apikey: publicEnvironment.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
      Authorization: `Bearer ${publicEnvironment.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY}`,
    },
    ...(cachePolicy.revalidate === false
      ? { cache: 'no-store' }
      : { next: { revalidate: cachePolicy.revalidate, tags: cachePolicy.tags } }),
  });

  if (!response.ok) {
    throw new Error(`public_portal_rpc_failed:${functionName}:${response.status}`);
  }

  return (await response.json()) as Result;
}

export async function getPublicHomepage(): Promise<PublicHomepage> {
  return callPublicRpc<PublicHomepage>('get_public_homepage', new URLSearchParams(), {
    revalidate: 300,
    tags: ['public-content', 'public-homepage'],
  });
}

export async function listPublishedContent(filters: ContentFilters = {}): Promise<ContentListing> {
  const parameters = new URLSearchParams();
  const page = Math.max(1, filters.page ?? 1);

  appendParameter(parameters, 'search_query', filters.query?.trim());
  appendParameter(parameters, 'category_slug', filters.category);
  appendParameter(parameters, 'tag_slug', filters.tag);
  appendParameter(parameters, 'author_id', filters.authorId);
  appendParameter(parameters, 'edition_slug', filters.edition);
  appendParameter(parameters, 'content_kind', filters.type);
  appendParameter(parameters, 'published_from', filters.from);
  appendParameter(parameters, 'published_to', filters.to);
  appendParameter(parameters, 'page_size', PAGE_SIZE);
  appendParameter(parameters, 'page_offset', (page - 1) * PAGE_SIZE);

  const hasVolatileQuery = Boolean(filters.query?.trim());

  return callPublicRpc<ContentListing>('list_published_content', parameters, {
    revalidate: hasVolatileQuery ? false : 300,
    tags: ['public-content', 'public-listing'],
  });
}

export async function getPublishedContent(slug: string): Promise<PublicContentDetail | null> {
  const parameters = new URLSearchParams({ requested_slug: slug });
  return callPublicRpc<PublicContentDetail | null>('get_published_content', parameters, {
    revalidate: 3600,
    tags: ['public-content', `public-content:${slug}`],
  });
}

export async function resolvePublishedContentSlug(slug: string): Promise<string | null> {
  const parameters = new URLSearchParams({ requested_slug: slug });
  return callPublicRpc<string | null>('resolve_published_content_slug', parameters, {
    revalidate: 3600,
    tags: ['public-content', 'public-redirects'],
  });
}

export const publicListingPageSize = PAGE_SIZE;
