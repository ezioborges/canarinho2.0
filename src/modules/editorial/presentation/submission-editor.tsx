'use client';

import { zodResolver } from '@hookform/resolvers/zod';
import { useEditor, EditorContent, type JSONContent } from '@tiptap/react';
import { StarterKit } from '@tiptap/starter-kit';
import { useRouter } from 'next/navigation';
import { useEffect, useRef, useState } from 'react';
import { useFieldArray, useForm } from 'react-hook-form';

import {
  editableStatuses,
  richTextHasContent,
  submissionContentTypeLabels,
  submissionContentTypes,
  type SubmissionContentType,
} from '../domain/submission';
import { draftInputSchema, type DraftInput } from '../schemas/draft';
import type {
  SubmissionDetail,
  SubmissionWorkspace,
} from '../infrastructure/submission.repository';

type SaveState = 'idle' | 'pending' | 'saving' | 'saved' | 'local' | 'error';

const emptyDocument: JSONContent = { type: 'doc', content: [{ type: 'paragraph' }] };

function RichTextEditor({
  content,
  editable,
  onChange,
}: {
  content: Record<string, unknown>;
  editable: boolean;
  onChange: (document: Record<string, unknown>) => void;
}) {
  const editor = useEditor({
    extensions: [StarterKit],
    content,
    editable,
    immediatelyRender: false,
    editorProps: {
      attributes: { class: 'rich-editor__content', 'aria-label': 'Conteúdo da matéria' },
    },
    onUpdate: ({ editor: currentEditor }) => onChange(currentEditor.getJSON()),
  });

  return (
    <div className="rich-editor">
      {editable ? (
        <div className="rich-editor__toolbar" aria-label="Formatação do texto">
          <button
            type="button"
            onClick={() => editor?.chain().focus().toggleBold().run()}
            aria-pressed={editor?.isActive('bold')}
          >
            Negrito
          </button>
          <button
            type="button"
            onClick={() => editor?.chain().focus().toggleItalic().run()}
            aria-pressed={editor?.isActive('italic')}
          >
            Itálico
          </button>
          <button
            type="button"
            onClick={() => editor?.chain().focus().toggleHeading({ level: 2 }).run()}
            aria-pressed={editor?.isActive('heading', { level: 2 })}
          >
            Título 2
          </button>
          <button
            type="button"
            onClick={() => editor?.chain().focus().toggleBulletList().run()}
            aria-pressed={editor?.isActive('bulletList')}
          >
            Lista
          </button>
          <button
            type="button"
            onClick={() => editor?.chain().focus().toggleBlockquote().run()}
            aria-pressed={editor?.isActive('blockquote')}
          >
            Citação
          </button>
        </div>
      ) : null}
      <EditorContent editor={editor} />
    </div>
  );
}

function saveStateLabel(state: SaveState): string {
  const labels: Record<SaveState, string> = {
    idle: 'Sem alterações',
    pending: 'Alterações aguardando autosave…',
    saving: 'Salvando…',
    saved: 'Rascunho salvo',
    local: 'Sem conexão: cópia preservada neste navegador',
    error: 'Não foi possível salvar. Tente novamente.',
  };
  return labels[state];
}

