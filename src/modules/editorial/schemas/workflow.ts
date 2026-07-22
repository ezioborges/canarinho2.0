import { z } from 'zod';

import { editorialStatuses } from '../domain/submission';

const nullableText = (maximum: number) => z.string().trim().max(maximum);

export const editorialTransitionSchema = z.object({
  contentId: z.uuid(),
  lockVersion: z.coerce.number().int().positive(),
  status: z.enum(editorialStatuses),
  justification: z.string().trim().min(3).max(2000),
  schedule: z.iso.datetime({ local: true }).optional(),
  directorException: z.boolean(),
});

export const editorialCommentSchema = z.object({
  contentId: z.uuid(),
  versionId: z.uuid(),
  body: z.string().trim().min(3).max(4000),
});

export const editorialSaveSchema = z.object({
  contentId: z.uuid(),
  lockVersion: z.coerce.number().int().positive(),
  title: z.string().trim().min(3).max(180),
  subtitle: nullableText(240),
  summary: nullableText(600),
  body: z.record(z.string(), z.unknown()),
  primaryCategoryId: z.uuid().nullable(),
  tagIds: z.array(z.uuid()).max(12),
  coverAssetId: z.uuid().nullable(),
  seoTitle: nullableText(70),
  seoDescription: nullableText(170),
  readingTimeMinutes: z.coerce.number().int().min(1).max(240),
  justification: z.string().trim().min(3).max(2000),
});

export const restoreVersionSchema = z.object({
  contentId: z.uuid(),
  versionId: z.uuid(),
  lockVersion: z.coerce.number().int().positive(),
  justification: z.string().trim().min(3).max(2000),
});

export type EditorialSaveInput = z.infer<typeof editorialSaveSchema>;
