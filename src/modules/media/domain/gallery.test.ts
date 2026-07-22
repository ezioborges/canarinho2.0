import { describe, expect, it } from 'vitest';

import { hasCompleteGalleryMetadata } from './gallery';

describe('hasCompleteGalleryMetadata', () => {
  it('aceita uma imagem com descricao, credito, licenca e titulo', () => {
    expect(
      hasCompleteGalleryMetadata({
        alt: 'Sombras sobre uma escadaria.',
        credit: 'Foto: Equipe Canarinho',
        license: 'CC BY-NC 4.0',
        title: 'Geometrias do campus',
      }),
    ).toBe(true);
  });

  it('recusa metadado vazio', () => {
    expect(
      hasCompleteGalleryMetadata({
        alt: 'Descrição acessível',
        credit: ' ',
        license: 'CC BY-NC 4.0',
        title: 'Imagem',
      }),
    ).toBe(false);
  });
});
