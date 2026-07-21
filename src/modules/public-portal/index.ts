export const publicPortalModule = {
  id: 'public-portal',
  label: 'Portal publico',
} as const;

export {
  contentTypeLabels,
  contentTypes,
  extractText,
  isContentType,
  primaryCategory,
  readingTimeInMinutes,
} from './domain/content';
export type {
  ContentFilters,
  ContentListing,
  ContentType,
  PublicAuthor,
  PublicCategory,
  PublicContentCard,
  PublicContentDetail,
  PublicCover,
  PublicEdition,
  PublicHomepage,
  PublicTag,
  RichTextDocument,
  RichTextNode,
} from './domain/content';
export {
  getPublicHomepage,
  getPublishedContent,
  listPublishedContent,
  publicListingPageSize,
  resolvePublishedContentSlug,
} from './infrastructure/public-content.repository';
export { ContentCard } from './presentation/content-card';
export { ContentGrid } from './presentation/content-grid';
export { CoverImage } from './presentation/cover-image';
export { FilteredArchive } from './presentation/filtered-archive';
export { RichText } from './presentation/rich-text';
export { PublicShell, SiteFooter, SiteHeader } from './presentation/site-shell';
