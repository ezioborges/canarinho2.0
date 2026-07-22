'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import type { Route } from 'next';

import { createSupabaseServerClient } from '@/shared/lib/supabase/server';

import {
  editorialCommentSchema,
  editorialSaveSchema,
  editorialTransitionSchema,
  restoreVersionSchema,
} from '../schemas/workflow';

type EditorialArea = 'revisao' | 'editorial';

function field(formData: FormData, name: string): string {
  const value = formData.get(name);
  return typeof value === 'string' ? value : '';
}

function areaFrom(formData: FormData): EditorialArea {
  return field(formData, 'area') === 'revisao' ? 'revisao' : 'editorial';
}

function resultPath(
  area: EditorialArea,
  contentId: string,
  key: 'sucesso' | 'erro',
  value: string,
): Route {
  return `/admin/${area}/${contentId}?${key}=${encodeURIComponent(value)}` as Route;
}

function safeError(message: string): string {
  const known = [
    'stale_content_version',
    'reviewer_cannot_approve_own_content',
    'content_missing_publication_requirements',
    'editorial_transition_not_allowed',
    'editor_is_not_responsible',
    'content_not_editable_by_editor',
    'future_schedule_required',
    'restoration_requires_editing_state',
  ];
  return known.find((code) => message.includes(code)) ?? 'operacao_nao_concluida';
}

function refreshEditorial(contentId: string) {
  revalidatePath('/admin/revisao');
  revalidatePath('/admin/editorial');
  revalidatePath(`/admin/revisao/${contentId}`);
  revalidatePath(`/admin/editorial/${contentId}`);
  revalidatePath('/materias');
  revalidatePath('/');
}

export async function assignReviewerAction(formData: FormData) {
  const area = areaFrom(formData);
  const contentId = field(formData, 'contentId');
  const reviewerId = field(formData, 'reviewerId');
  const lockVersion = Number(field(formData, 'lockVersion'));
  const justification = field(formData, 'justification');
  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.rpc('assign_editorial_reviewer', {
    requested_content_id: contentId,
    requested_reviewer_id: reviewerId,
    expected_lock_version: lockVersion,
    justification,
  });
  if (error) redirect(resultPath(area, contentId, 'erro', safeError(error.message)));
  refreshEditorial(contentId);
  redirect(resultPath(area, contentId, 'sucesso', 'revisao_atribuida'));
}

export async function addEditorialCommentAction(formData: FormData) {
  const area = areaFrom(formData);
  const parsed = editorialCommentSchema.safeParse({
    contentId: field(formData, 'contentId'),
    versionId: field(formData, 'versionId'),
    body: field(formData, 'body'),
  });
  if (!parsed.success) {
    redirect(resultPath(area, field(formData, 'contentId'), 'erro', 'comentario_invalido'));
  }
  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.rpc('add_editorial_comment', {
    requested_content_id: parsed.data.contentId,
    requested_version_id: parsed.data.versionId,
    requested_body: parsed.data.body,
  });
  if (error) {
    redirect(resultPath(area, parsed.data.contentId, 'erro', safeError(error.message)));
  }
  refreshEditorial(parsed.data.contentId);
  redirect(resultPath(area, parsed.data.contentId, 'sucesso', 'comentario_adicionado'));
}

export async function transitionEditorialAction(formData: FormData) {
  const area = areaFrom(formData);
  const contentId = field(formData, 'contentId');
  const rawSchedule = field(formData, 'schedule');
  const schedule = rawSchedule ? new Date(rawSchedule).toISOString() : undefined;
  const parsed = editorialTransitionSchema.safeParse({
    contentId,
    lockVersion: field(formData, 'lockVersion'),
    status: field(formData, 'status'),
    justification: field(formData, 'justification'),
    schedule,
    directorException: field(formData, 'directorException') === 'true',
  });
  if (!parsed.success) redirect(resultPath(area, contentId, 'erro', 'transicao_invalida'));

  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.rpc('transition_editorial_content', {
    requested_content_id: parsed.data.contentId,
    requested_status: parsed.data.status,
    expected_lock_version: parsed.data.lockVersion,
    justification: parsed.data.justification,
    requested_schedule: parsed.data.schedule ?? null,
    director_exception: parsed.data.directorException,
  });
  if (error) {
    redirect(resultPath(area, parsed.data.contentId, 'erro', safeError(error.message)));
  }
  refreshEditorial(parsed.data.contentId);
  if (area === 'revisao' && ['approved', 'rejected'].includes(parsed.data.status)) {
    redirect('/admin/revisao?sucesso=status_atualizado');
  }
  redirect(resultPath(area, parsed.data.contentId, 'sucesso', 'status_atualizado'));
}

