import { redirect } from 'next/navigation';

import { getAuthenticatedSession } from '@/modules/identity-access';

export default async function AdminPage() {
  const session = await getAuthenticatedSession('/admin');
  if (session.roles.includes('conexoes')) {
    redirect('/admin/comunicacoes');
  }
  if (session.roles.some((role) => role === 'revisor' || role === 'diretor')) {
    redirect('/admin/revisao');
  }
  redirect('/admin/editorial');
}
