import type { Metadata } from 'next';
import Link from 'next/link';

import { signIn, safeReturnPath } from '@/modules/identity-access';

export const metadata: Metadata = { title: 'Entrar', robots: { index: false, follow: false } };

type PageProperties = { searchParams: Promise<Record<string, string | string[] | undefined>> };

export default async function SignInPage({ searchParams }: PageProperties) {
  const parameters = await searchParams;
  const error = typeof parameters.erro === 'string' ? parameters.erro : null;
  const success = typeof parameters.sucesso === 'string' ? parameters.sucesso : null;
  const returnPath = safeReturnPath(
    typeof parameters.retorno === 'string' ? parameters.retorno : undefined,
  );

  return (
    <main id="conteudo-principal" className="auth-page">
      <section className="auth-card" aria-labelledby="titulo-entrar">
        <p className="eyebrow">Sua conta</p>
        <h1 id="titulo-entrar">Entre no Canarinho</h1>
        <p>Salve rascunhos, envie sua matéria e acompanhe cada etapa editorial.</p>
        {error ? <p className="form-message form-message--error">{error}</p> : null}
        {success ? <p className="form-message form-message--success">{success}</p> : null}
        <form action={signIn} className="stack-form">
          <input type="hidden" name="retorno" value={returnPath} />
          <label>
            Email
            <input name="email" type="email" autoComplete="email" required />
          </label>
          <label>
            Senha
            <input
              name="senha"
              type="password"
              autoComplete="current-password"
              minLength={8}
              required
            />
          </label>
          <button className="button button--primary" type="submit">
            Entrar
          </button>
        </form>
        <div className="auth-links">
          <Link href="/recuperar-senha">Esqueci minha senha</Link>
          <Link href="/cadastro">Criar uma conta</Link>
        </div>
      </section>
    </main>
  );
}
