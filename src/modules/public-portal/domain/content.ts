export const contentTypes = [
  'news',
  'weekly_article',
  'column',
  'poem',
  'essay',
  'short_story',
  'artwork',
  'notice',
] as const;

export type ContentType = (typeof contentTypes)[number];

export const contentTypeLabels: Record<ContentType, string> = {
  artwork: 'Arte e fotografia',
  column: 'Coluna',
  essay: 'Ensaio',
  news: 'Notícia',
  notice: 'Informe',
  poem: 'Poema',
  short_story: 'Conto',
  weekly_article: 'Artigo semanal',
};

export type PublicAuthor = {
  id: string | null;
  name: string;
};

export type PublicCategory = {
  isPrimary: boolean;
  name: string;
  slug: string;
};

export type PublicTag = {
  name: string;
  slug: string;
};

export type PublicCover = {
  alt: string;
  credit: string | null;
  license: string | null;
  mimeType: string;
  objectPath: string;
  title: string | null;
};

export type RichTextNode = {
  attrs?: {
    alt?: string;
    level?: number;
    src?: string;
    title?: string;
  };
  content?: RichTextNode[];
  marks?: { attrs?: { href?: string }; type: string }[];
  text?: string;
  type: string;
};

export type RichTextDocument = RichTextNode & {
  content: RichTextNode[];
  type: 'doc';
};

export type PublicContentCard = {
  authors: PublicAuthor[];
  categories: PublicCategory[];
  cover: PublicCover | null;
  id: string;
  publishedAt: string;
  slug: string;
  subtitle: string | null;
  summary: string | null;
  tags: PublicTag[];
  title: string;
  type: ContentType;
};

export type PublicEdition = {
  issueNumber: number | null;
  publishedAt?: string;
  slug: string;
  summary?: string | null;
  title: string;
};

export type PublicContentDetail = PublicContentCard & {
  body: RichTextDocument;
  editions: PublicEdition[];
  related: PublicContentCard[];
  seoDescription: string | null;
  seoTitle: string | null;
};

export type ContentListing = {
  items: PublicContentCard[];
  total: number;
};

export type PublicHomepage = {
  editions: PublicEdition[];
  featured: PublicContentCard[];
  gallery: PublicContentCard[];
  hero: PublicContentCard | null;
  poems: PublicContentCard[];
  recent: PublicContentCard[];
  weekly: PublicContentCard[];
};

export type ContentFilters = {
  authorId?: string;
  category?: string;
  edition?: string;
  from?: string;
  page?: number;
  query?: string;
  tag?: string;
  to?: string;
  type?: ContentType;
};

export function isContentType(value: string | undefined): value is ContentType {
  return contentTypes.some((contentType) => contentType === value);
}

export function primaryCategory(content: PublicContentCard): PublicCategory | undefined {
  return content.categories.find((category) => category.isPrimary) ?? content.categories[0];
}

export function extractText(node: RichTextNode): string {
  const ownText = node.text ?? '';
  const childText = node.content?.map(extractText).join(' ') ?? '';
  return `${ownText} ${childText}`.trim();
}

export function readingTimeInMinutes(document: RichTextDocument, wordsPerMinute = 220): number {
  const words = extractText(document).split(/\s+/u).filter(Boolean).length;
  return Math.max(1, Math.ceil(words / wordsPerMinute));
}
