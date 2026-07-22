import 'server-only';

import { notFound } from 'next/navigation';

import { getAuthenticatedSession } from '@/modules/identity-access';
import { createSupabaseServerClient } from '@/shared/lib/supabase/server';

export type PublicNotice = {
  id: string;
  title: string;
  slug: string;
  summary: string;
  body: string;
  audience: string;
  comments_enabled: boolean;
  pinned: boolean;
  published_at: string;
  expires_at: string | null;
};

export type NoticeComment = { id: string; body: string; created_at: string };

export type CommunicationsAdmin = {
  notices: Array<PublicNotice & { status: string }>;
  subscribers: Array<{
    id: string;
    email: string;
    status: string;
    segment: string;
    consent_version: string;
    consented_at: string;
  }>;
  campaigns: Array<{
    id: string;
    name: string;
    subject: string;
    preview_text: string | null;
    body_text: string;
    segment: string;
    status: string;
    scheduled_at: string | null;
    sent_at: string | null;
    newsletter_deliveries: Array<{ status: string }>;
  }>;
  exports: Array<{
    id: string;
    status: string;
    row_count: number | null;
    expires_at: string | null;
    created_at: string;
  }>;
  isDirector: boolean;
};

export type UserNotification = {
  id: string;
  title: string;
  body: string;
  href: string | null;
  read_at: string | null;
  created_at: string;
};

export async function listPublicNotices(): Promise<PublicNotice[]> {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase
    .from('communication_notices')
    .select('id,title,slug,summary,body,audience,comments_enabled,pinned,published_at,expires_at')
    .eq('status', 'published')
    .order('pinned', { ascending: false })
    .order('published_at', { ascending: false });
  if (error) throw new Error(`public_notices_failed:${error.code}`);
  return (data ?? []).map((notice) => ({
    ...notice,
    pinned: notice.pinned && (!notice.expires_at || new Date(notice.expires_at) > new Date()),
  })) as PublicNotice[];
}

export async function getPublicNotice(
  slug: string,
): Promise<{ notice: PublicNotice; comments: NoticeComment[] } | null> {
  const supabase = await createSupabaseServerClient();
  const { data: notice, error } = await supabase
    .from('communication_notices')
    .select('id,title,slug,summary,body,audience,comments_enabled,pinned,published_at,expires_at')
    .eq('slug', slug)
    .eq('status', 'published')
    .maybeSingle();
  if (error) throw new Error(`public_notice_failed:${error.code}`);
  if (!notice) return null;
  const { data: comments, error: commentsError } = await supabase
    .from('notice_comments')
    .select('id,body,created_at')
    .eq('notice_id', notice.id)
    .order('created_at', { ascending: false });
  if (commentsError) throw new Error(`notice_comments_failed:${commentsError.code}`);
  return { notice: notice as PublicNotice, comments: (comments ?? []) as NoticeComment[] };
}

export async function getCommunicationsAdmin(): Promise<CommunicationsAdmin> {
  const session = await getAuthenticatedSession('/admin/comunicacoes');
  if (!session.roles.some((role) => role === 'conexoes' || role === 'diretor')) notFound();
  const supabase = await createSupabaseServerClient();
  const [notices, subscribers, campaigns, exports] = await Promise.all([
    supabase
      .from('communication_notices')
      .select(
        'id,title,slug,summary,body,audience,comments_enabled,pinned,published_at,expires_at,status',
      )
      .order('created_at', { ascending: false }),
    supabase
      .from('newsletter_subscribers')
      .select('id,email,status,segment,consent_version,consented_at')
      .order('created_at', { ascending: false })
      .limit(200),
    supabase
      .from('newsletter_campaigns')
      .select(
        'id,name,subject,preview_text,body_text,segment,status,scheduled_at,sent_at,newsletter_deliveries(status)',
      )
      .order('created_at', { ascending: false }),
    supabase
      .from('newsletter_exports')
      .select('id,status,row_count,expires_at,created_at')
      .order('created_at', { ascending: false }),
  ]);
  if (notices.error || subscribers.error || campaigns.error || exports.error) {
    throw new Error('communications_admin_failed');
  }
  return {
    notices: (notices.data ?? []) as CommunicationsAdmin['notices'],
    subscribers: (subscribers.data ?? []) as CommunicationsAdmin['subscribers'],
    campaigns: (campaigns.data ?? []) as CommunicationsAdmin['campaigns'],
    exports: (exports.data ?? []) as CommunicationsAdmin['exports'],
    isDirector: session.roles.includes('diretor'),
  };
}

export async function listOwnNotifications(): Promise<UserNotification[]> {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) notFound();
  const { data, error } = await supabase
    .from('user_notifications')
    .select('id,title,body,href,read_at,created_at')
    .order('created_at', { ascending: false })
    .limit(100);
  if (error) throw new Error(`notifications_failed:${error.code}`);
  return (data ?? []) as UserNotification[];
}
