import { createClient, type SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

type WorkerAction =
  'all' | 'campaigns' | 'confirmations' | 'notifications' | 'exports' | 'download-export';

type WorkerRequest = {
  action?: WorkerAction;
  campaignId?: string;
  exportId?: string;
  batchSize?: number;
};

type EmailMessage = {
  to: string;
  subject: string;
  text: string;
  idempotencyKey: string;
};

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const siteUrl = Deno.env.get('SITE_URL') ?? 'http://localhost:3000';
const providerUrl = Deno.env.get('EMAIL_PROVIDER_URL');
const providerKey = Deno.env.get('EMAIL_PROVIDER_API_KEY');
const sender = Deno.env.get('EMAIL_FROM') ?? 'Canarinho <nao-responda@canarinho.test>';

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json; charset=utf-8' },
  });
}

function cleanError(error: unknown) {
  return error instanceof Error ? error.message.slice(0, 500) : 'worker_error';
}

async function authorize(request: Request, admin: SupabaseClient) {
  const cronSecret = Deno.env.get('COMMUNICATIONS_CRON_SECRET');
  if (cronSecret && request.headers.get('x-cron-secret') === cronSecret) {
    return { kind: 'cron' as const, userId: null, roles: ['diretor'] };
  }
  const authorization = request.headers.get('authorization') ?? '';
  const token = authorization.replace(/^Bearer\s+/i, '');
  if (!token) return null;
  const { data, error } = await admin.auth.getUser(token);
  if (error || !data.user) {
    console.warn('communications_worker_auth_rejected', error?.code ?? 'missing_user');
    return null;
  }
  const { data: roleRows, error: roleError } = await admin
    .from('user_roles')
    .select('role_code')
    .eq('user_id', data.user.id);
  if (roleError) console.warn('communications_worker_role_lookup_failed', roleError.code);
  const roles = (roleRows ?? []).map((row) => String(row.role_code));
  if (!roles.some((role) => ['conexoes', 'editor', 'diretor'].includes(role))) {
    console.warn('communications_worker_role_rejected');
    return null;
  }
  return { kind: 'user' as const, userId: data.user.id, roles };
}

async function sendEmail(message: EmailMessage) {
  if (!providerUrl || !providerKey) {
    return { id: `local:${message.idempotencyKey}` };
  }
  const response = await fetch(providerUrl, {
    method: 'POST',
    headers: {
      authorization: `Bearer ${providerKey}`,
      'content-type': 'application/json',
      'idempotency-key': message.idempotencyKey,
    },
    body: JSON.stringify({
      from: sender,
      to: [message.to],
      subject: message.subject,
      text: message.text,
    }),
  });
  if (!response.ok) throw new Error(`email_provider_${response.status}`);
  const result = (await response.json()) as { id?: string };
  return { id: result.id ?? message.idempotencyKey };
}

async function processConfirmations(admin: SupabaseClient, batchSize: number) {
  const { data, error } = await admin.rpc('claim_newsletter_confirmation_events', {
    batch_size: batchSize,
  });
  if (error) throw error;
  let succeeded = 0;
  for (const event of data ?? []) {
    try {
      const link = `${siteUrl}/newsletter/confirmar?token=${encodeURIComponent(event.confirmation_token)}`;
      await sendEmail({
        to: event.email,
        subject: 'Confirme sua inscrição na Carta do Canarinho',
        text: `Confirme sua inscrição pelo link: ${link}\n\nSe você não pediu esta mensagem, ignore-a.`,
        idempotencyKey: event.idempotency_key,
      });
      await admin.rpc('record_communication_outbox_event', {
        requested_event_id: event.event_id,
        requested_succeeded: true,
        requested_error: null,
      });
      succeeded += 1;
    } catch (error) {
      await admin.rpc('record_communication_outbox_event', {
        requested_event_id: event.event_id,
        requested_succeeded: false,
        requested_error: cleanError(error),
      });
    }
  }
  return { claimed: data?.length ?? 0, succeeded };
}

async function processCampaigns(admin: SupabaseClient, batchSize: number, campaignId?: string) {
  const { data, error } = await admin.rpc('claim_newsletter_batch', {
    requested_campaign_id: campaignId ?? null,
    batch_size: batchSize,
  });
  if (error) throw error;
  let succeeded = 0;
  for (const delivery of data ?? []) {
    try {
      const unsubscribeUrl = `${siteUrl}/newsletter/descadastrar?token=${encodeURIComponent(delivery.unsubscribe_token)}`;
      const result = await sendEmail({
        to: delivery.email,
        subject: delivery.subject,
        text: `${delivery.preview_text ? `${delivery.preview_text}\n\n` : ''}${delivery.body_text}\n\nDescadastrar: ${unsubscribeUrl}`,
        idempotencyKey: delivery.idempotency_key,
      });
      await admin.rpc('record_newsletter_delivery', {
        requested_delivery_id: delivery.delivery_id,
        requested_succeeded: true,
        requested_provider_message_id: result.id,
        requested_error: null,
      });
      succeeded += 1;
    } catch (error) {
      await admin.rpc('record_newsletter_delivery', {
        requested_delivery_id: delivery.delivery_id,
        requested_succeeded: false,
        requested_provider_message_id: null,
        requested_error: cleanError(error),
      });
    }
  }
  return { claimed: data?.length ?? 0, succeeded };
}

