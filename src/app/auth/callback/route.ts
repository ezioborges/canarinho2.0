import { NextResponse, type NextRequest } from 'next/server';

import { safeReturnPath } from '@/modules/identity-access';
import { createSupabaseServerClient } from '@/shared/lib/supabase/server';

export async function GET(request: NextRequest) {
  const code = request.nextUrl.searchParams.get('code');
  const returnPath = safeReturnPath(request.nextUrl.searchParams.get('retorno'));
  if (code) {
    const supabase = await createSupabaseServerClient();
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (!error) {
      return NextResponse.redirect(new URL(returnPath, request.url));
    }
  }
  return NextResponse.redirect(
    new URL('/entrar?erro=Link%20inválido%20ou%20expirado.', request.url),
  );
}
