import 'server-only';

import type { Route } from 'next';
import { redirect } from 'next/navigation';

import { createSupabaseServerClient } from '@/shared/lib/supabase/server';

export type AppRole = 'leitor' | 'revisor' | 'editor' | 'conexoes' | 'diretor';

export type AuthenticatedSession = {
  userId: string;
  displayName: string;
  roles: AppRole[];
};

export async function getAuthenticatedSession(
  returnPath: Route = '/conta',
): Promise<AuthenticatedSession> {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect(`/entrar?retorno=${encodeURIComponent(returnPath)}` as Route);
  const [profile, roles] = await Promise.all([
    supabase.from('profiles').select('display_name').eq('id', user.id).single(),
    supabase.from('user_roles').select('role_code').eq('user_id', user.id),
  ]);
  if (profile.error || roles.error) throw new Error('authenticated_session_failed');
  return {
    userId: user.id,
    displayName: profile.data.display_name,
    roles: (roles.data ?? []).map((row) => row.role_code) as AppRole[],
  };
}
