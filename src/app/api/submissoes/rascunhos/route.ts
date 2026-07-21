import { NextResponse, type NextRequest } from 'next/server';

import { draftInputSchema } from '@/modules/editorial/contracts';
import { saveOwnDraft } from '@/modules/editorial/server';

function isSameOrigin(request: NextRequest): boolean {
  const fetchSite = request.headers.get('sec-fetch-site');
  const origin = request.headers.get('origin');
  return fetchSite !== 'cross-site' && (!origin || origin === request.nextUrl.origin);
}

export async function POST(request: NextRequest) {
  if (!isSameOrigin(request)) {
    return NextResponse.json({ error: 'origin_not_allowed' }, { status: 403 });
  }
  const parsed = draftInputSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) {
    return NextResponse.json(
      { error: 'invalid_draft', issues: parsed.error.flatten().fieldErrors },
      { status: 422 },
    );
  }

  const { data, error } = await saveOwnDraft(parsed.data);
  if (error) {
    const status = error.code === '40001' ? 409 : error.code === '42501' ? 403 : 400;
    return NextResponse.json({ error: error.message, code: error.code }, { status });
  }
  return NextResponse.json(data);
}