function csvCell(value: unknown) {
  return `"${String(value ?? '').replaceAll('"', '""')}"`;
}

async function processExports(admin: SupabaseClient, batchSize: number) {
  const { data: jobs, error } = await admin.rpc('claim_newsletter_exports', {
    batch_size: Math.min(batchSize, 20),
  });
  if (error) throw error;
  let succeeded = 0;
  for (const job of jobs ?? []) {
    try {
      const { data: subscribers, error: listError } = await admin
        .from('newsletter_subscribers')
        .select('email,status,segment,consent_version,consented_at,confirmed_at,unsubscribed_at')
        .order('created_at');
      if (listError) throw listError;
      const header = [
        'email',
        'status',
        'segment',
        'consent_version',
        'consented_at',
        'confirmed_at',
        'unsubscribed_at',
      ];
      const csv = [
        header.map(csvCell).join(','),
        ...(subscribers ?? []).map((row) => header.map((key) => csvCell(row[key])).join(',')),
      ].join('\n');
      const objectPath = `${job.requested_by}/${job.export_id}.csv`;
      const { error: uploadError } = await admin.storage
        .from('newsletter-exports')
        .upload(objectPath, new Blob([csv], { type: 'text/csv;charset=utf-8' }), { upsert: true });
      if (uploadError) throw uploadError;
      await admin.rpc('complete_newsletter_export', {
        requested_export_id: job.export_id,
        requested_succeeded: true,
        requested_object_path: objectPath,
        requested_row_count: subscribers?.length ?? 0,
        requested_error: null,
      });
      succeeded += 1;
    } catch (error) {
      await admin.rpc('complete_newsletter_export', {
        requested_export_id: job.export_id,
        requested_succeeded: false,
        requested_object_path: null,
        requested_row_count: null,
        requested_error: cleanError(error),
      });
    }
  }
  return { claimed: jobs?.length ?? 0, succeeded };
}

async function cleanup(admin: SupabaseClient) {
  await admin.rpc('expire_communication_notice_highlights', { batch_size: 100 });
  const { data: exports } = await admin.rpc('expire_newsletter_exports', { batch_size: 100 });
  const paths = (exports ?? []).map((item) => item.object_path).filter(Boolean);
  if (paths.length) await admin.storage.from('newsletter-exports').remove(paths);
}

Deno.serve(async (request) => {
  if (request.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);
  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const actor = await authorize(request, admin);
  if (!actor) return json({ error: 'unauthorized' }, 401);
  let input: WorkerRequest;
  try {
    input = (await request.json()) as WorkerRequest;
  } catch {
    return json({ error: 'invalid_json' }, 400);
  }
  const action = input.action ?? 'all';
  const batchSize = Math.min(Math.max(input.batchSize ?? 50, 1), 200);
  try {
    if (action === 'download-export') {
      if (!actor.roles.includes('diretor') || !input.exportId)
        return json({ error: 'forbidden' }, 403);
      const { data: item } = await admin
        .from('newsletter_exports')
        .select('requested_by,status,object_path,expires_at')
        .eq('id', input.exportId)
        .maybeSingle();
      if (
        !item ||
        item.requested_by !== actor.userId ||
        item.status !== 'ready' ||
        !item.object_path ||
        new Date(item.expires_at) <= new Date()
      ) {
        return json({ error: 'export_unavailable' }, 404);
      }
      const { data, error } = await admin.storage
        .from('newsletter-exports')
        .createSignedUrl(item.object_path, 60, { download: `inscritos-${input.exportId}.csv` });
      if (error) throw error;
      return json({ signedUrl: data.signedUrl });
    }
    const result: Record<string, unknown> = {};
    if (action === 'all' || action === 'confirmations')
      result.confirmations = await processConfirmations(admin, batchSize);
    if (action === 'all' || action === 'notifications') {
      const { data, error } = await admin.rpc('process_editorial_notifications', {
        batch_size: batchSize,
      });
      if (error) throw error;
      result.notifications = { processed: data ?? 0 };
    }
    if (action === 'all' || action === 'campaigns')
      result.campaigns = await processCampaigns(admin, batchSize, input.campaignId);
    if (action === 'all' || action === 'exports')
      result.exports = await processExports(admin, batchSize);
    await cleanup(admin);
    return json(result);
  } catch (error) {
    return json({ error: cleanError(error) }, 500);
  }
});
