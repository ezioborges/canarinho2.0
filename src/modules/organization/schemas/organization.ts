import { z } from 'zod';

const optionalText = (maximum: number) =>
  z
    .string()
    .trim()
    .max(maximum)
    .transform((value) => value || null);

export const teamMemberSchema = z.object({
  memberId: z.union([z.string().uuid(), z.literal('')]).transform((value) => value || null),
  areaId: z.string().uuid(),
  name: z.string().trim().min(2).max(120),
  roleTitle: z.string().trim().min(2).max(120),
  bio: optionalText(1000),
  publicContact: optionalText(200),
  position: z.coerce.number().int().min(1).max(32767),
});

export const archiveMemberSchema = z.object({
  memberId: z.string().uuid(),
  reason: z.string().trim().min(3).max(1000),
});

export const recruitmentApplicationSchema = z.object({
  openingId: z.string().uuid(),
  name: z.string().trim().min(2).max(120),
  email: z.string().trim().email().max(254),
  affiliation: z.string().trim().min(2).max(200),
  message: z.string().trim().min(20).max(4000),
  consent: z.literal('on'),
  website: z.string().max(0),
});

export const applicationReviewSchema = z.object({
  applicationId: z.string().uuid(),
  status: z.enum(['received', 'in_review', 'shortlisted', 'rejected', 'withdrawn']),
  note: z.string().trim().min(3).max(2000),
});
