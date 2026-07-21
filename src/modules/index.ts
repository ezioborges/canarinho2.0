import { administrationModule } from './administration';
import { analyticsModule } from './analytics';
import { communicationsModule } from './communications';
import { communityModule } from './community';
import { editorialModule } from './editorial';
import { identityAccessModule } from './identity-access';
import { mediaModule } from './media';
import { organizationModule } from './organization';
import { publicPortalModule } from './public-portal';
import { taxonomyCurationModule } from './taxonomy-curation';

export const moduleCatalog = [
  identityAccessModule,
  editorialModule,
  taxonomyCurationModule,
  mediaModule,
  publicPortalModule,
  communityModule,
  communicationsModule,
  analyticsModule,
  organizationModule,
  administrationModule,
] as const;
