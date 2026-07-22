import { describe, expect, it } from 'vitest';

import { availableEditorialActions } from './workflow';

describe('availableEditorialActions', () => {
  it('separa revisão e edição por papel', () => {
    expect(availableEditorialActions('submitted', ['revisor'])).toEqual(['assign_review']);
    expect(availableEditorialActions('approved', ['revisor'])).toEqual([]);
    expect(availableEditorialActions('approved', ['editor'])).toEqual(['start_editing']);
  });

  it('oferece exceção e reabertura somente à Direção', () => {
    expect(availableEditorialActions('rejected', ['editor'])).toEqual([]);
    expect(availableEditorialActions('rejected', ['diretor'])).toEqual([
      'reopen',
      'director_publish',
    ]);
  });

  it('mantém agendamento cancelável antes do job', () => {
    expect(availableEditorialActions('scheduled', ['editor'])).toEqual(['cancel_schedule']);
  });
});
