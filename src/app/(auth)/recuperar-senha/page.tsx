import type { Metadata } from 'next';
import Link from 'next/link';

import { requestPasswordReset } from '@/modules/identity-access';

export const metadata: Metadata = { title: 'Recuperar senha', robots: { index: false } };

type PageProperties = { searchParams: Promise<Record<string, string | string[] | undefined>> };

export default async function PasswordRecoveryPage({ searchParams }: PageProperties) {
  const parameters = await searchParams;
  const error = typeof parameters.erro === 'string' ? parameters.erro : null;
  const success = typeof parameters.sucesso === 'string' ? parameters.sucesso : null;
  return (
    <main id="conteudo-principal" className="auth-page">
      <section className="auth-card">
        <p className="eyebrow">Acesso</p>
        <h1>Recupere sua senha</h1>
        <p>
          Enviaremos um link temporário. A resposta é igual mesmo quando o email não está
          cadastrado.
        </p>
        {error ? <p className="form-message form-message--error">{error}</p> : null}
        {success ? <p className="form-message form-message--success">{success}</p> : null}
        <form action={requestPasswordReset} className="stack-form">
          <label>
            Email
            <input name="email" type="email" autoComplete="email" required />
          </label>
          <button className="button button--primary" type="submit">
            Enviar instruções
          </button>
        </form>
        <p className="auth-links">
          <Link href="/entrar">Voltar ao login</Link>
        </p>
      </section>
    </main>
  );
}
