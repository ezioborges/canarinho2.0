export const organizationModule = {
  id: 'organization',
  label: 'Organizacao',
} as const;

export {
  archiveTeamMemberAction,
  saveTeamMemberAction,
  submitRecruitmentApplicationAction,
  updateRecruitmentApplicationAction,
} from './application/organization-actions';
export {
  getOrganizationAdmin,
  listPublicOpenings,
  listPublicTeam,
} from './infrastructure/organization.repository';
export type {
  OrganizationAdmin,
  PublicOpening,
  PublicTeamArea,
  RecruitmentApplication,
} from './infrastructure/organization.repository';
