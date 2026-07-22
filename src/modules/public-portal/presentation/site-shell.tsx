import Link from 'next/link';
import type { ReactNode } from 'react';

export function SiteHeader() {
  return (
    <>
      <a className="skip-link" href="#conteudo-principal">
        Pular para o conteúdo
      </a>
      <header className="site-header">
        <div className="site-header__inner">
          <Link className="brand" href="/" aria-label="Canarinho — página inicial">
            <span className="brand__bird" aria-hidden="true">
              c
            </span>
            <span>canarinho</span>
          </Link>
          <nav aria-label="Navegação principal">
            <Link href="/materias">Matérias</Link>
            <Link href="/poemas">Poemas</Link>
            <Link href="/galeria">Galeria</Link>
            <Link href="/equipe">Equipe</Link>
            <Link href="/submissoes">Enviar matéria</Link>
          </nav>
          <form className="header-search" action="/busca" role="search">
            <label className="sr-only" htmlFor="header-search-query">
              Buscar no Canarinho
            </label>
            <input id="header-search-query" name="q" type="search" placeholder="Buscar" />
            <button type="submit" aria-label="Buscar">
              ↗
            </button>
          </form>
        </div>
      </header>
    </>
  );
}

export function SiteFooter() {
  return (
    <footer className="site-footer">
      <div>
        <Link className="brand brand--footer" href="/">
          canarinho
        </Link>
        <p>Jornalismo, arte e ideias produzidas com a comunidade universitária.</p>
      </div>
      <nav aria-label="Navegação do rodapé">
        <Link href="/materias">Todas as matérias</Link>
        <Link href="/busca">Busca</Link>
        <Link href="/equipe">Equipe</Link>
        <Link href="/faca-parte">Faça parte</Link>
        <Link href="/submissoes">Minhas submissões</Link>
        <a href="mailto:contato@canarinho.test">Contato</a>
      </nav>
      <p className="site-footer__legal">© 2026 Canarinho. Conteúdo editorial de demonstração.</p>
    </footer>
  );
}

export function PublicShell({ children }: { children: ReactNode }) {
  return (
    <>
      <SiteHeader />
      {children}
      <SiteFooter />
    </>
  );
}
