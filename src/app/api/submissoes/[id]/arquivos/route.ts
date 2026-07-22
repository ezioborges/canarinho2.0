import { NextResponse, type NextRequest } from 'next/server';

import { createSupabaseServerClient } from '@/shared/lib/supabase/server';

const MAX_FILE_SIZE = 10 * 1024 * 1024;
const allowedFiles: Record<
  string,
  { extensions: string[]; purpose: 'inline_image' | 'attachment' }
> = {
  'image/jpeg': { extensions: ['jpg', 'jpeg'], purpose: 'inline_image' },
  'image/png': { extensions: ['png'], purpose: 'inline_image' },
  'image/webp': { extensions: ['webp'], purpose: 'inline_image' },
  'application/pdf': { extensions: ['pdf'], purpose: 'attachment' },
};

type RouteContext = { params: Promise<{ id: string }> };

export async function POST(request: NextRequest, context: RouteContext) {
  const origin = request.headers.get('origin');
  if (
    request.headers.get('sec-fetch-site') === 'cross-site' ||
    (origin && origin !== request.nextUrl.origin)
  ) {
    return NextResponse.json({ error: 'origin_not_allowed' }, { status: 403 });
  }
  const { id: contentId } = await context.params;
  const formData = await request.formData();
  const file = formData.get('arquivo');
  const altText = String(formData.get('textoAlternativo') ?? '').trim();
  if (!(file instanceof File)) {
    return NextResponse.json({ error: 'file_required' }, { status: 422 });
  }

  const rule = allowedFiles[file.type];
  const extension = file.name.toLowerCase().split('.').pop() ?? '';
  if (
    !rule ||
    !rule.extensions.includes(extension) ||
    file.size <= 0 ||
    file.size > MAX_FILE_SIZE
  ) {
    return NextResponse.json({ error: 'file_type_or_size_not_allowed' }, { status: 422 });
  }
  if (file.type.startsWith('image/') && altText.length < 2) {
    return NextResponse.json({ error: 'image_alt_text_required' }, { status: 422 });
  }

  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: 'authentication_required' }, { status: 401 });

  const assetId = crypto.randomUUID();
  const objectPath = `${user.id}/${contentId}/${assetId}.${extension}`;
  const upload = await supabase.storage.from('content-drafts').upload(objectPath, file, {
    contentType: file.type,
    upsert: false,
  });
  if (upload.error) {
    return NextResponse.json({ error: 'private_upload_failed' }, { status: 400 });
  }

  const registered = await supabase.rpc('register_own_draft_asset', {
    requested_asset_id: assetId,
    requested_content_id: contentId,
    requested_object_path: objectPath,
    requested_purpose: rule.purpose,
    requested_mime_type: file.type,
    requested_byte_size: file.size,
    requested_title: file.name,
    requested_alt_text: altText,
  });
  if (registered.error) {
    await supabase.storage.from('content-drafts').remove([objectPath]);
    return NextResponse.json({ error: registered.error.message }, { status: 400 });
  }
  return NextResponse.json(registered.data, { status: 201 });
}