export function SubmissionEditor({
  contentId,
  workspace,
  initialSubmission = null,
}: {
  contentId: string;
  workspace: SubmissionWorkspace;
  initialSubmission?: SubmissionDetail | null;
}) {
  const router = useRouter();
  const currentStatus = initialSubmission?.content.status ?? 'draft';
  const editable = editableStatuses.includes(currentStatus as (typeof editableStatuses)[number]);
  const [saveState, setSaveState] = useState<SaveState>('idle');
  const [formError, setFormError] = useState<string | null>(null);
  const [assets, setAssets] = useState(initialSubmission?.assets ?? []);
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const inFlightSaveRef = useRef<Promise<number | null> | null>(null);
  const revisionRef = useRef(0);
  const savedRevisionRef = useRef(0);
  const storageKey = `canarinho:draft:${contentId}`;

  const form = useForm<DraftInput>({
    resolver: zodResolver(draftInputSchema),
    defaultValues: {
      contentId,
      lockVersion: initialSubmission?.content.lock_version ?? null,
      idempotencyKey: crypto.randomUUID(),
      type: (initialSubmission?.content.type ?? 'news') as SubmissionContentType,
      title: initialSubmission?.content.title ?? '',
      subtitle: initialSubmission?.content.subtitle ?? '',
      summary: initialSubmission?.content.summary ?? '',
      body: initialSubmission?.content.body ?? emptyDocument,
      authors: initialSubmission?.authors.length
        ? initialSubmission.authors.map((author) => ({
            profile_id: author.profile_id,
            display_name: author.display_name,
          }))
        : [{ profile_id: workspace.profile.id, display_name: null }],
      primaryCategoryId:
        initialSubmission?.categories.find((category) => category.is_primary)?.category_id ?? null,
      tagIds: initialSubmission?.tags.map((tag) => tag.tag_id) ?? [],
      notes: initialSubmission?.content.submission_notes ?? '',
    },
  });
  const authors = useFieldArray({ control: form.control, name: 'authors' });

  const saveDraft = async (): Promise<number | null> => {
    if (!editable) return form.getValues('lockVersion');
    if (inFlightSaveRef.current) {
      const savedLock = await inFlightSaveRef.current;
      return savedLock !== null && revisionRef.current > savedRevisionRef.current
        ? saveDraft()
        : savedLock;
    }

    const operation = (async () => {
      const revision = revisionRef.current;
      const candidate = {
        ...form.getValues(),
        idempotencyKey: crypto.randomUUID(),
      };
      const parsed = draftInputSchema.safeParse(candidate);
      if (!parsed.success) {
        if (candidate.title.trim().length > 0) setSaveState('error');
        return null;
      }
      setSaveState('saving');
      try {
        const response = await fetch('/api/submissoes/rascunhos', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(parsed.data),
        });
        if (response.status === 409) {
          setFormError('Este rascunho foi alterado em outra aba. Recarregue antes de continuar.');
          setSaveState('error');
          return null;
        }
        if (!response.ok) throw new Error('draft_save_failed');
        const result = (await response.json()) as { lock_version: number };
        form.setValue('lockVersion', result.lock_version, { shouldDirty: false });
        form.setValue('idempotencyKey', crypto.randomUUID(), { shouldDirty: false });
        savedRevisionRef.current = revision;
        localStorage.removeItem(storageKey);
        setSaveState('saved');
        if (!initialSubmission) {
          window.history.replaceState(window.history.state, '', `/submissoes/${contentId}/editar`);
        }
        return result.lock_version;
      } catch {
        localStorage.setItem(
          storageKey,
          JSON.stringify({ ...candidate, savedLocallyAt: new Date().toISOString() }),
        );
        setSaveState(navigator.onLine ? 'error' : 'local');
        return null;
      } finally {
        if (revisionRef.current > savedRevisionRef.current && revisionRef.current !== revision) {
          setSaveState('pending');
        }
      }
    })();
    inFlightSaveRef.current = operation;
    let savedLock: number | null;
    try {
      savedLock = await operation;
    } finally {
      if (inFlightSaveRef.current === operation) inFlightSaveRef.current = null;
    }
    return savedLock !== null && revisionRef.current > savedRevisionRef.current
      ? saveDraft()
      : savedLock;
  };
  const saveRef = useRef(saveDraft);
  saveRef.current = saveDraft;

  useEffect(() => {
    // React Hook Form fornece uma assinatura imperativa; ela fica isolada neste efeito.
    // eslint-disable-next-line react-hooks/incompatible-library
    const subscription = form.watch((_values, info) => {
      if (!info.name || info.name === 'lockVersion' || info.name === 'idempotencyKey') return;
      revisionRef.current += 1;
      setSaveState('pending');
      if (timerRef.current) clearTimeout(timerRef.current);
      timerRef.current = setTimeout(() => void saveRef.current(), 1600);
    });
    return () => {
      subscription.unsubscribe();
      if (timerRef.current) clearTimeout(timerRef.current);
    };
  }, [form]);

  const submitForReview = async () => {
    setFormError(null);
    const values = form.getValues();
    if (
      !richTextHasContent(values.body) ||
      values.authors.length === 0 ||
      !values.primaryCategoryId
    ) {
      setFormError('Preencha conteúdo, ao menos um autor e a categoria principal antes de enviar.');
      return;
    }
    if (!workspace.terms) {
      setFormError('Não há uma versão ativa dos termos. Fale com a equipe editorial.');
      return;
    }
    const accepted = document.querySelector<HTMLInputElement>('#aceite-termos')?.checked;
    if (!accepted) {
      setFormError('Você precisa aceitar os termos de submissão.');
      return;
    }
    const lockVersion = await saveDraft();
    if (!lockVersion) return;
    const response = await fetch(`/api/submissoes/${contentId}/enviar`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        lockVersion,
        termsVersion: workspace.terms.version,
        idempotencyKey: crypto.randomUUID(),
      }),
    });
    if (!response.ok) {
      setFormError(
        response.status === 409
          ? 'O rascunho mudou em outra aba. Recarregue antes de enviar.'
          : 'Não foi possível enviar. Revise os campos obrigatórios.',
      );
      return;
    }
    router.push(`/submissoes/${contentId}?enviada=1`);
    router.refresh();
  };

  const uploadFile = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const uploadForm = event.currentTarget;
    const data = new FormData(uploadForm);
    const response = await fetch(`/api/submissoes/${contentId}/arquivos`, {
      method: 'POST',
      body: data,
    });
    if (!response.ok) {
      const result = (await response.json().catch(() => null)) as { error?: string } | null;
      setFormError(
        result?.error === 'image_alt_text_required'
          ? 'Imagens precisam de texto alternativo.'
          : 'Arquivo recusado. Use JPG, PNG, WebP ou PDF de até 10 MB.',
      );
      return;
    }
    const asset = (await response.json()) as (typeof assets)[number];
    setAssets((current) => [...current, asset]);
    uploadForm.reset();
    setFormError(null);
  };

  return (
    <div className="submission-editor">
      <div className="submission-editor__status" role="status" aria-live="polite">
        <span className={`status-dot status-dot--${saveState}`} aria-hidden="true" />
        {editable ? saveStateLabel(saveState) : 'Somente leitura neste estágio editorial'}
      </div>
      {formError ? <p className="form-message form-message--error">{formError}</p> : null}
      <form className="submission-form" onSubmit={(event) => event.preventDefault()}>
        <fieldset disabled={!editable}>
          <legend>Informações editoriais</legend>
          <div className="form-grid form-grid--two">
            <label>
              Título
              <input {...form.register('title')} minLength={3} maxLength={180} required />
              <small>O rascunho começa a ser salvo após três caracteres.</small>
            </label>
            <label>
              Tipo de conteúdo
              <select {...form.register('type')}>
                {submissionContentTypes.map((type) => (
                  <option key={type} value={type}>
                    {submissionContentTypeLabels[type]}
                  </option>
                ))}
              </select>
            </label>
          </div>
          <label>
            Subtítulo
            <input {...form.register('subtitle')} maxLength={240} />
          </label>
          <label>
            Resumo
            <textarea {...form.register('summary')} rows={3} maxLength={600} />
          </label>
        </fieldset>

        <fieldset disabled={!editable}>
          <legend>Texto</legend>
          <RichTextEditor
            content={form.getValues('body')}
            editable={editable}
            onChange={(body) =>
              form.setValue('body', body, { shouldDirty: true, shouldValidate: true })
            }
          />
        </fieldset>

        <fieldset disabled={!editable}>
          <legend>Autoria e classificação</legend>
          <div className="author-list">
            {authors.fields.map((field, index) =>
              field.profile_id ? (
                <div className="author-row" key={field.id}>
                  <span>
                    <strong>{index + 1}.</strong> {workspace.profile.display_name} (você)
                  </span>
                </div>
              ) : (
                <div className="author-row" key={field.id}>
                  <label>
                    Autor ou autora {index + 1}
                    <input
                      {...form.register(`authors.${index}.display_name`)}
                      minLength={2}
                      maxLength={120}
                      required
                    />
                  </label>
                  <button
                    type="button"
                    className="button button--text"
                    onClick={() => authors.remove(index)}
                  >
                    Remover
                  </button>
                </div>
              ),
            )}
            <button
              type="button"
              className="button button--secondary"
              onClick={() => authors.append({ profile_id: null, display_name: '' })}
            >
              Adicionar coautor
            </button>
          </div>
          <div className="form-grid form-grid--two">
            <label>
              Categoria principal
              <select
                {...form.register('primaryCategoryId', { setValueAs: (value) => value || null })}
                required
              >
                <option value="">Selecione</option>
                {workspace.categories.map((category) => (
                  <option key={category.id} value={category.id}>
                    {category.name}
                  </option>
                ))}
              </select>
            </label>
            <div>
              <span className="field-label">Tags</span>
              <div className="check-grid">
                {workspace.tags.map((tag) => (
                  <label className="check-label" key={tag.id}>
                    <input type="checkbox" value={tag.id} {...form.register('tagIds')} />
                    {tag.name}
                  </label>
                ))}
              </div>
            </div>
          </div>
          <label>
            Observações para a equipe
            <textarea {...form.register('notes')} rows={4} maxLength={4000} />
          </label>
        </fieldset>

        <div className="submission-actions">
          <button
            className="button button--secondary"
            type="button"
            disabled={!editable}
            onClick={() => void saveDraft()}
          >
            Salvar agora
          </button>
        </div>
      </form>

      <section className="upload-panel" aria-labelledby="arquivos-titulo">
        <h2 id="arquivos-titulo">Imagens e anexos</h2>
        <p>
          Arquivos ficam privados e vinculados a este rascunho. Formatos: JPG, PNG, WebP e PDF; até
          10 MB.
        </p>
        {assets.length ? (
          <ul>
            {assets.map((asset) => (
              <li key={asset.id}>
                {asset.title ?? asset.object_path}{' '}
                <small>({Math.ceil(asset.byte_size / 1024)} KB)</small>
              </li>
            ))}
          </ul>
        ) : (
          <p className="empty-inline">Nenhum arquivo enviado.</p>
        )}
        {editable && form.getValues('lockVersion') ? (
          <form className="upload-form" onSubmit={(event) => void uploadFile(event)}>
            <label>
              Arquivo
              <input name="arquivo" type="file" accept=".jpg,.jpeg,.png,.webp,.pdf" required />
            </label>
            <label>
              Texto alternativo (obrigatório para imagem)
              <input name="textoAlternativo" maxLength={300} />
            </label>
            <button className="button button--secondary" type="submit">
              Enviar arquivo
            </button>
          </form>
        ) : editable ? (
          <p>Salve o rascunho uma vez para liberar os arquivos.</p>
        ) : null}
      </section>

      {editable && workspace.terms ? (
        <section className="terms-panel" aria-labelledby="termos-titulo">
          <h2 id="termos-titulo">{workspace.terms.title}</h2>
          <p>{workspace.terms.body}</p>
          <label className="check-label check-label--terms">
            <input id="aceite-termos" type="checkbox" />
            Li e aceito os termos da versão {workspace.terms.version}.
          </label>
          <button
            className="button button--primary"
            type="button"
            onClick={() => void submitForReview()}
          >
            Enviar para revisão
          </button>
        </section>
      ) : null}
    </div>
  );
}