export async function saveEditorialContentAction(formData: FormData) {
  const contentId = field(formData, 'contentId');
  let body: Record<string, unknown> = {};
  try {
    body = JSON.parse(field(formData, 'body')) as Record<string, unknown>;
  } catch {
    redirect(resultPath('editorial', contentId, 'erro', 'conteudo_invalido'));
  }
  const parsed = editorialSaveSchema.safeParse({
    contentId,
    lockVersion: field(formData, 'lockVersion'),
    title: field(formData, 'title'),
    subtitle: field(formData, 'subtitle'),
    summary: field(formData, 'summary'),
    body,
    primaryCategoryId: field(formData, 'primaryCategoryId') || null,
    tagIds: formData.getAll('tagIds').filter((value): value is string => typeof value === 'string'),
    coverAssetId: field(formData, 'coverAssetId') || null,
    seoTitle: field(formData, 'seoTitle'),
    seoDescription: field(formData, 'seoDescription'),
    readingTimeMinutes: field(formData, 'readingTimeMinutes'),
    justification: field(formData, 'justification'),
  });
  if (!parsed.success) {
    redirect(resultPath('editorial', contentId, 'erro', 'edicao_invalida'));
  }

  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.rpc('save_editorial_content', {
    requested_content_id: parsed.data.contentId,
    expected_lock_version: parsed.data.lockVersion,
    requested_title: parsed.data.title,
    requested_subtitle: parsed.data.subtitle,
    requested_summary: parsed.data.summary,
    requested_body: parsed.data.body,
    requested_primary_category_id: parsed.data.primaryCategoryId,
    requested_tag_ids: parsed.data.tagIds,
    requested_cover_asset_id: parsed.data.coverAssetId,
    requested_seo_title: parsed.data.seoTitle,
    requested_seo_description: parsed.data.seoDescription,
    requested_reading_time_minutes: parsed.data.readingTimeMinutes,
    justification: parsed.data.justification,
  });
  if (error) redirect(resultPath('editorial', contentId, 'erro', safeError(error.message)));
  refreshEditorial(contentId);
  redirect(resultPath('editorial', contentId, 'sucesso', 'edicao_salva'));
}

export async function restoreEditorialVersionAction(formData: FormData) {
  const contentId = field(formData, 'contentId');
  const parsed = restoreVersionSchema.safeParse({
    contentId,
    versionId: field(formData, 'versionId'),
    lockVersion: field(formData, 'lockVersion'),
    justification: field(formData, 'justification'),
  });
  if (!parsed.success) {
    redirect(resultPath('editorial', contentId, 'erro', 'restauracao_invalida'));
  }
  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.rpc('restore_editorial_version', {
    requested_content_id: parsed.data.contentId,
    requested_version_id: parsed.data.versionId,
    expected_lock_version: parsed.data.lockVersion,
    justification: parsed.data.justification,
  });
  if (error) redirect(resultPath('editorial', contentId, 'erro', safeError(error.message)));
  refreshEditorial(contentId);
  redirect(resultPath('editorial', contentId, 'sucesso', 'versao_restaurada'));
}

export async function setPrimaryHeroAction(formData: FormData) {
  const contentId = field(formData, 'contentId');
  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.rpc('set_primary_hero', {
    requested_content_id: contentId,
    justification: field(formData, 'justification'),
  });
  if (error) redirect(resultPath('editorial', contentId, 'erro', safeError(error.message)));
  refreshEditorial(contentId);
  redirect(resultPath('editorial', contentId, 'sucesso', 'destaque_atualizado'));
}
