begin;

select plan(12);

select ok(to_regtype('public.app_role') is not null, 'enum app_role existe');
select has_table('public', 'profiles', 'tabela profiles existe');
select has_table('public', 'roles', 'tabela roles existe');
select has_table('public', 'user_roles', 'tabela user_roles existe');

select is((select count(*) from public.roles), 5::bigint, 'cinco papeis foram cadastrados');
select is(
  (select count(*) from auth.users where email like '%@local.canarinho.test'),
  5::bigint,
  'cinco usuarios ficticios foram criados'
);
select is((select count(*) from public.profiles), 5::bigint, 'cada persona possui perfil');
select is((select count(*) from public.user_roles), 5::bigint, 'cada persona possui um papel');
select is(
  (select count(distinct role_code) from public.user_roles),
  5::bigint,
  'todos os papeis possuem uma persona'
);

select ok(
  (select relrowsecurity from pg_class where oid = 'public.profiles'::regclass),
  'RLS esta ativa em profiles'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.roles'::regclass),
  'RLS esta ativa em roles'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.user_roles'::regclass),
  'RLS esta ativa em user_roles'
);

select * from finish();
rollback;
