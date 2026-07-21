import type { Metadata } from 'next';
import Link from 'next/link';

import { signUp } from '@/modules/identity-access';

export const metadata: Metadata = { title: 'Criar conta', robots: { index: false, follow: false } };

type PageProperties = { searchParams: Promise<Record<string, string | string[] | undefined>> };

export default async function SignupPage({ searchParams }: PageProperties) {
  const parameters = await searchParams;
  const error = typeof parameters.erro === 'string' ? parameters.erro : null;
  return (
    <main id="conteudo-principal" className="auth-page">
      <section className="auth-card" aria-labelledby="titulo-cadastro">
        <p className="eyebrow">Participe</p>
        <h1 id="titulo-cadastro">Crie sua conta</h1>
        <p>Seu nome público aparecerá na assinatura dos conteúdos que você enviar.</p>
        {error ? <p className="form-message form-message--error">{error}</p> : null}
        <form action={signUp} className="stack-form">
          <label>
            Nome público
            <input name="nome" autoComplete="name" minLength={2} maxLength={120} required />
          </label>
          <label>
            Email
            <input name="email" type="email" autoComplete="email" required />
          </label>
          <label>
            Senha
            <input
              name="senha"
              type="password"
              autoComplete="new-password"
              minLength={8}
              required
            />
          </label>
          <button className="button button--primary" type="submit">
            Criar conta
          </button>
        </form>
        <p className="auth-links">
          Já tem conta? <Link href="/entrar">Entrar</Link>
        </p>
      </section>
    </main>
  );
}
