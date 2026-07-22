import Link from 'next/link';
import type { ReactNode } from 'react';

import { signOut } from '@/modules/identity-access';
import { PublicShell } from '@/modules/public-portal';

export default function AccountLayout({ children }: Readonly<{ children: ReactNode }>) {
  return (
    <PublicShell>
      <div className="account-nav">
        <nav aria-label="Área da conta">
          <Link href="/submissoes">Minhas submissões</Link>
          <Link href="/favoritos">Favoritos</Link>
          <Link href="/notificacoes">Notificações</Link>
          <Link href="/conta">Meu perfil</Link>
        </nav>
        <form action={signOut}>
          <button className="button button--text" type="submit">
            Sair
          </button>
        </form>
      </div>
      {children}
    </PublicShell>
  );
}
