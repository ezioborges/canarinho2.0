import Link from 'next/link';
import type { ReactNode } from 'react';

import { getAuthenticatedSession, signOut } from '@/modules/identity-access';
import { PublicShell } from '@/modules/public-portal';

export default async function AdminLayout({ children }: Readonly<{ children: ReactNode }>) {
  const session = await getAuthenticatedSession('/admin');
  const canReview = session.roles.some((role) => role === 'revisor' || role === 'diretor');
  const canEdit = session.roles.some((role) => role === 'editor' || role === 'diretor');
  const isDirector = session.roles.includes('diretor');
  const canCommunicate = session.roles.some((role) => role === 'conexoes' || role === 'diretor');

  return (
    <PublicShell>
      <div className="account-nav admin-nav">
        <nav aria-label="Operação editorial">
          {canReview ? <Link href="/admin/revisao">Fila de revisão</Link> : null}
          {canEdit ? <Link href="/admin/editorial">Edição e publicação</Link> : null}
          {canEdit ? <Link href="/admin/comunidade">Comunidade</Link> : null}
          {canCommunicate ? <Link href="/admin/comunicacoes">Comunicações</Link> : null}
          {isDirector ? <Link href="/admin/organizacao">Equipe e seleção</Link> : null}
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
