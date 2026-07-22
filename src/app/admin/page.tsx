import { redirect } from 'next/navigation';

import { getEditorialSession } from '@/modules/editorial';

export default async function AdminPage() {
  const session = await getEditorialSession('/admin');
  if (session.roles.some((role) => role === 'revisor' || role === 'diretor')) {
    redirect('/admin/revisao');
  }
  redirect('/admin/editorial');
}
