'use server';

import type { Route } from 'next';
import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';

import { createSupabaseServerClient } from '@/shared/lib/supabase/server';

import {
  campaignCommandSchema,
  campaignScheduleSchema,
  campaignSchema,
  exportRequestSchema,
  newsletterSubscriptionSchema,
  noticeCommentSchema,
  noticePinSchema,
  noticeSchema,
  noticeStatusSchema,
  subscriberCommandSchema,
} from '../schemas/communications';

function adminRedirect(kind: 'erro' | 'sucesso', message: string): never {
  redirect(`/admin/comunicacoes?${new URLSearchParams({ [kind]: message })}` as Route);
}

export async function subscribeNewsletterAction(formData: FormData): Promise<never> {
  const parsed = newsletterSubscriptionSchema.safeParse({
    email: formData.get('email'),
    consent: formData.get('consent'),
    website: formData.get('website') ?? '',
    returnPath: formData.get('returnPath') ?? '/',
  });
  const returnPath = formData.get('returnPath') === '/informes' ? '/informes' : '/';
  if (!parsed.success) {
    redirect(`${returnPath}?newsletter=Revise+o+email+e+o+consentimento.` as Route);
  }
  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.rpc('subscribe_newsletter', {
    requested_email: parsed.data.email,
    requested_consent_version: 'newsletter-2026-01',
    requested_source: parsed.data.returnPath === '/' ? 'home' : 'informes',
    anti_spam_field: parsed.data.website,
  });
  if (error) {
    redirect(`${returnPath}?newsletter=Nao+foi+possivel+registrar+o+email.` as Route);
  }
  redirect(`${returnPath}?newsletter=Confira+seu+email+para+confirmar+a+inscricao.` as Route);
}

export async function saveNoticeAction(formData: FormData): Promise<never> {
  const parsed = noticeSchema.safeParse({
    noticeId: formData.get('noticeId') ?? '',
    title: formData.get('title'),
    slug: formData.get('slug'),
    summary: formData.get('summary'),
    body: formData.get('body'),
    audience: formData.get('audience'),
    commentsEnabled: formData.get('commentsEnabled'),
    expiresAt: formData.get('expiresAt') ?? '',
  });
  if (!parsed.success) adminRedirect('erro', 'Revise os dados do informe.');
  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.rpc('save_communication_notice', {
    requested_notice_id: parsed.data.noticeId,
    requested_title: parsed.data.title,
    requested_slug: parsed.data.slug,
    requested_summary: parsed.data.summary,
    requested_body: parsed.data.body,
    requested_audience: parsed.data.audience,
    requested_comments_enabled: parsed.data.commentsEnabled,
    requested_expires_at: parsed.data.expiresAt,
  });
  if (error) adminRedirect('erro', 'Não foi possível salvar o informe.');
  revalidatePath('/informes');
  revalidatePath('/admin/comunicacoes');
  adminRedirect('sucesso', 'Informe salvo com auditoria.');
}

export async function changeNoticeStatusAction(formData: FormData): Promise<never> {
  const parsed = noticeStatusSchema.safeParse({
    noticeId: formData.get('noticeId'),
    action: formData.get('action'),
    reason: formData.get('reason'),
  });
  if (!parsed.success) adminRedirect('erro', 'Informe um motivo válido.');
  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.rpc('change_communication_notice_status', {
    requested_notice_id: parsed.data.noticeId,
    requested_action: parsed.data.action,
    requested_reason: parsed.data.reason,
  });
  if (error) adminRedirect('erro', 'Não foi possível alterar o estado do informe.');
  revalidatePath('/informes');
  revalidatePath('/admin/comunicacoes');
  adminRedirect('sucesso', 'Estado do informe atualizado.');
}

export async function setNoticePinnedAction(formData: FormData): Promise<never> {
  const parsed = noticePinSchema.safeParse({
    noticeId: formData.get('noticeId'),
    pinned: formData.get('pinned'),
    reason: formData.get('reason'),
  });
  if (!parsed.success) adminRedirect('erro', 'Revise a fixação do informe.');
  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.rpc('set_communication_notice_pinned', {
    requested_notice_id: parsed.data.noticeId,
    requested_pinned: parsed.data.pinned,
    requested_reason: parsed.data.reason,
  });
  if (error) adminRedirect('erro', 'Não foi possível alterar o destaque.');
  revalidatePath('/informes');
  revalidatePath('/admin/comunicacoes');
  adminRedirect('sucesso', 'Destaque do informe atualizado.');
}

export async function addNoticeCommentAction(formData: FormData): Promise<never> {
  const parsed = noticeCommentSchema.safeParse({
    noticeId: formData.get('noticeId'),
    slug: formData.get('slug'),
    body: formData.get('body'),
    idempotencyKey: formData.get('idempotencyKey'),
  });
  if (!parsed.success) redirect('/informes' as Route);
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect(`/entrar?retorno=/informes/${parsed.data.slug}` as Route);
  const { error } = await supabase.rpc('add_notice_comment', {
    requested_notice_id: parsed.data.noticeId,
    requested_body: parsed.data.body,
    requested_idempotency_key: parsed.data.idempotencyKey,
  });
  if (error) {
    redirect(`/informes/${parsed.data.slug}?erro=Comentario+nao+publicado.` as Route);
  }
  revalidatePath(`/informes/${parsed.data.slug}`);
  redirect(`/informes/${parsed.data.slug}?sucesso=Comentario+publicado.` as Route);
}

