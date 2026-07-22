import 'server-only';

import type { Route } from 'next';
import { notFound, redirect } from 'next/navigation';

import { createSupabaseServerClient } from '@/shared/lib/supabase/server';

import { editorialStatuses, slugForDraft } from '../domain/submission';
import { editorQueueStatuses, reviewQueueStatuses, type EditorialRole } from '../domain/workflow';
import type { DraftInput } from '../schemas/draft';

export type SubmissionListItem = {
  id: string;
  title: string;
  type: string;
  status: string;
  lock_version: number;
  updated_at: string;
  submitted_at: string | null;
};

export type SubmissionWorkspace = {
  profile: { id: string; display_name: string };
  categories: { id: string; name: string }[];
  tags: { id: string; name: string }[];
  terms: { version: string; title: string; body: string } | null;
};

export type SubmissionDetail = {
  content: Record<string, unknown> & {
    id: string;
    title: string;
    type: string;
    status: string;
    slug: string;
    body: Record<string, unknown>;
    lock_version: number;
    subtitle: string | null;
    summary: string | null;
    submission_notes: string | null;
  };
  authors: { position: number; profile_id: string | null; display_name: string | null }[];
  categories: { category_id: string; is_primary: boolean }[];
  tags: { tag_id: string }[];
  assets: {
    id: string;
    title: string | null;
    object_path: string;
    mime_type: string;
    byte_size: number;
  }[];
  history: {
    id: number;
    from_status: string;
    to_status: string;
    reason: string;
    created_at: string;
  }[];
  comments: {
    id: string;
    version_id: string;
    body: string;
    created_at: string;
  }[];
};

export type EditorialSession = {
  userId: string;
  displayName: string;
  roles: EditorialRole[];
};

export type EditorialQueueItem = {
  id: string;
  title: string;
  type: string;
  status: string;
  lock_version: number;
  submitted_at: string | null;
  scheduled_at: string | null;
  updated_at: string;
  reviewer_id: string | null;
  editor_id: string | null;
};

type VersionSnapshot = {
  content?: Record<string, unknown>;
  authors?: Record<string, unknown>[];
  categories?: Record<string, unknown>[];
  tags?: Record<string, unknown>[];
};

export type EditorialDetail = {
  session: EditorialSession;
  content: Record<string, unknown> & {
    id: string;
    title: string;
    type: string;
    status: string;
    slug: string;
    subtitle: string | null;
    summary: string | null;
    body: Record<string, unknown>;
    lock_version: number;
    reviewer_id: string | null;
    editor_id: string | null;
    cover_asset_id: string | null;
    seo_title: string | null;
    seo_description: string | null;
    reading_time_minutes: number | null;
    scheduled_at: string | null;
    published_at: string | null;
  };
  authors: { position: number; profile_id: string | null; display_name: string | null }[];
  categories: { id: string; name: string }[];
  selectedCategoryId: string | null;
  tags: { id: string; name: string }[];
  selectedTagIds: string[];
  covers: { id: string; title: string | null; alt_text: string | null }[];
  versions: {
    id: string;
    version_number: number;
    reason: string;
    snapshot: VersionSnapshot;
    created_at: string;
    actor_kind: 'user' | 'system';
    actor_label: string | null;
  }[];
  comments: {
    id: string;
    version_id: string;
    author_id: string;
    body: string;
    created_at: string;
  }[];
  history: {
    id: number;
    from_status: string;
    to_status: string;
    reason: string;
    created_at: string;
    actor_kind: 'user' | 'system';
    actor_label: string | null;
  }[];
  reviewers: { id: string; display_name: string }[];
};

export async function listOwnSubmissions(): Promise<SubmissionListItem[]> {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return [];
  const { data, error } = await supabase
    .from('content_items')
    .select('id,title,type,status,lock_version,updated_at,submitted_at')
    .eq('submitted_by', user.id)
    .is('deleted_at', null)
    .order('updated_at', { ascending: false });
  if (error) throw new Error(`own_submissions_failed:${error.code}`);
  return (data ?? []) as SubmissionListItem[];
}

