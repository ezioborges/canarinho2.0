import type { EditorialStatus } from './submission';

export const reviewQueueStatuses = ['submitted', 'under_review', 'changes_requested'] as const;
export const editorQueueStatuses = [
  'approved',
  'in_editing',
  'scheduled',
  'published',
  'archived',
] as const;

export type EditorialRole = 'revisor' | 'editor' | 'diretor';
export type EditorialAction =
  | 'assign_review'
  | 'request_changes'
  | 'approve'
  | 'reject'
  | 'reopen'
  | 'start_editing'
  | 'cancel_schedule'
  | 'schedule'
  | 'publish'
  | 'archive'
  | 'republish'
  | 'director_publish';

export function availableEditorialActions(
  status: EditorialStatus,
  roles: readonly EditorialRole[],
): EditorialAction[] {
  const isDirector = roles.includes('diretor');
  const isReviewer = roles.includes('revisor') || isDirector;
  const isEditor = roles.includes('editor') || isDirector;
  const actions: EditorialAction[] = [];

  if (status === 'submitted' && isReviewer) actions.push('assign_review');
  if (status === 'under_review' && isReviewer) {
    actions.push('request_changes', 'approve', 'reject');
  }
  if (status === 'rejected' && isDirector) actions.push('reopen');
  if (status === 'approved' && isEditor) actions.push('start_editing');
  if (status === 'in_editing' && isEditor) actions.push('schedule', 'publish');
  if (status === 'scheduled' && isEditor) actions.push('cancel_schedule');
  if (status === 'published' && isEditor) actions.push('archive');
  if (status === 'archived' && isEditor) actions.push('republish');
  if (!['published', 'archived'].includes(status) && isDirector) actions.push('director_publish');

  return actions;
}
