import { describe, expect, it } from 'vitest';

import { extractText, isContentType, readingTimeInMinutes } from './content';

describe('public portal content domain', () => {
  it('accepts only content types supported by the domain', () => {
    expect(isContentType('poem')).toBe(true);
    expect(isContentType('private_note')).toBe(false);
  });

  it('extracts text without trusting rendered HTML', () => {
    const document = {
      type: 'doc' as const,
      content: [
        { type: 'paragraph', content: [{ type: 'text', text: 'Primeiro trecho' }] },
        { type: 'paragraph', content: [{ type: 'text', text: 'segundo trecho' }] },
      ],
    };

    expect(extractText(document)).toBe('Primeiro trecho segundo trecho');
  });

  it('always returns at least one minute of reading', () => {
    expect(readingTimeInMinutes({ type: 'doc', content: [] })).toBe(1);
  });
});