export async function getSubmissionWorkspace(): Promise<SubmissionWorkspace> {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error('authentication_required');

  const [profileResult, categoriesResult, tagsResult, termsResult] = await Promise.all([
    supabase.from('profiles').select('id,display_name').eq('id', user.id).single(),
    supabase.from('categories').select('id,name').is('archived_at', null).order('name'),
    supabase.from('tags').select('id,name').is('archived_at', null).order('name'),
    supabase
      .from('submission_terms')
      .select('version,title,body')
      .is('retired_at', null)
      .lte('published_at', new Date().toISOString())
      .order('published_at', { ascending: false })
      .limit(1)
      .maybeSingle(),
  ]);
  if (profileResult.error || categoriesResult.error || tagsResult.error || termsResult.error) {
    throw new Error('submission_workspace_failed');
  }
  return {
    profile: profileResult.data as SubmissionWorkspace['profile'],
    categories: (categoriesResult.data ?? []) as SubmissionWorkspace['categories'],
    tags: (tagsResult.data ?? []) as SubmissionWorkspace['tags'],
    terms: termsResult.data as SubmissionWorkspace['terms'],
  };
}

export async function getOwnSubmission(contentId: string): Promise<SubmissionDetail> {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.rpc('get_own_submission', {
    requested_content_id: contentId,
  });
  if (error || !data) notFound();
  return data as SubmissionDetail;
}

export async function saveOwnDraft(input: DraftInput) {
  const supabase = await createSupabaseServerClient();
  return supabase.rpc('save_own_content_draft', {
    requested_content_id: input.contentId,
    expected_lock_version: input.lockVersion,
    idempotency_key: input.idempotencyKey,
    requested_slug: slugForDraft(input.title, input.contentId),
    requested_type: input.type,
    requested_title: input.title,
    requested_subtitle: input.subtitle,
    requested_summary: input.summary,
    requested_body: input.body,
    requested_authors: input.authors,
    requested_primary_category_id: input.primaryCategoryId,
    requested_tag_ids: input.tagIds,
    requested_notes: input.notes,
  });
}

export async function getEditorialSession(returnPath = '/admin'): Promise<EditorialSession> {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect(`/entrar?retorno=${encodeURIComponent(returnPath)}` as Route);

  const [profileResult, rolesResult] = await Promise.all([
    supabase.from('profiles').select('display_name').eq('id', user.id).single(),
    supabase.from('user_roles').select('role_code').eq('user_id', user.id),
  ]);
  if (profileResult.error || rolesResult.error) throw new Error('editorial_session_failed');

  const roles = (rolesResult.data ?? [])
    .map((entry) => entry.role_code)
    .filter((role): role is EditorialRole => ['revisor', 'editor', 'diretor'].includes(role));
  if (!roles.length) notFound();

  return {
    userId: user.id,
    displayName: profileResult.data.display_name,
    roles,
  };
}

async function listEditorialQueue(statuses: readonly string[]): Promise<EditorialQueueItem[]> {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase
    .from('content_items')
    .select(
      'id,title,type,status,lock_version,submitted_at,scheduled_at,updated_at,reviewer_id,editor_id',
    )
    .in('status', [...statuses])
    .is('deleted_at', null)
    .order('updated_at', { ascending: true });
  if (error) throw new Error(`editorial_queue_failed:${error.code}`);
  return (data ?? []) as EditorialQueueItem[];
}

export async function listReviewQueue(): Promise<EditorialQueueItem[]> {
  const session = await getEditorialSession('/admin/revisao');
  return listEditorialQueue(
    session.roles.includes('diretor') ? [...reviewQueueStatuses, 'rejected'] : reviewQueueStatuses,
  );
}

export async function listEditorQueue(): Promise<EditorialQueueItem[]> {
  const session = await getEditorialSession('/admin/editorial');
  return listEditorialQueue(
    session.roles.includes('diretor') ? editorialStatuses : editorQueueStatuses,
  );
}

