import { z } from 'zod';

const applicationEnvironmentSchema = z.enum(['local', 'development', 'staging', 'production']);

const publicEnvironmentSchema = z.object({
  NEXT_PUBLIC_APP_ENV: applicationEnvironmentSchema,
  NEXT_PUBLIC_SITE_URL: z.url(),
  NEXT_PUBLIC_SUPABASE_URL: z.url(),
  NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: z
    .string()
    .min(20)
    .refine((key) => !key.toLowerCase().includes('service_role'), {
      message: 'a chave publica nao pode ser uma service_role',
    }),
});

const serverEnvironmentSchema = z.object({
  SUPABASE_SERVICE_ROLE_KEY: z.preprocess(
    (value) => (value === '' ? undefined : value),
    z.string().min(20).optional(),
  ),
  NEXT_PUBLIC_SUPABASE_SERVICE_ROLE_KEY: z.undefined({
    error: 'service_role nunca pode usar o prefixo NEXT_PUBLIC_',
  }),
});

type EnvironmentSource = Record<string, string | undefined>;

export type PublicEnvironment = z.infer<typeof publicEnvironmentSchema>;
export type ServerEnvironment = z.infer<typeof serverEnvironmentSchema>;

export function parsePublicEnvironment(source: EnvironmentSource): PublicEnvironment {
  return publicEnvironmentSchema.parse({
    NEXT_PUBLIC_APP_ENV: source.NEXT_PUBLIC_APP_ENV,
    NEXT_PUBLIC_SITE_URL: source.NEXT_PUBLIC_SITE_URL,
    NEXT_PUBLIC_SUPABASE_URL: source.NEXT_PUBLIC_SUPABASE_URL,
    NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: source.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
  });
}

export function parseServerEnvironment(source: EnvironmentSource): ServerEnvironment {
  return serverEnvironmentSchema.parse({
    SUPABASE_SERVICE_ROLE_KEY: source.SUPABASE_SERVICE_ROLE_KEY,
    NEXT_PUBLIC_SUPABASE_SERVICE_ROLE_KEY: source.NEXT_PUBLIC_SUPABASE_SERVICE_ROLE_KEY,
  });
}
