export const editorialModule = {
  id: 'editorial',
  label: 'Editorial',
} as const;

export {
  editableStatuses,
  editorialStatusLabels,
  editorialStatuses,
  richTextHasContent,
  slugForDraft,
  submissionContentTypeLabels,
  submissionContentTypes,
} from './domain/submission';
export type { EditorialStatus, SubmissionContentType } from './domain/submission';
export {
  availableEditorialActions,
  editorQueueStatuses,
  reviewQueueStatuses,
} from './domain/workflow';
export type { EditorialAction, EditorialRole } from './domain/workflow';
export {
  getEditorialDetail,
  getEditorialSession,
  getOwnSubmission,
  getSubmissionWorkspace,
  listEditorQueue,
  listOwnSubmissions,
  listReviewQueue,
  saveOwnDraft,
} from './infrastructure/submission.repository';
export type {
  EditorialDetail,
  EditorialQueueItem,
  EditorialSession,
  SubmissionDetail,
  SubmissionListItem,
  SubmissionWorkspace,
} from './infrastructure/submission.repository';
export { draftInputSchema, submitInputSchema } from './schemas/draft';
export type { DraftInput } from './schemas/draft';
export {
  editorialCommentSchema,
  editorialSaveSchema,
  editorialTransitionSchema,
  restoreVersionSchema,
} from './schemas/workflow';
export type { EditorialSaveInput } from './schemas/workflow';
