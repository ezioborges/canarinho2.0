import { NextResponse, type NextRequest } from 'next/server';

import { submitInputSchema } from '@/modules/editorial/contracts';
import { createSupabaseServerClient } from '@/shared/lib/supabase/server';

type RouteContext = { params: Promise<{ id: string }> };

export async function POST(request: NextRequest, context: RouteContext) {
  const origin = request.headers.get('origin');
  if (
    request.headers.get('sec-fetch-site') === 'cross-site' ||
    (origin && origin !== request.nextUrl.origin)
  ) {
    return NextResponse.json({ error: 'origin_not_allowed' }, { status: 403 });
  }
  const { id } = await context.params;
  const body = (await request.json().catch(() => null)) as Record<string, unknown> | null;
  const parsed = submitInputSchema.safeParse({ ...(body ?? {}), contentId: id });
  if (!parsed.success) {
    return NextResponse.json({ error: 'invalid_submission' }, { status: 422 });
  }

  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.rpc('submit_own_content', {
    requested_content_id: parsed.data.contentId,
    expected_lock_version: parsed.data.lockVersion,
    requested_terms_version: parsed.data.termsVersion,
    idempotency_key: parsed.data.idempotencyKey,
  });
  if (error) {
    const status = error.code === '40001' ? 409 : error.code === '42501' ? 403 : 400;
    return NextResponse.json({ error: error.message, code: error.code }, { status });
  }
  return NextResponse.json(data);
}
