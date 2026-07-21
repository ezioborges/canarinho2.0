import type { MetadataRoute } from 'next';

import { publicEnvironment } from '@/shared/config/public-environment';

export default function robots(): MetadataRoute.Robots {
  const isProduction = publicEnvironment.NEXT_PUBLIC_APP_ENV === 'production';

  return {
    rules: isProduction
      ? { userAgent: '*', allow: '/', disallow: ['/admin/', '/conta/'] }
      : { userAgent: '*', disallow: '/' },
    ...(isProduction
      ? { sitemap: new URL('/sitemap.xml', publicEnvironment.NEXT_PUBLIC_SITE_URL).toString() }
      : {}),
  };
}
