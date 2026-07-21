import { describe, expect, it } from 'vitest';

import { parsePublicEnvironment, parseServerEnvironment } from './environment.schema';

const validPublicEnvironment = {
  NEXT_PUBLIC_APP_ENV: 'local',
  NEXT_PUBLIC_SITE_URL: 'http://localhost:3000',
  NEXT_PUBLIC_SUPABASE_URL: 'http://127.0.0.1:54321',
  NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: 'sb_publishable_local_test_key',
};

describe('parsePublicEnvironment', () => {
  it('aceita apenas um ambiente conhecido com URLs validas', () => {
    expect(parsePublicEnvironment(validPublicEnvironment)).toEqual(validPublicEnvironment);
  });

  it('falha cedo quando uma variavel obrigatoria esta ausente', () => {
    expect(() =>
      parsePublicEnvironment({
        ...validPublicEnvironment,
        NEXT_PUBLIC_SITE_URL: undefined,
      }),
    ).toThrow();
  });

  it('rejeita uma service role no espaco publico', () => {
    expect(() =>
      parsePublicEnvironment({
        ...validPublicEnvironment,
        NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: 'service_role_nao_pode_ser_publica',
      }),
    ).toThrow(/service_role/);
  });
});

describe('parseServerEnvironment', () => {
  it('permite omitir a service role enquanto nao houver operacao privilegiada', () => {
    expect(parseServerEnvironment({}).SUPABASE_SERVICE_ROLE_KEY).toBeUndefined();
  });

  it('rejeita uma service role prefixada como publica', () => {
    expect(() =>
      parseServerEnvironment({
        NEXT_PUBLIC_SUPABASE_SERVICE_ROLE_KEY: 'segredo_exposto_indevidamente',
      }),
    ).toThrow(/NEXT_PUBLIC_/);
  });
});
