import { moduleCatalog } from '@/modules';
import { publicEnvironment } from '@/shared/config/public-environment';

export default function FoundationPage() {
  return (
    <main>
      <section className="hero" aria-labelledby="foundation-title">
        <p className="eyebrow">Canarinho 2.0</p>
        <h1 id="foundation-title">Fundacao pronta para evoluir por dominio.</h1>
        <p className="summary">
          A aplicacao Next.js, a configuracao tipada e as fronteiras do monolito modular estao
          ativas. O proximo incremento pode partir desta base reproduzivel.
        </p>
        <dl className="runtime">
          <div>
            <dt>Ambiente</dt>
            <dd>{publicEnvironment.NEXT_PUBLIC_APP_ENV}</dd>
          </div>
          <div>
            <dt>Modulos</dt>
            <dd>{moduleCatalog.length}</dd>
          </div>
        </dl>
      </section>

      <section className="modules" aria-labelledby="modules-title">
        <div>
          <p className="eyebrow">Arquitetura</p>
          <h2 id="modules-title">Fronteiras iniciais</h2>
        </div>
        <ul>
          {moduleCatalog.map((module) => (
            <li key={module.id}>
              <span>{module.label}</span>
              <code>{module.id}</code>
            </li>
          ))}
        </ul>
      </section>
    </main>
  );
}
