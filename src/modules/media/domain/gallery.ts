export type GalleryAssetMetadata = {
  alt: string | null;
  credit: string | null;
  license: string | null;
  title: string | null;
};

export function hasCompleteGalleryMetadata(asset: GalleryAssetMetadata): boolean {
  return [asset.alt, asset.credit, asset.license, asset.title].every(
    (value) => typeof value === 'string' && value.trim().length > 0,
  );
}
