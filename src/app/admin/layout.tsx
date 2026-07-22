import Link from 'next/link';
import type { ReactNode } from 'react';

import { getEditorialSession } from '@/modules/editorial';
import { signOut } from '@/modules/identity-access';
import { PublicShell } from '@/modules/public-portal';

export default async function AdminLayout({ children }: Readonly<{ children: ReactNode }>) {
  const session = await getEditorialSession('/admin');
  const canReview = session.roles.some((role) => role === 'revisor' || role === 'diretor');
  const canEdit = session.roles.some((role) => role === 'editor' || role === 'diretor');

  return (
    <PublicShell>
      <div className="account-nav admin-nav">
        <nav aria-label="Operação editorial">
          {canReview ? <Link href="/admin/revisao">Fila de revisão</Link> : null}
          {canEdit ? <Link href="/admin/editorial">Edição e publicação</Link> : null}
        </nav>
        <div className="admin-nav__identity">
          <span>{session.displayName}</span>
          <form action={signOut}>
            <button className="button button--text" type="submit">
              Sair
            </button>
          </form>
        </div>
      </div>
      {children}
    </PublicShell>
  );
}
