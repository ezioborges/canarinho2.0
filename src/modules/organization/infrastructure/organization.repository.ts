import 'server-only';

import { notFound } from 'next/navigation';

import { getEditorialSession } from '@/modules/editorial';
import type { PublicCover } from '@/modules/public-portal';
import { createSupabaseServerClient } from '@/shared/lib/supabase/server';

export type PublicTeamMember = {
  id: string;
  name: string;
  roleTitle: string;
  bio: string | null;
  publicContact: string | null;
  photo: Pick<PublicCover, 'objectPath' | 'alt' | 'credit'> | null;
};

export type PublicTeamArea = {
  id: string;
  name: string;
  slug: string;
  description: string | null;
  members: PublicTeamMember[];
};

export type PublicOpening = {
  id: string;
  title: string;
  slug: string;
  summary: string;
  description: string;
  requirements: string;
  process: string;
  contact_email: string;
  applications_enabled: boolean;
  closes_at: string | null;
};

export type RecruitmentApplication = {
  id: string;
  applicant_name: string;
  email: string;
  affiliation: string;
  message: string;
  status: string;
  created_at: string;
  retention_expires_at: string;
  internal_note: string | null;
};

export type OrganizationAdmin = {
  areas: { id: string; name: string; position: number }[];
  members: {
    id: string;
    area_id: string;
    display_name: string;
    role_title: string;
    bio: string | null;
    public_contact: string | null;
    position: number;
    active: boolean;
  }[];
  applications: RecruitmentApplication[];
};

export async function listPublicTeam(): Promise<PublicTeamArea[]> {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.rpc('list_public_team');
  if (error) throw new Error(`public_team_failed:${error.code}`);
  return (data ?? []) as PublicTeamArea[];
}

export async function listPublicOpenings(): Promise<PublicOpening[]> {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase
    .from('recruitment_openings')
    .select(
      'id,title,slug,summary,description,requirements,process,contact_email,applications_enabled,closes_at',
    )
    .eq('status', 'published')
    .order('published_at', { ascending: false });
  if (error) throw new Error(`public_openings_failed:${error.code}`);
  return (data ?? []) as PublicOpening[];
}

export async function getOrganizationAdmin(): Promise<OrganizationAdmin> {
  const session = await getEditorialSession('/admin/organizacao');
  if (!session.roles.includes('diretor')) notFound();
  const supabase = await createSupabaseServerClient();
  const [areas, members, applications] = await Promise.all([
    supabase.from('team_areas').select('id,name,position').order('position'),
    supabase
      .from('team_members')
      .select('id,area_id,display_name,role_title,bio,public_contact,position,active')
      .order('area_id')
      .order('position'),
    supabase
      .from('recruitment_applications')
      .select(
        'id,applicant_name,email,affiliation,message,status,created_at,retention_expires_at,internal_note',
      )
      .order('created_at', { ascending: false }),
  ]);
  if (areas.error || members.error || applications.error) {
    throw new Error('organization_admin_failed');
  }
  return {
    areas: (areas.data ?? []) as OrganizationAdmin['areas'],
    members: (members.data ?? []) as OrganizationAdmin['members'],
    applications: (applications.data ?? []) as RecruitmentApplication[],
  };
}
