import type { Metadata } from 'next';
import type { ReactNode } from 'react';

import '@/styles/globals.css';

export const metadata: Metadata = {
  title: {
    default: 'Canarinho 2.0',
    template: '%s | Canarinho 2.0',
  },
  description: 'Portal editorial do Canarinho.',
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