export async function getEditorialDetail(contentId: string): Promise<EditorialDetail> {
  const session = await getEditorialSession(`/admin/editorial/${contentId}`);
  const supabase = await createSupabaseServerClient();
  const contentResult = await supabase
    .from('content_items')
    .select('*')
    .eq('id', contentId)
    .is('deleted_at', null)
    .maybeSingle();
  if (contentResult.error || !contentResult.data) notFound();

  const [
    authorsResult,
    categoriesResult,
    selectedCategoriesResult,
    tagsResult,
    selectedTagsResult,
    coversResult,
    versionsResult,
    commentsResult,
    historyResult,
    reviewerRolesResult,
  ] = await Promise.all([
    supabase
      .from('content_authors')
      .select('position,profile_id,display_name')
      .eq('content_id', contentId)
      .order('position'),
    supabase.from('categories').select('id,name').is('archived_at', null).order('name'),
    supabase
      .from('content_categories')
      .select('category_id,is_primary')
      .eq('content_id', contentId),
    supabase.from('tags').select('id,name').is('archived_at', null).order('name'),
    supabase.from('content_tags').select('tag_id').eq('content_id', contentId),
    supabase
      .from('media_assets')
      .select('id,title,alt_text')
      .eq('bucket_id', 'content-public')
      .eq('purpose', 'cover')
      .is('archived_at', null)
      .order('created_at', { ascending: false }),
    supabase
      .from('content_versions')
      .select('id,version_number,reason,snapshot,created_at,actor_kind,actor_label')
      .eq('content_id', contentId)
      .order('version_number', { ascending: false }),
    supabase
      .from('editorial_comments')
      .select('id,version_id,author_id,body,created_at')
      .eq('content_id', contentId)
      .order('created_at'),
    supabase
      .from('editorial_status_history')
      .select('id,from_status,to_status,reason,created_at,actor_kind,actor_label')
      .eq('content_id', contentId)
      .order('created_at', { ascending: false }),
    session.roles.includes('diretor')
      ? supabase.from('user_roles').select('user_id').in('role_code', ['revisor', 'diretor'])
      : Promise.resolve({ data: [{ user_id: session.userId }], error: null }),
  ]);

  const results = [
    authorsResult,
    categoriesResult,
    selectedCategoriesResult,
    tagsResult,
    selectedTagsResult,
    coversResult,
    versionsResult,
    commentsResult,
    historyResult,
    reviewerRolesResult,
  ];
  if (results.some((result) => result.error)) throw new Error('editorial_detail_failed');

  const reviewerIds = [...new Set((reviewerRolesResult.data ?? []).map((entry) => entry.user_id))];
  const reviewerProfilesResult = reviewerIds.length
    ? await supabase
        .from('profiles')
        .select('id,display_name')
        .in('id', reviewerIds)
        .order('display_name')
    : { data: [], error: null };
  if (reviewerProfilesResult.error) throw new Error('editorial_reviewers_failed');

  return {
    session,
    content: contentResult.data as EditorialDetail['content'],
    authors: (authorsResult.data ?? []) as EditorialDetail['authors'],
    categories: (categoriesResult.data ?? []) as EditorialDetail['categories'],
    selectedCategoryId:
      selectedCategoriesResult.data?.find((entry) => entry.is_primary)?.category_id ?? null,
    tags: (tagsResult.data ?? []) as EditorialDetail['tags'],
    selectedTagIds: (selectedTagsResult.data ?? []).map((entry) => entry.tag_id),
    covers: (coversResult.data ?? []) as EditorialDetail['covers'],
    versions: (versionsResult.data ?? []) as EditorialDetail['versions'],
    comments: (commentsResult.data ?? []) as EditorialDetail['comments'],
    history: (historyResult.data ?? []) as EditorialDetail['history'],
    reviewers: (reviewerProfilesResult.data ?? []) as EditorialDetail['reviewers'],
  };
}
