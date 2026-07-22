export const communityModule = {
  id: 'community',
  label: 'Comunidade',
} as const;

export {
  addPublicCommentAction,
  moderateCommentAction,
  reportCommentAction,
  setFavoriteAction,
} from './application/community-actions';
export {
  getContentCommunity,
  listModerationQueue,
  listOwnFavorites,
} from './infrastructure/community.repository';
export type {
  CommentCursor,
  ContentCommunity,
  ModerationQueueItem,
  PublicComment,
} from './infrastructure/community.repository';
export { CommentSection } from './presentation/comment-section';
export { FavoriteButton } from './presentation/favorite-button';
