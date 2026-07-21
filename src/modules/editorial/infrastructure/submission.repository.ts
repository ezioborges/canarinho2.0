import 'server-only';

import { notFound } from 'next/navigation';

import { createSupabaseServerClient } from '@/shared/lib/supabase/server';

import { slugForDraft } from '../domain/submission';
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
