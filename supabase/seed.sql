-- Dados exclusivamente locais e ficticios. Nao executar em staging ou producao.
-- Todas as personas usam a senha: CanarinhoLocal123!

with personas (id, email, display_name) as (
  values
    ('10000000-0000-4000-8000-000000000001'::uuid, 'leitor@local.canarinho.test', 'Pessoa Leitora'),
    ('10000000-0000-4000-8000-000000000002'::uuid, 'revisor@local.canarinho.test', 'Pessoa Revisora'),
    ('10000000-0000-4000-8000-000000000003'::uuid, 'editor@local.canarinho.test', 'Pessoa Editora'),
    ('10000000-0000-4000-8000-000000000004'::uuid, 'conexoes@local.canarinho.test', 'Pessoa de Conexoes'),
    ('10000000-0000-4000-8000-000000000005'::uuid, 'diretor@local.canarinho.test', 'Pessoa Diretora')
)
insert into auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at,
  confirmation_token,
  recovery_token,
  email_change,
  email_change_token_new,
  is_sso_user,
  is_anonymous
)
select
  '00000000-0000-0000-0000-000000000000'::uuid,
  personas.id,
  'authenticated',
  'authenticated',
  personas.email,
  extensions.crypt('CanarinhoLocal123!', extensions.gen_salt('bf')),
  statement_timestamp(),
  jsonb_build_object('provider', 'email', 'providers', jsonb_build_array('email')),
  jsonb_build_object('display_name', personas.display_name, 'seed_persona', true),
  statement_timestamp(),
  statement_timestamp(),
  '',
  '',
  '',
  '',
  false,
  false
from personas
on conflict (id) do nothing;

with personas (id, email) as (
  values
    ('10000000-0000-4000-8000-000000000001'::uuid, 'leitor@local.canarinho.test'),
    ('10000000-0000-4000-8000-000000000002'::uuid, 'revisor@local.canarinho.test'),
    ('10000000-0000-4000-8000-000000000003'::uuid, 'editor@local.canarinho.test'),
    ('10000000-0000-4000-8000-000000000004'::uuid, 'conexoes@local.canarinho.test'),
    ('10000000-0000-4000-8000-000000000005'::uuid, 'diretor@local.canarinho.test')
)
insert into auth.identities (
  id,
  user_id,
  provider_id,
  identity_data,
  provider,
  last_sign_in_at,
  created_at,
  updated_at
)
select
  personas.id,
  personas.id,
  personas.id::text,
  jsonb_build_object(
    'sub', personas.id::text,
    'email', personas.email,
    'email_verified', true,
    'phone_verified', false
  ),
  'email',
  statement_timestamp(),
  statement_timestamp(),
  statement_timestamp()
from personas
on conflict (provider_id, provider) do nothing;

with assignments (user_id, role_code) as (
  values
    ('10000000-0000-4000-8000-000000000001'::uuid, 'leitor'::public.app_role),
    ('10000000-0000-4000-8000-000000000002'::uuid, 'revisor'::public.app_role),
    ('10000000-0000-4000-8000-000000000003'::uuid, 'editor'::public.app_role),
    ('10000000-0000-4000-8000-000000000004'::uuid, 'conexoes'::public.app_role),
    ('10000000-0000-4000-8000-000000000005'::uuid, 'diretor'::public.app_role)
)
insert into public.user_roles (user_id, role_code)
select assignments.user_id, assignments.role_code
from assignments
on conflict (user_id, role_code) do nothing;
