-- Estrutura minima para que as personas locais da Etapa 1 tenham papeis reais.
-- A matriz completa de autorizacao, policies e testes negativos pertence a Etapa 2.

create type public.app_role as enum (
  'leitor',
  'revisor',
  'editor',
  'conexoes',
  'diretor'
);

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null check (char_length(trim(display_name)) between 2 and 120),
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp()
);

create table public.roles (
  code public.app_role primary key,
  name text not null unique,
  description text not null,
  created_at timestamptz not null default statement_timestamp()
);

create table public.user_roles (
  user_id uuid not null references public.profiles (id) on delete cascade,
  role_code public.app_role not null references public.roles (code) on delete restrict,
  granted_at timestamptz not null default statement_timestamp(),
  primary key (user_id, role_code)
);

alter table public.profiles enable row level security;
alter table public.roles enable row level security;
alter table public.user_roles enable row level security;

comment on table public.profiles is
  'Perfil minimo vinculado ao Supabase Auth; a Etapa 2 amplia regras e policies.';
comment on table public.roles is 'Catalogo fechado dos papeis funcionais do Canarinho.';
comment on table public.user_roles is 'Relacao N:N entre usuarios e papeis funcionais.';

create function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(
      nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''),
      split_part(coalesce(new.email, 'usuario'), '@', 1)
    )
  );

  return new;
end;
$$;

revoke all on function public.handle_new_auth_user() from public, anon, authenticated;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_auth_user();

insert into public.roles (code, name, description)
values
  ('leitor', 'Leitor', 'Usuario autenticado e autor de submissoes.'),
  ('revisor', 'Revisor', 'Responsavel pela avaliacao editorial inicial.'),
  ('editor', 'Editor', 'Responsavel pela preparacao final e publicacao.'),
  ('conexoes', 'Conexoes', 'Responsavel por informes e comunicacao comunitaria.'),
  ('diretor', 'Diretor', 'Superadministrador com acoes sensiveis auditadas.');