export async function saveCampaignAction(formData: FormData): Promise<never> {
  const parsed = campaignSchema.safeParse({
    campaignId: formData.get('campaignId') ?? '',
    name: formData.get('name'),
    subject: formData.get('subject'),
    previewText: formData.get('previewText') ?? '',
    bodyText: formData.get('bodyText'),
    segment: formData.get('segment'),
  });
  if (!parsed.success) adminRedirect('erro', 'Revise os dados da campanha.');
  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.rpc('save_newsletter_campaign', {
    requested_campaign_id: parsed.data.campaignId,
    requested_name: parsed.data.name,
    requested_subject: parsed.data.subject,
    requested_preview_text: parsed.data.previewText,
    requested_body_text: parsed.data.bodyText,
    requested_segment: parsed.data.segment,
  });
  if (error) adminRedirect('erro', 'Não foi possível salvar a campanha.');
  revalidatePath('/admin/comunicacoes');
  adminRedirect('sucesso', 'Campanha salva como rascunho.');
}

export async function scheduleCampaignAction(formData: FormData): Promise<never> {
  const parsed = campaignScheduleSchema.safeParse({
    campaignId: formData.get('campaignId'),
    scheduledAt: formData.get('scheduledAt'),
    reason: formData.get('reason'),
  });
  if (!parsed.success) adminRedirect('erro', 'Informe um horário futuro e um motivo.');
  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.rpc('schedule_newsletter_campaign', {
    requested_campaign_id: parsed.data.campaignId,
    requested_scheduled_at: parsed.data.scheduledAt,
    requested_reason: parsed.data.reason,
  });
  if (error) adminRedirect('erro', 'Não foi possível agendar a campanha.');
  revalidatePath('/admin/comunicacoes');
  adminRedirect('sucesso', 'Campanha agendada.');
}

async function campaignCommand(
  formData: FormData,
  rpc: 'cancel_newsletter_campaign' | 'retry_failed_newsletter_campaign',
  success: string,
): Promise<never> {
  const parsed = campaignCommandSchema.safeParse({
    campaignId: formData.get('campaignId'),
    reason: formData.get('reason'),
  });
  if (!parsed.success) adminRedirect('erro', 'Informe um motivo válido.');
  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.rpc(rpc, {
    requested_campaign_id: parsed.data.campaignId,
    requested_reason: parsed.data.reason,
  });
  if (error) adminRedirect('erro', 'A operação da campanha não foi concluída.');
  revalidatePath('/admin/comunicacoes');
  adminRedirect('sucesso', success);
}

export async function cancelCampaignAction(formData: FormData): Promise<never> {
  return campaignCommand(formData, 'cancel_newsletter_campaign', 'Campanha cancelada.');
}

export async function retryCampaignAction(formData: FormData): Promise<never> {
  return campaignCommand(
    formData,
    'retry_failed_newsletter_campaign',
    'Entregas elegíveis reenfileiradas.',
  );
}

export async function inactivateSubscriberAction(formData: FormData): Promise<never> {
  const parsed = subscriberCommandSchema.safeParse({
    subscriberId: formData.get('subscriberId'),
    reason: formData.get('reason'),
  });
  if (!parsed.success) adminRedirect('erro', 'Informe o motivo da inativação.');
  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.rpc('set_newsletter_subscriber_inactive', {
    requested_subscriber_id: parsed.data.subscriberId,
    requested_reason: parsed.data.reason,
  });
  if (error) adminRedirect('erro', 'Não foi possível inativar o inscrito.');
  revalidatePath('/admin/comunicacoes');
  adminRedirect('sucesso', 'Inscrito inativado e removido de lotes pendentes.');
}

export async function requestNewsletterExportAction(formData: FormData): Promise<never> {
  const parsed = exportRequestSchema.safeParse({ reason: formData.get('reason') });
  if (!parsed.success) adminRedirect('erro', 'Informe a finalidade da exportação.');
  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.rpc('request_newsletter_export', {
    requested_reason: parsed.data.reason,
  });
  if (error) adminRedirect('erro', 'Não foi possível solicitar a exportação.');
  revalidatePath('/admin/comunicacoes');
  adminRedirect('sucesso', 'Exportação protegida solicitada.');
}

export async function markNotificationReadAction(formData: FormData): Promise<never> {
  const notificationId = String(formData.get('notificationId') ?? '');
  const supabase = await createSupabaseServerClient();
  await supabase.rpc('mark_own_notification_read', {
    requested_notification_id: notificationId,
  });
  revalidatePath('/notificacoes');
  redirect('/notificacoes' as Route);
}
