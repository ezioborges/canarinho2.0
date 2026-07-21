import { z } from 'zod';

export const credentialsSchema = z.object({
  email: z.email('Informe um email válido.').max(254),
  password: z.string().min(8, 'A senha deve ter ao menos 8 caracteres.').max(128),
});

export const signupSchema = credentialsSchema.extend({
  displayName: z.string().trim().min(2, 'Informe seu nome público.').max(120),
});

export const profileSchema = z.object({
  displayName: z.string().trim().min(2).max(120),
  course: z.string().trim().max(120).optional(),
  affiliation: z.string().trim().max(120).optional(),
});
