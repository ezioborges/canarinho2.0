import { NextResponse } from 'next/server';

import { publicEnvironment } from '@/shared/config/public-environment';
import { createSupabaseServerClient } from '@/shared/lib/supabase/server';

export async function POST(request: Request) {
  const supabase = await createSupabaseServerClient();
  const { data } = await supabase.auth.getSession();
  if (!data.session) return NextResponse.redirect(new URL('/entrar', request.url), 303);
  const response = await fetch(
    `${publicEnvironment.NEXT_PUBLIC_SUPABASE_URL}/functions/v1/communications-worker`,
    {
      method: 'POST',
      headers: {
        authorization: `Bearer ${data.session.access_token}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({ action: 'all', batchSize: 50 }),
    },
  );
  const message = response.ok ? 'Fila+processada.' : 'Worker+indisponivel.';
  return NextResponse.redirect(
    new URL(`/admin/comunicacoes?${response.ok ? 'sucesso' : 'erro'}=${message}`, request.url),
    303,
  );
}
