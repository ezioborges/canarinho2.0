import type { ReactNode } from 'react';

import { PublicShell } from '@/modules/public-portal';

export default function AuthLayout({ children }: Readonly<{ children: ReactNode }>) {
  return <PublicShell>{children}</PublicShell>;
}
