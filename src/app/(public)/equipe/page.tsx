import type { Metadata } from 'next';
import Link from 'next/link';

import { listPublicTeam } from '@/modules/organization';

export const metadata: Metadata = {
  title: 'Equipe',
  description: 'Conheça as pessoas e os eixos que constroem o Canarinho.',
  alternates: { canonical: '/equipe' },
};

export default async function TeamPage() {
  const areas = await listPublicTeam();
  return (
    <main id="conteudo-principal" className="organization-page">
      <header className="page-intro">
        <p className="eyebrow">Quem faz</p>
        <h1>Um jornal feito em bando</h1>
        <p>Conheça as pessoas que cuidam de cada etapa do Canarinho.</p>
        <Link className="button button--primary" href="/faca-parte">
          Faça parte da equipe
        </Link>
      </header>
      {areas.map((area) => (
        <section className="team-area" key={area.id} aria-labelledby={`area-${area.slug}`}>
          <header>
            <h2 id={`area-${area.slug}`}>{area.name}</h2>
            {area.description ? <p>{area.description}</p> : null}
          </header>
          <div className="team-grid">
            {area.members.map((member) => (
              <article className="team-card" key={member.id}>
                <p className="eyebrow">{member.roleTitle}</p>
                <h3>{member.name}</h3>
                {member.bio ? <p>{member.bio}</p> : null}
                {member.publicContact ? (
                  <a href={`mailto:${member.publicContact}`}>Contato</a>
                ) : null}
              </article>
            ))}
          </div>
        </section>
      ))}
    </main>
  );
}
