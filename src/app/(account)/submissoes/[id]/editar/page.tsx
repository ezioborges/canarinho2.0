import type { Metadata } from 'next';

import { getOwnSubmission, getSubmissionWorkspace } from '@/modules/editorial';
import { SubmissionEditor } from '@/modules/editorial/client';

export const metadata: Metadata = { title: 'Editar submissão', robots: { index: false } };
type PageProperties = { params: Promise<{ id: string }> };

export default async function EditSubmissionPage({ params }: PageProperties) {
  const { id } = await params;
  const [submission, workspace] = await Promise.all([
    getOwnSubmission(id),
    getSubmissionWorkspace(),
  ]);
  return (
    <main id="conteudo-principal" className="editor-page">
      <header className="page-heading">
        <p className="eyebrow">Rascunho</p>
        <h1>{submission.content.title}</h1>
      </header>
      <SubmissionEditor contentId={id} workspace={workspace} initialSubmission={submission} />
    </main>
  );
}
