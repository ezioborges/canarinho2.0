export const communicationsModule = {
  id: 'communications',
  label: 'Comunicacoes',
} as const;

export {
  addNoticeCommentAction,
  cancelCampaignAction,
  changeNoticeStatusAction,
  inactivateSubscriberAction,
  markNotificationReadAction,
  requestNewsletterExportAction,
  retryCampaignAction,
  saveCampaignAction,
  saveNoticeAction,
  scheduleCampaignAction,
  setNoticePinnedAction,
  subscribeNewsletterAction,
} from './application/communications-actions';
export {
  getCommunicationsAdmin,
  getPublicNotice,
  listOwnNotifications,
  listPublicNotices,
} from './infrastructure/communications.repository';
export type {
  CommunicationsAdmin,
  NoticeComment,
  PublicNotice,
  UserNotification,
} from './infrastructure/communications.repository';
export { NewsletterForm } from './presentation/newsletter-form';
