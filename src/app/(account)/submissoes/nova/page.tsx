import type { Metadata } from 'next';

import { getSubmissionWorkspace } from '@/modules/editorial';
import { SubmissionEditor } from '@/modules/editorial/client';

export const metadata: Metadata = { title: 'Nova submissão', robots: { index: false } };

export default async function NewSubmissionPage() {
  const workspace = await getSubmissionWorkspace();
  const contentId = crypto.randomUUID();
  return (
    <main id="conteudo-principal" className="editor-page">
      <header className="page-heading">
        <p className="eyebrow">Nova pauta</p>
        <h1>Escreva sua submissão</h1>
        <p>Você pode voltar depois: o autosave começa assim que o título tiver três caracteres.</p>
      </header>
      <SubmissionEditor contentId={contentId} workspace={workspace} />
    </main>
  );
}
