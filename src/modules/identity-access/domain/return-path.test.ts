import { describe, expect, it } from 'vitest';

import { safeReturnPath } from './return-path';

describe('safeReturnPath', () => {
  it('preserva somente caminhos internos', () => {
    expect(safeReturnPath('/submissoes/nova?origem=home')).toBe('/submissoes/nova?origem=home');
  });

  it.each(['https://evil.test', '//evil.test', 'javascript:alert(1)', null])(
    'bloqueia retorno externo %s',
    (value) => {
      expect(safeReturnPath(value)).toBe('/submissoes');
    },
  );
});
