import Image from 'next/image';

import { publicEnvironment } from '@/shared/config/public-environment';

import type { PublicCover } from '../domain/content';

type CoverImageProperties = {
  cover: PublicCover | null;
  priority?: boolean;
  sizes?: string;
};

function coverSource(cover: PublicCover): string {
  const staticMarker = '/static/';
  const staticPosition = cover.objectPath.indexOf(staticMarker);

  if (staticPosition >= 0) {
    return `/images/editorial/${cover.objectPath.slice(staticPosition + staticMarker.length)}`;
  }

  const encodedPath = cover.objectPath.split('/').map(encodeURIComponent).join('/');
  return `${publicEnvironment.NEXT_PUBLIC_SUPABASE_URL}/storage/v1/object/public/content-public/${encodedPath}`;
}

export function CoverImage({
  cover,
  priority = false,
  sizes = '(max-width: 48rem) 100vw, 50vw',
}: CoverImageProperties) {
  if (!cover) {
    return <div className="cover-placeholder" aria-hidden="true" />;
  }

  return (
    <Image
      className="cover-image"
      src={coverSource(cover)}
      alt={cover.alt}
      width={1200}
      height={750}
      sizes={sizes}
      priority={priority}
    />
  );
}
