import { NextResponse } from 'next/server';

import { publicEnvironment } from '@/shared/config/public-environment';
import { createSupabaseServerClient } from '@/shared/lib/supabase/server';

export async function GET(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const supabase = await createSupabaseServerClient();
  const { data } = await supabase.auth.getSession();
  if (!data.session) return NextResponse.redirect(new URL('/entrar', request.url));
  const response = await fetch(
    `${publicEnvironment.NEXT_PUBLIC_SUPABASE_URL}/functions/v1/communications-worker`,
    {
      method: 'POST',
      headers: {
        authorization: `Bearer ${data.session.access_token}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({ action: 'download-export', exportId: id }),
    },
  );
  if (!response.ok) {
    return NextResponse.redirect(
      new URL('/admin/comunicacoes?erro=Exportacao+indisponivel.', request.url),
    );
  }
  const result = (await response.json()) as { signedUrl?: string };
  if (!result.signedUrl) {
    return NextResponse.redirect(
      new URL('/admin/comunicacoes?erro=Exportacao+expirada.', request.url),
    );
  }
  return NextResponse.redirect(result.signedUrl);
}
