import type { Metadata } from 'next';

import { updatePassword } from '@/modules/identity-access';

export const metadata: Metadata = { title: 'Nova senha', robots: { index: false } };

type PageProperties = { searchParams: Promise<Record<string, string | string[] | undefined>> };

export default async function UpdatePasswordPage({ searchParams }: PageProperties) {
  const parameters = await searchParams;
  const error = typeof parameters.erro === 'string' ? parameters.erro : null;
  return (
    <main id="conteudo-principal" className="auth-page">
      <section className="auth-card">
        <p className="eyebrow">Acesso</p>
        <h1>Defina uma nova senha</h1>
        {error ? <p className="form-message form-message--error">{error}</p> : null}
        <form action={updatePassword} className="stack-form">
          <label>
            Nova senha
            <input
              name="senha"
              type="password"
              autoComplete="new-password"
              minLength={8}
              required
            />
          </label>
          <button className="button button--primary" type="submit">
            Atualizar senha
          </button>
        </form>
      </section>
    </main>
  );
}
