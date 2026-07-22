'use server';

import type { Route } from 'next';
import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';

import { createSupabaseServerClient } from '@/shared/lib/supabase/server';

import {
  favoriteSchema,
  moderationSchema,
  publicCommentSchema,
  reportCommentSchema,
} from '../schemas/community';

function contentRedirect(slug: string, kind: 'erro' | 'sucesso', message: string): never {
  const query = new URLSearchParams({ [kind]: message });
  redirect(`/materias/${slug}?${query.toString()}#comentarios` as Route);
}

export async function addPublicCommentAction(formData: FormData): Promise<never> {
  const parsed = publicCommentSchema.safeParse({
    contentId: formData.get('contentId'),
    slug: formData.get('slug'),
    body: formData.get('body'),
    idempotencyKey: formData.get('idempotencyKey'),
  });
  if (!parsed.success) {
    const slug = String(formData.get('slug') ?? '');
    contentRedirect(slug, 'erro', parsed.error.issues[0]?.message ?? 'Comentário inválido.');
  }
  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.rpc('add_public_comment', {
    requested_content_id: parsed.data.contentId,
    requested_body: parsed.data.body,
    requested_idempotency_key: parsed.data.idempotencyKey,
  });
  if (error) {
    const message = error.message.includes('rate_limit')
      ? 'Você comentou muitas vezes. Aguarde alguns minutos.'
      : 'Não foi possível publicar o comentário.';
    contentRedirect(parsed.data.slug, 'erro', message);
  }
  revalidatePath(`/materias/${parsed.data.slug}`);
  contentRedirect(parsed.data.slug, 'sucesso', 'Comentário publicado.');
}

export async function reportCommentAction(formData: FormData): Promise<never> {
  const parsed = reportCommentSchema.safeParse({
    commentId: formData.get('commentId'),
    slug: formData.get('slug'),
    reason: formData.get('reason'),
  });
  if (!parsed.success) redirect('/materias' as Route);
  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.rpc('report_public_comment', {
    requested_comment_id: parsed.data.commentId,
    requested_reason: parsed.data.reason,
  });
  if (error) contentRedirect(parsed.data.slug, 'erro', 'Não foi possível enviar a denúncia.');
  contentRedirect(parsed.data.slug, 'sucesso', 'Denúncia enviada à moderação.');
}

export async function setFavoriteAction(formData: FormData): Promise<never> {
  const parsed = favoriteSchema.safeParse({
    contentId: formData.get('contentId'),
    slug: formData.get('slug'),
    favorite: formData.get('favorite'),
  });
  if (!parsed.success) redirect('/materias' as Route);
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect(`/entrar?retorno=/materias/${parsed.data.slug}` as Route);
  const { error } = await supabase.rpc('set_content_favorite', {
    requested_content_id: parsed.data.contentId,
    requested_favorite: parsed.data.favorite,
  });
  if (error) contentRedirect(parsed.data.slug, 'erro', 'Não foi possível atualizar o favorito.');
  revalidatePath(`/materias/${parsed.data.slug}`);
  revalidatePath('/favoritos');
  contentRedirect(
    parsed.data.slug,
    'sucesso',
    parsed.data.favorite ? 'Conteúdo salvo nos favoritos.' : 'Conteúdo removido dos favoritos.',
  );
}

export async function moderateCommentAction(formData: FormData): Promise<never> {
  const parsed = moderationSchema.safeParse({
    commentId: formData.get('commentId'),
    action: formData.get('action'),
    reason: formData.get('reason'),
  });
  if (!parsed.success) redirect('/admin/comunidade?erro=Revise+os+dados.' as Route);
  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.rpc('moderate_public_comment', {
    requested_comment_id: parsed.data.commentId,
    requested_action: parsed.data.action,
    requested_reason: parsed.data.reason,
  });
  if (error) redirect('/admin/comunidade?erro=Moderacao+nao+concluida.' as Route);
  revalidatePath('/admin/comunidade');
  redirect('/admin/comunidade?sucesso=Moderacao+registrada.' as Route);
}
