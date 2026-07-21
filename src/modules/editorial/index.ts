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
  getOwnSubmission,
  getSubmissionWorkspace,
  listOwnSubmissions,
  saveOwnDraft,
} from './infrastructure/submission.repository';
export type {
  SubmissionDetail,
  SubmissionListItem,
  SubmissionWorkspace,
} from './infrastructure/submission.repository';
export { draftInputSchema, submitInputSchema } from './schemas/draft';
export type { DraftInput } from './schemas/draft';
