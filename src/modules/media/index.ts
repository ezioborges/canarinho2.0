export const mediaModule = {
  id: 'media',
  label: 'Midia',
} as const;

export { hasCompleteGalleryMetadata } from './domain/gallery';
export type { GalleryAssetMetadata } from './domain/gallery';
