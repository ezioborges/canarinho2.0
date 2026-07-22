import type { NextRequest } from 'next/server';
import { NextResponse } from 'next/server';

import { createSupabaseServerClient } from '@/shared/lib/supabase/server';

export async function GET(request: NextRequest) {
  const token = request.nextUrl.searchParams.get('token') ?? '';
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.rpc('confirm_newsletter_subscription', {
    requested_token: token,
  });
  const message =
    !error && data
      ? 'Inscricao+confirmada.+Bem-vinda+a+Carta+do+Canarinho.'
      : 'Link+de+confirmacao+invalido+ou+expirado.';
  return NextResponse.redirect(new URL(`/informes?newsletter=${message}`, request.url));
}
