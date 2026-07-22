import type { NextRequest } from 'next/server';
import { NextResponse } from 'next/server';

import { createSupabaseServerClient } from '@/shared/lib/supabase/server';

export async function GET(request: NextRequest) {
  const token = request.nextUrl.searchParams.get('token') ?? '';
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.rpc('unsubscribe_newsletter', {
    requested_token: token,
  });
  const message =
    !error && data
      ? 'Descadastro+concluido.+Este+email+nao+recebera+novas+campanhas.'
      : 'Link+de+descadastro+invalido.';
  return NextResponse.redirect(new URL(`/informes?newsletter=${message}`, request.url));
}
