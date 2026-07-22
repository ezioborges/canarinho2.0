import { z } from 'zod';

const optionalUuid = z.preprocess((value) => (value === '' ? null : value), z.uuid().nullable());

export const newsletterSubscriptionSchema = z.object({
  email: z
    .string()
    .trim()
    .pipe(z.email('Informe um email válido.'))
    .transform((email) => email.toLowerCase()),
  consent: z.literal('on', { error: 'Autorize o envio da newsletter.' }),
  website: z.string().max(0).default(''),
  returnPath: z.enum(['/', '/informes']).default('/'),
});

export const noticeSchema = z.object({
  noticeId: optionalUuid,
  title: z.string().trim().min(3).max(180),
  slug: z
    .string()
    .trim()
    .regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/),
  summary: z.string().trim().min(10).max(500),
  body: z.string().trim().min(10).max(10_000),
  audience: z.enum(['general', 'students', 'team', 'authors', 'visitors']),
  commentsEnabled: z
    .string()
    .optional()
    .transform((value) => value === 'on'),
  expiresAt: z
    .string()
    .optional()
    .transform((value) => (value ? new Date(value).toISOString() : null)),
});

export const noticeStatusSchema = z.object({
  noticeId: z.uuid(),
  action: z.enum(['publish', 'archive']),
  reason: z.string().trim().min(3).max(1000),
});

export const noticePinSchema = z.object({
  noticeId: z.uuid(),
  pinned: z.enum(['true', 'false']).transform((value) => value === 'true'),
  reason: z.string().trim().min(3).max(1000),
});

export const noticeCommentSchema = z.object({
  noticeId: z.uuid(),
  slug: z.string().regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/),
  body: z.string().trim().min(3).max(2000),
  idempotencyKey: z.uuid(),
});

export const campaignSchema = z.object({
  campaignId: optionalUuid,
  name: z.string().trim().min(3).max(120),
  subject: z.string().trim().min(3).max(180),
  previewText: z.string().trim().max(240),
  bodyText: z.string().trim().min(10).max(20_000),
  segment: z.enum(['all', 'students', 'authors']),
});

export const campaignScheduleSchema = z.object({
  campaignId: z.uuid(),
  scheduledAt: z.string().transform((value) => new Date(value).toISOString()),
  reason: z.string().trim().min(3).max(1000),
});

export const campaignCommandSchema = z.object({
  campaignId: z.uuid(),
  reason: z.string().trim().min(3).max(1000),
});

export const subscriberCommandSchema = z.object({
  subscriberId: z.uuid(),
  reason: z.string().trim().min(3).max(1000),
});

export const exportRequestSchema = z.object({
  reason: z.string().trim().min(3).max(1000),
});
