import 'server-only';

import { createSupabaseServerClient } from '@/shared/lib/supabase/server';

import type { PublicContentCard } from '@/modules/public-portal';

export type PublicComment = {
  id: string;
  body: string;
  authorName: string;
  createdAt: string;
};

export type CommentCursor = { createdAt: string; id: string };

export type ContentCommunity = {
  comments: PublicComment[];
  hasMore: boolean;
  authenticated: boolean;
  favorite: boolean;
};

export type ModerationQueueItem = {
  id: string;
  body: string;
  status: 'visible' | 'hidden' | 'removed';
  created_at: string;
  author_id: string;
  content_id: string;
  moderation_reason: string | null;
  comment_reports: { id: string; reason: string; created_at: string; status: string }[];
};

export async function getContentCommunity(
  contentId: string,
  cursor?: CommentCursor,
): Promise<ContentCommunity> {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  const [commentsResult, favoriteResult] = await Promise.all([
    supabase.rpc('list_public_comments', {
      requested_content_id: contentId,
      before_created_at: cursor?.createdAt ?? null,
      before_id: cursor?.id ?? null,
      page_size: 20,
    }),
    user
      ? supabase
          .from('content_favorites')
          .select('content_id')
          .eq('user_id', user.id)
          .eq('content_id', contentId)
          .maybeSingle()
      : Promise.resolve({ data: null, error: null }),
  ]);
  if (commentsResult.error) throw new Error(`public_comments_failed:${commentsResult.error.code}`);
  const payload = (commentsResult.data ?? { items: [], hasMore: false }) as {
    items: PublicComment[];
    hasMore: boolean;
  };
  return {
    comments: payload.items,
    hasMore: payload.hasMore,
    authenticated: Boolean(user),
    favorite: Boolean(favoriteResult.data),
  };
}

export async function listOwnFavorites(): Promise<PublicContentCard[]> {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.rpc('list_own_favorites');
  if (error) throw new Error(`favorites_failed:${error.code}`);
  return (data ?? []) as PublicContentCard[];
}

export async function listModerationQueue(): Promise<ModerationQueueItem[]> {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase
    .from('public_comments')
    .select(
      'id,body,status,created_at,author_id,content_id,moderation_reason,comment_reports(id,reason,created_at,status)',
    )
    .order('created_at', { ascending: false })
    .limit(100);
  if (error) throw new Error(`moderation_queue_failed:${error.code}`);
  return (data ?? []) as ModerationQueueItem[];
}
