import type { Metadata } from 'next';

import { listPublicOpenings, submitRecruitmentApplicationAction } from '@/modules/organization';

export const metadata: Metadata = {
  title: 'Faça parte',
  description: 'Conheça as chamadas abertas e participe da equipe Canarinho.',
  alternates: { canonical: '/faca-parte' },
};

function single(value: string | string[] | undefined) {
  return Array.isArray(value) ? value[0] : value;
}

export default async function RecruitmentPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const [openings, query] = await Promise.all([listPublicOpenings(), searchParams]);
  return (
    <main id="conteudo-principal" className="organization-page recruitment-page">
      <header className="page-intro">
        <p className="eyebrow">Faça parte</p>
        <h1>Tem espaço para a sua voz.</h1>
        <p>Aprenda fazendo e ajude a aproximar histórias da comunidade universitária.</p>
      </header>
      {single(query.sucesso) ? (
        <p className="form-message form-message--success">{single(query.sucesso)}</p>
      ) : null}
      {single(query.erro) ? (
        <p className="form-message form-message--error">{single(query.erro)}</p>
      ) : null}
      {openings.map((opening) => (
        <article className="opening-card" key={opening.id}>
          <header>
            <h2>{opening.title}</h2>
            <p>{opening.summary}</p>
          </header>
          <div className="opening-details">
            <section>
              <h3>Sobre a chamada</h3>
              <p>{opening.description}</p>
            </section>
            <section>
              <h3>O que buscamos</h3>
              <p>{opening.requirements}</p>
            </section>
            <section>
              <h3>Como funciona</h3>
              <p>{opening.process}</p>
            </section>
          </div>
          {opening.applications_enabled ? (
            <form className="application-form" action={submitRecruitmentApplicationAction}>
              <input type="hidden" name="openingId" value={opening.id} />
              <div className="honeypot" aria-hidden="true">
                <label>
                  Site
                  <input name="website" tabIndex={-1} autoComplete="off" />
                </label>
              </div>
              <label>
                Nome completo
                <input name="name" minLength={2} maxLength={120} required />
              </label>
              <label>
                Email
                <input name="email" type="email" maxLength={254} required />
              </label>
              <label>
                Curso ou vínculo
                <input name="affiliation" minLength={2} maxLength={200} required />
              </label>
              <label>
                Por que você quer participar?
                <textarea name="message" minLength={20} maxLength={4000} required />
              </label>
              <label className="checkbox-field">
                <input name="consent" type="checkbox" required /> Autorizo o uso destes dados
                exclusivamente para esta seleção. A candidatura será excluída após o prazo de
                retenção informado.
              </label>
              <button className="button button--primary" type="submit">
                Enviar candidatura
              </button>
            </form>
          ) : (
            <a href={`mailto:${opening.contact_email}`}>Falar com a equipe</a>
          )}
        </article>
      ))}
      {!openings.length ? (
        <div className="empty-state">
          <h2>Sem chamadas abertas agora</h2>
          <p>Acompanhe o portal para saber das próximas oportunidades.</p>
        </div>
      ) : null}
    </main>
  );
}
