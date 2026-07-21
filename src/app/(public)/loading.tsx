export default function PublicLoading() {
  return (
    <main
      id="conteudo-principal"
      className="loading-page"
      aria-busy="true"
      aria-label="Carregando conteúdo"
    >
      <div className="skeleton skeleton--label" />
      <div className="skeleton skeleton--title" />
      <div className="skeleton skeleton--title skeleton--short" />
      <div className="skeleton skeleton--image" />
      <span className="sr-only">Carregando…</span>
    </main>
  );
}
