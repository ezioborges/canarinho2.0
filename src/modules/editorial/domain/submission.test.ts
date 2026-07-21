import { describe, expect, it } from 'vitest';

import { richTextHasContent, slugForDraft } from './submission';

describe('submissao editorial', () => {
  it('gera slug estavel com sufixo do agregado', () => {
    expect(slugForDraft('Ciência & Extensão!', '12345678-1234-4000-8000-123456789012')).toBe(
      'ciencia-extensao-12345678',
    );
  });

  it('distingue documento vazio de documento com texto', () => {
    expect(richTextHasContent({ type: 'doc', content: [{ type: 'paragraph' }] })).toBe(false);
    expect(
      richTextHasContent({
        type: 'doc',
        content: [{ type: 'paragraph', content: [{ type: 'text', text: 'Texto' }] }],
      }),
    ).toBe(true);
  });
});
