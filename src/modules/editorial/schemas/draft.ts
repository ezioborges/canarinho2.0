import { z } from 'zod';

import { submissionContentTypes } from '../domain/submission';

const authorSchema = z
  .object({
    profile_id: z.uuid().nullable(),
    display_name: z.string().trim().max(120).nullable(),
  })
  .refine(
    (author) => author.profile_id !== null || (author.display_name?.length ?? 0) >= 2,
    'Informe o nome do coautor.',
  );

export const draftInputSchema = z.object({
  contentId: z.uuid(),
  lockVersion: z.number().int().positive().nullable(),
  idempotencyKey: z.uuid(),
  type: z.enum(submissionContentTypes),
  title: z.string().trim().min(3).max(180),
  subtitle: z.string().trim().max(240),
  summary: z.string().trim().max(600),
  body: z.record(z.string(), z.unknown()),
  authors: z.array(authorSchema).max(10),
  primaryCategoryId: z.uuid().nullable(),
  tagIds: z.array(z.uuid()).max(12),
  notes: z.string().max(4000),
});

export const submitInputSchema = z.object({
  contentId: z.uuid(),
  lockVersion: z.number().int().positive(),
  termsVersion: z.string().regex(/^[0-9]{4}-[0-9]{2}$/),
  idempotencyKey: z.uuid(),
});

export type DraftInput = z.infer<typeof draftInputSchema>;
