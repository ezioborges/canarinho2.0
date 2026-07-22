import type { Metadata } from 'next';

import { updateProfile } from '@/modules/identity-access';
import { createSupabaseServerClient } from '@/shared/lib/supabase/server';

export const metadata: Metadata = { title: 'Meu perfil', robots: { index: false, follow: false } };

type PageProperties = { searchParams: Promise<Record<string, string | string[] | undefined>> };

export default async function AccountPage({ searchParams }: PageProperties) {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  const { data: profile } = await supabase
    .from('profiles')
    .select('display_name,course,affiliation,created_at')
    .eq('id', user?.id ?? '')
    .single();
  const parameters = await searchParams;
  const error = typeof parameters.erro === 'string' ? parameters.erro : null;
  const success = typeof parameters.sucesso === 'string' ? parameters.sucesso : null;

  return (
    <main id="conteudo-principal" className="account-page">
      <header className="page-heading">
        <p className="eyebrow">Sua conta</p>
        <h1>Meu perfil</h1>
        <p>O email é gerenciado pelo acesso da conta; estes dados compõem seu perfil público.</p>
      </header>
      {error ? <p className="form-message form-message--error">{error}</p> : null}
      {success ? <p className="form-message form-message--success">{success}</p> : null}
      <section className="account-card">
        <p>
          <strong>Email:</strong> {user?.email}
        </p>
        <form action={updateProfile} className="stack-form">
          <label>
            Nome público
            <input
              name="nome"
              defaultValue={profile?.display_name ?? ''}
              minLength={2}
              maxLength={120}
              required
            />
          </label>
          <label>
            Curso
            <input name="curso" defaultValue={profile?.course ?? ''} maxLength={120} />
          </label>
          <label>
            Vínculo
            <input name="vinculo" defaultValue={profile?.affiliation ?? ''} maxLength={120} />
          </label>
          <button className="button button--primary" type="submit">
            Salvar perfil
          </button>
        </form>
      </section>
    </main>
  );
}
