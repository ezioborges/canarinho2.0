import { z } from 'zod';

const uuidSchema = z.string().uuid();

export const publicCommentSchema = z.object({
  contentId: uuidSchema,
  slug: z.string().regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/),
  body: z.string().trim().min(3, 'Escreva ao menos 3 caracteres.').max(2000),
  idempotencyKey: uuidSchema,
});

export const reportCommentSchema = z.object({
  commentId: uuidSchema,
  slug: z.string().regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/),
  reason: z.string().trim().min(3).max(1000),
});

export const favoriteSchema = z.object({
  contentId: uuidSchema,
  slug: z.string().regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/),
  favorite: z.enum(['true', 'false']).transform((value) => value === 'true'),
});

export const moderationSchema = z.object({
  commentId: uuidSchema,
  action: z.enum(['hide', 'restore', 'remove']),
  reason: z.string().trim().min(3).max(1000),
});
