'use client';

import { createBrowserClient } from '@supabase/ssr';

import { publicEnvironment } from '@/shared/config/public-environment';

export function createSupabaseBrowserClient() {
  return createBrowserClient(
    publicEnvironment.NEXT_PUBLIC_SUPABASE_URL,
    publicEnvironment.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
  );
}
