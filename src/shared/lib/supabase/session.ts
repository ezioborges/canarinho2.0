import 'server-only';

import { cache } from 'react';

import { createSupabaseServerClient } from './server';

export const getAuthenticatedUser = cache(async () => {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  return user;
});
