import type { Metadata } from 'next';
import type { ReactNode } from 'react';

import { publicEnvironment } from '@/shared/config/public-environment';

import '@/styles/globals.css';

export const metadata: Metadata = {
  metadataBase: new URL(publicEnvironment.NEXT_PUBLIC_SITE_URL),
  title: {
    default: 'Canarinho — histórias que circulam',
    template: '%s | Canarinho',
  },
  description: 'Jornalismo, arte e ideias produzidas com a comunidade universitária.',
  applicationName: 'Canarinho',
  authors: [{ name: 'Canarinho' }],
  creator: 'Canarinho',
  openGraph: {
    type: 'website',
    locale: 'pt_BR',
    siteName: 'Canarinho',
    title: 'Canarinho — histórias que circulam',
    description: 'Jornalismo, arte e ideias produzidas com a comunidade universitária.',
    url: '/',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Canarinho — histórias que circulam',
    description: 'Jornalismo, arte e ideias produzidas com a comunidade universitária.',
  },
};

type RootLayoutProperties = Readonly<{
  children: ReactNode;
}>;

export default function RootLayout({ children }: RootLayoutProperties) {
  return (
    <html lang="pt-BR">
      <body>{children}</body>
    </html>
  );
}
