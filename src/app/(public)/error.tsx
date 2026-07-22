'use client';

import { useEffect } from 'react';

export default function PublicError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    // O digest permite correlacionar o erro sem expor dados editoriais ou credenciais na tela.
    void error.digest;
  }, [error]);

  return (
    <main id="conteudo-principal" className="status-page">
      <p className="eyebrow">Algo saiu do voo</p>
      <h1>Não foi possível carregar esta página.</h1>
      <p>O conteúdo continua seguro. Tente novamente em alguns instantes.</p>
      <button className="button" type="button" onClick={reset}>
        Tentar novamente
      </button>
    </main>
  );
}
