'use client';

import { EditorContent, type JSONContent, useEditor } from '@tiptap/react';
import { StarterKit } from '@tiptap/starter-kit';
import { useState } from 'react';

import { saveEditorialContentAction } from '../application/editorial-actions';
import type { EditorialDetail } from '../infrastructure/submission.repository';

function FinalRichTextEditor({
  initialContent,
  onChange,
}: {
  initialContent: Record<string, unknown>;
  onChange: (content: JSONContent) => void;
}) {
  const editor = useEditor({
    extensions: [StarterKit],
    content: initialContent,
    immediatelyRender: false,
    editorProps: {
      attributes: { class: 'rich-editor__content', 'aria-label': 'Conteúdo final da matéria' },
    },
    onUpdate: ({ editor: currentEditor }) => onChange(currentEditor.getJSON()),
  });

  return (
    <div className="rich-editor">
      <div className="rich-editor__toolbar" aria-label="Formatação do texto">
        <button type="button" onClick={() => editor?.chain().focus().toggleBold().run()}>
          Negrito
        </button>
        <button type="button" onClick={() => editor?.chain().focus().toggleItalic().run()}>
          Itálico
        </button>
        <button
          type="button"
          onClick={() => editor?.chain().focus().toggleHeading({ level: 2 }).run()}
        >
          Título 2
        </button>
        <button type="button" onClick={() => editor?.chain().focus().toggleBulletList().run()}>
          Lista
        </button>
        <button type="button" onClick={() => editor?.chain().focus().toggleBlockquote().run()}>
          Citação
        </button>
      </div>
      <EditorContent editor={editor} />
    </div>
  );
}

export function FinalEditor({ detail }: { detail: EditorialDetail }) {
  const [body, setBody] = useState<Record<string, unknown>>(detail.content.body);

  return (
    <form className="submission-form editorial-form" action={saveEditorialContentAction}>
      <input type="hidden" name="contentId" value={detail.content.id} />
      <input type="hidden" name="lockVersion" value={detail.content.lock_version} />
      <input type="hidden" name="body" value={JSON.stringify(body)} />
      <fieldset>
        <legend>Edição final</legend>
        <label>
          Título
          <input
            name="title"
            required
            minLength={3}
            maxLength={180}
            defaultValue={detail.content.title}
          />
        </label>
        <div className="form-grid form-grid--two">
          <label>
            Subtítulo
            <input name="subtitle" maxLength={240} defaultValue={detail.content.subtitle ?? ''} />
          </label>
          <label>
            Tempo de leitura (minutos)
            <input
              name="readingTimeMinutes"
              type="number"
              min={1}
              max={240}
              required
              defaultValue={detail.content.reading_time_minutes ?? 1}
            />
          </label>
        </div>
        <label>
          Resumo
          <textarea
            name="summary"
            rows={3}
            maxLength={600}
            defaultValue={detail.content.summary ?? ''}
          />
        </label>
        <div className="field-label">
          Conteúdo
          <FinalRichTextEditor initialContent={detail.content.body} onChange={setBody} />
        </div>
      </fieldset>

      <fieldset>
        <legend>Publicação e descoberta</legend>
        <div className="form-grid form-grid--two">
          <label>
            Categoria principal
            <select name="primaryCategoryId" defaultValue={detail.selectedCategoryId ?? ''}>
              <option value="">Selecione</option>
              {detail.categories.map((category) => (
                <option key={category.id} value={category.id}>
                  {category.name}
                </option>
              ))}
            </select>
          </label>
          <label>
            Capa pública
            <select name="coverAssetId" defaultValue={detail.content.cover_asset_id ?? ''}>
              <option value="">Selecione</option>
              {detail.covers.map((cover) => (
                <option key={cover.id} value={cover.id}>
                  {cover.title ?? cover.alt_text ?? cover.id}
                </option>
              ))}
            </select>
          </label>
        </div>
        <div>
          <span className="field-label">Tags</span>
          <div className="check-grid">
            {detail.tags.map((tag) => (
              <label className="check-label" key={tag.id}>
                <input
                  name="tagIds"
                  type="checkbox"
                  value={tag.id}
                  defaultChecked={detail.selectedTagIds.includes(tag.id)}
                />
                {tag.name}
              </label>
            ))}
          </div>
        </div>
        <label>
          Título SEO
          <input name="seoTitle" maxLength={70} defaultValue={detail.content.seo_title ?? ''} />
        </label>
        <label>
          Descrição SEO
          <textarea
            name="seoDescription"
            rows={3}
            maxLength={170}
            defaultValue={detail.content.seo_description ?? ''}
          />
        </label>
        <label>
          Motivo da edição
          <textarea name="justification" minLength={3} maxLength={2000} rows={3} required />
          <small>O motivo integra a auditoria e ajuda a comparar versões.</small>
        </label>
        <button className="button button--primary" type="submit">
          Salvar versão editorial
        </button>
      </fieldset>
    </form>
  );
}
