import { describe, expect, it } from 'vitest';

import { newsletterSubscriptionSchema, noticeSchema } from './communications';

describe('communications schemas', () => {
  it('normaliza o email e exige consentimento explicito', () => {
    const result = newsletterSubscriptionSchema.parse({
      email: '  PESSOA@EXAMPLE.COM ',
      consent: 'on',
      website: '',
      returnPath: '/',
    });
    expect(result.email).toBe('pessoa@example.com');
  });

  it('rejeita slug de informe fora do formato canonico', () => {
    const result = noticeSchema.safeParse({
      noticeId: '',
      title: 'Um informe válido',
      slug: 'Informe Com Espaço',
      summary: 'Resumo suficientemente descritivo.',
      body: 'Corpo suficientemente descritivo para o informe.',
      audience: 'general',
      commentsEnabled: 'on',
      expiresAt: '',
    });
    expect(result.success).toBe(false);
  });
});
