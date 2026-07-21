import Link from 'next/link';

export default function NotFoundPage() {
  return (
    <main id="conteudo-principal" className="status-page">
      <p className="eyebrow">Erro 404</p>
      <h1>Esta história não pousou por aqui.</h1>
      <p>O endereço pode ter mudado ou o conteúdo ainda não está publicado.</p>
      <div className="status-page__actions">
        <Link className="button" href="/">
          Ir para a página inicial
        </Link>
        <Link href="/materias">Explorar matérias</Link>
      </div>
    </main>
  );
}
