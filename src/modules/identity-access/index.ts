export const identityAccessModule = {
  id: 'identity-access',
  label: 'Identidade e acesso',
} as const;

export { getAuthenticatedSession } from './infrastructure/session.repository';
export type { AppRole, AuthenticatedSession } from './infrastructure/session.repository';

export {
  requestPasswordReset,
  signIn,
  signOut,
  signUp,
  updatePassword,
  updateProfile,
} from './application/auth-actions';
export { safeReturnPath } from './domain/return-path';
export { credentialsSchema, profileSchema, signupSchema } from './schemas/account';
