'use server';

import { redirect } from 'next/navigation';
import type { Route } from 'next';

import { publicEnvironment } from '@/shared/config/public-environment';
import { createSupabaseServerClient } from '@/shared/lib/supabase/server';

import { safeReturnPath } from '../domain/return-path';
import { credentialsSchema, profileSchema, signupSchema } from '../schemas/account';

function redirectWithMessage(path: string, kind: 'erro' | 'sucesso', message: string): never {
  const parameters = new URLSearchParams({ [kind]: message });
  redirect(`${path}?${parameters.toString()}` as Route);
}

export async function signIn(formData: FormData): Promise<never> {
  const returnPath = safeReturnPath(formData.get('retorno'));
  const parsed = credentialsSchema.safeParse({
    email: formData.get('email'),
    password: formData.get('senha'),
  });
  if (!parsed.success) {
    redirectWithMessage('/entrar', 'erro', parsed.error.issues[0]?.message ?? 'Dados inválidos.');
  }

  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.auth.signInWithPassword(parsed.data);
  if (error) {
    redirectWithMessage('/entrar', 'erro', 'Email ou senha não conferem.');
  }
  redirect(returnPath as Route);
}

export async function signUp(formData: FormData): Promise<never> {
  const parsed = signupSchema.safeParse({
    displayName: formData.get('nome'),
    email: formData.get('email'),
    password: formData.get('senha'),
  });
  if (!parsed.success) {
    redirectWithMessage('/cadastro', 'erro', parsed.error.issues[0]?.message ?? 'Dados inválidos.');
  }

  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.auth.signUp({
    email: parsed.data.email,
    password: parsed.data.password,
    options: {
      data: { display_name: parsed.data.displayName },
      emailRedirectTo: `${publicEnvironment.NEXT_PUBLIC_SITE_URL}/auth/callback?retorno=/submissoes`,
    },
  });
  if (error) {
    redirectWithMessage('/cadastro', 'erro', 'Não foi possível criar a conta. Tente outro email.');
  }
  if (data.session) {
    redirect('/submissoes');
  }
  redirectWithMessage('/entrar', 'sucesso', 'Confira seu email para confirmar o cadastro.');
}

export async function requestPasswordReset(formData: FormData): Promise<never> {
  const parsed = credentialsSchema
    .pick({ email: true })
    .safeParse({ email: formData.get('email') });
  if (!parsed.success) {
    redirectWithMessage('/recuperar-senha', 'erro', 'Informe um email válido.');
  }

  const supabase = await createSupabaseServerClient();
  await supabase.auth.resetPasswordForEmail(parsed.data.email, {
    redirectTo: `${publicEnvironment.NEXT_PUBLIC_SITE_URL}/auth/callback?retorno=/atualizar-senha`,
  });
  redirectWithMessage(
    '/recuperar-senha',
    'sucesso',
    'Se a conta existir, enviaremos as instruções de recuperação.',
  );
}

export async function updatePassword(formData: FormData): Promise<never> {
  const parsed = credentialsSchema.pick({ password: true }).safeParse({
    password: formData.get('senha'),
  });
  if (!parsed.success) {
    redirectWithMessage(
      '/atualizar-senha',
      'erro',
      parsed.error.issues[0]?.message ?? 'Senha inválida.',
    );
  }

  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.auth.updateUser({ password: parsed.data.password });
  if (error) {
    redirectWithMessage(
      '/atualizar-senha',
      'erro',
      'O link expirou. Solicite uma nova recuperação.',
    );
  }
  redirectWithMessage('/conta', 'sucesso', 'Senha atualizada.');
}

export async function updateProfile(formData: FormData): Promise<never> {
  const parsed = profileSchema.safeParse({
    displayName: formData.get('nome'),
    course: formData.get('curso') || undefined,
    affiliation: formData.get('vinculo') || undefined,
  });
  if (!parsed.success) {
    redirectWithMessage('/conta', 'erro', 'Revise os dados do perfil.');
  }

  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) {
    redirect('/entrar?retorno=/conta');
  }

  const { error } = await supabase
    .from('profiles')
    .update({
      display_name: parsed.data.displayName,
      course: parsed.data.course || null,
      affiliation: parsed.data.affiliation || null,
    })
    .eq('id', user.id);
  if (error) {
    redirectWithMessage('/conta', 'erro', 'Não foi possível atualizar o perfil.');
  }
  redirectWithMessage('/conta', 'sucesso', 'Perfil atualizado.');
}

export async function signOut(): Promise<never> {
  const supabase = await createSupabaseServerClient();
  await supabase.auth.signOut();
  redirect('/');
}
