'use server';

import type { Route } from 'next';
import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';

import { createSupabaseServerClient } from '@/shared/lib/supabase/server';

import {
  applicationReviewSchema,
  archiveMemberSchema,
  recruitmentApplicationSchema,
  teamMemberSchema,
} from '../schemas/organization';

function adminRedirect(kind: 'erro' | 'sucesso', message: string): never {
  redirect(`/admin/organizacao?${new URLSearchParams({ [kind]: message })}` as Route);
}

export async function saveTeamMemberAction(formData: FormData): Promise<never> {
  const parsed = teamMemberSchema.safeParse({
    memberId: formData.get('memberId') ?? '',
    areaId: formData.get('areaId'),
    name: formData.get('name'),
    roleTitle: formData.get('roleTitle'),
    bio: formData.get('bio') ?? '',
    publicContact: formData.get('publicContact') ?? '',
    position: formData.get('position'),
  });
  if (!parsed.success) adminRedirect('erro', 'Revise os dados do membro.');
  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.rpc('save_team_member', {
    requested_member_id: parsed.data.memberId,
    requested_area_id: parsed.data.areaId,
    requested_name: parsed.data.name,
    requested_role_title: parsed.data.roleTitle,
    requested_bio: parsed.data.bio,
    requested_public_contact: parsed.data.publicContact,
    requested_position: parsed.data.position,
  });
  if (error) adminRedirect('erro', 'Não foi possível salvar o membro.');
  revalidatePath('/equipe');
  revalidatePath('/admin/organizacao');
  adminRedirect('sucesso', 'Membro da equipe salvo.');
}

export async function archiveTeamMemberAction(formData: FormData): Promise<never> {
  const parsed = archiveMemberSchema.safeParse({
    memberId: formData.get('memberId'),
    reason: formData.get('reason'),
  });
  if (!parsed.success) adminRedirect('erro', 'Informe o motivo do arquivamento.');
  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.rpc('archive_team_member', {
    requested_member_id: parsed.data.memberId,
    requested_reason: parsed.data.reason,
  });
  if (error) adminRedirect('erro', 'Não foi possível arquivar o membro.');
  revalidatePath('/equipe');
  revalidatePath('/admin/organizacao');
  adminRedirect('sucesso', 'Membro arquivado com auditoria.');
}

export async function submitRecruitmentApplicationAction(formData: FormData): Promise<never> {
  const parsed = recruitmentApplicationSchema.safeParse({
    openingId: formData.get('openingId'),
    name: formData.get('name'),
    email: formData.get('email'),
    affiliation: formData.get('affiliation'),
    message: formData.get('message'),
    consent: formData.get('consent'),
    website: formData.get('website') ?? '',
  });
  if (!parsed.success) redirect('/faca-parte?erro=Revise+os+dados+da+candidatura.' as Route);
  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.rpc('submit_recruitment_application', {
    requested_opening_id: parsed.data.openingId,
    requested_name: parsed.data.name,
    requested_email: parsed.data.email,
    requested_affiliation: parsed.data.affiliation,
    requested_message: parsed.data.message,
    requested_consent_version: 'recrutamento-2026-01',
    anti_spam_field: parsed.data.website,
  });
  if (error) {
    redirect('/faca-parte?erro=Nao+foi+possivel+enviar+a+candidatura.' as Route);
  }
  redirect('/faca-parte?sucesso=Candidatura+recebida.+Entraremos+em+contato.' as Route);
}

export async function updateRecruitmentApplicationAction(formData: FormData): Promise<never> {
  const parsed = applicationReviewSchema.safeParse({
    applicationId: formData.get('applicationId'),
    status: formData.get('status'),
    note: formData.get('note'),
  });
  if (!parsed.success) adminRedirect('erro', 'Revise o parecer da candidatura.');
  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.rpc('update_recruitment_application', {
    requested_application_id: parsed.data.applicationId,
    requested_status: parsed.data.status,
    requested_note: parsed.data.note,
  });
  if (error) adminRedirect('erro', 'Não foi possível atualizar a candidatura.');
  revalidatePath('/admin/organizacao');
  adminRedirect('sucesso', 'Candidatura atualizada com auditoria.');
}
