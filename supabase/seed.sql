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

-- Fatia publica da Etapa 3: conteudo editorial ficticio, mas completo e navegavel.
update public.profiles
set display_name = case id
  when '10000000-0000-4000-8000-000000000001' then 'Lia Nascimento'
  when '10000000-0000-4000-8000-000000000002' then 'Rafael Moura'
  when '10000000-0000-4000-8000-000000000003' then 'Marina Campos'
  when '10000000-0000-4000-8000-000000000004' then 'Joana Freitas'
  when '10000000-0000-4000-8000-000000000005' then 'Caio Ribeiro'
  else display_name
end
where id::text like '10000000-0000-4000-8000-%';

insert into public.categories (id, name, slug, description, created_by)
values
  (
    '20000000-0000-4000-8000-000000000101', 'Campus', 'campus',
    'Notícias, projetos e histórias da vida universitária.',
    '10000000-0000-4000-8000-000000000003'
  ),
  (
    '20000000-0000-4000-8000-000000000102', 'Cultura', 'cultura',
    'Arte, literatura e memória produzidas pela comunidade.',
    '10000000-0000-4000-8000-000000000003'
  ),
  (
    '20000000-0000-4000-8000-000000000103', 'Ciência', 'ciencia',
    'Pesquisa e conhecimento explicados de forma próxima.',
    '10000000-0000-4000-8000-000000000003'
  ),
  (
    '20000000-0000-4000-8000-000000000104', 'Comunidade', 'comunidade',
    'Iniciativas que conectam a universidade e seu território.',
    '10000000-0000-4000-8000-000000000003'
  );

insert into public.tags (id, name, slug, created_by)
values
  ('21000000-0000-4000-8000-000000000101', 'Extensão', 'extensao', '10000000-0000-4000-8000-000000000003'),
  ('21000000-0000-4000-8000-000000000102', 'Sustentabilidade', 'sustentabilidade', '10000000-0000-4000-8000-000000000003'),
  ('21000000-0000-4000-8000-000000000103', 'Literatura', 'literatura', '10000000-0000-4000-8000-000000000003'),
  ('21000000-0000-4000-8000-000000000104', 'Pesquisa', 'pesquisa', '10000000-0000-4000-8000-000000000003'),
  ('21000000-0000-4000-8000-000000000105', 'Fotografia', 'fotografia', '10000000-0000-4000-8000-000000000003');

insert into public.editions (
  id, title, slug, summary, issue_number, starts_on, ends_on, published_at, created_by
)
values (
  '22000000-0000-4000-8000-000000000101',
  'Entre lugares',
  'entre-lugares-01',
  'A primeira edição reúne histórias sobre os espaços que a comunidade transforma todos os dias.',
  1,
  '2026-07-01',
  '2026-07-31',
  '2026-07-01 12:00:00-03',
  '10000000-0000-4000-8000-000000000003'
);

insert into public.media_assets (
  id, owner_id, bucket_id, object_path, purpose, mime_type, byte_size,
  title, alt_text, credit, license
)
values
  ('23000000-0000-4000-8000-000000000101', '10000000-0000-4000-8000-000000000003', 'content-public', '10000000-0000-4000-8000-000000000003/static/campus-em-movimento.svg', 'cover', 'image/svg+xml', 2400, 'Campus em movimento', 'Estudantes atravessam um pátio entre árvores e prédios do campus.', 'Ilustração: Estúdio Canarinho', 'CC BY-NC 4.0'),
  ('23000000-0000-4000-8000-000000000102', '10000000-0000-4000-8000-000000000003', 'content-public', '10000000-0000-4000-8000-000000000003/static/ciencia-aberta.svg', 'cover', 'image/svg+xml', 2400, 'Ciência aberta', 'Bancada de laboratório com plantas, frascos e cadernos de pesquisa.', 'Ilustração: Estúdio Canarinho', 'CC BY-NC 4.0'),
  ('23000000-0000-4000-8000-000000000103', '10000000-0000-4000-8000-000000000003', 'content-public', '10000000-0000-4000-8000-000000000003/static/horta-coletiva.svg', 'cover', 'image/svg+xml', 2400, 'Horta coletiva', 'Mãos cuidam de mudas em canteiros comunitários.', 'Ilustração: Estúdio Canarinho', 'CC BY-NC 4.0'),
  ('23000000-0000-4000-8000-000000000104', '10000000-0000-4000-8000-000000000003', 'content-public', '10000000-0000-4000-8000-000000000003/static/poema-janela.svg', 'cover', 'image/svg+xml', 2400, 'Poema da janela', 'Janela aberta para um céu amarelo no fim da tarde.', 'Ilustração: Estúdio Canarinho', 'CC BY-NC 4.0'),
  ('23000000-0000-4000-8000-000000000105', '10000000-0000-4000-8000-000000000003', 'content-public', '10000000-0000-4000-8000-000000000003/static/fotografia-campus.svg', 'cover', 'image/svg+xml', 2400, 'Geometrias do campus', 'Sombras geométricas atravessam uma escadaria de concreto.', 'Ilustração: Estúdio Canarinho', 'CC BY-NC 4.0'),
  ('23000000-0000-4000-8000-000000000106', '10000000-0000-4000-8000-000000000003', 'content-public', '10000000-0000-4000-8000-000000000003/static/biblioteca-viva.svg', 'cover', 'image/svg+xml', 2400, 'Biblioteca viva', 'Leitores conversam entre estantes coloridas de uma biblioteca.', 'Ilustração: Estúdio Canarinho', 'CC BY-NC 4.0');

insert into public.content_items (
  id, slug, type, title, subtitle, summary, body, status, visibility, submitted_by,
  cover_asset_id, seo_title, seo_description, terms_version, terms_accepted_at,
  submitted_at, approved_at, published_at
)
values
  (
    '31000000-0000-4000-8000-000000000101', 'campus-em-movimento', 'news',
    'Um campus que se move com quem chega',
    'Novos coletivos ocupam pátios, salas e ideias no início do semestre.',
    'Projetos criados por estudantes mostram como pequenos encontros transformam a experiência universitária.',
    '{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"Antes das oito da manhã, o pátio central já reúne gente chegando de bicicleta, cartazes de oficinas e uma roda que combina as atividades da semana."}]},{"type":"heading","attrs":{"level":2},"content":[{"type":"text","text":"Espaço também é participação"}]},{"type":"paragraph","content":[{"type":"text","text":"Neste semestre, quatro coletivos passaram a compartilhar uma sala antes vazia. O acordo simples de uso abriu espaço para encontros de leitura, reparo de bicicletas e acolhimento de estudantes recém-chegados."}]},{"type":"blockquote","content":[{"type":"paragraph","content":[{"type":"text","text":"Quando a gente reconhece o campus como lugar de convivência, estudar deixa de ser uma experiência solitária."}]}]},{"type":"paragraph","content":[{"type":"text","text":"A programação é aberta e será atualizada ao longo do mês pelos próprios grupos."}]}]}',
    'published', 'public', '10000000-0000-4000-8000-000000000001',
    '23000000-0000-4000-8000-000000000101', 'Um campus que se move com quem chega',
    'Conheça coletivos estudantis que transformam espaços e relações no campus.',
    '2026-01', '2026-06-30 10:00:00-03', '2026-06-30 10:00:00-03',
    '2026-07-01 09:00:00-03', '2026-07-18 08:00:00-03'
  ),
  (
    '31000000-0000-4000-8000-000000000102', 'pesquisa-que-cabe-na-conversa', 'weekly_article',
    'A ciência que cabe em uma conversa',
    'Pesquisadores abrem os laboratórios e traduzem descobertas sem perder a precisão.',
    'Uma iniciativa de ciência aberta aproxima perguntas do cotidiano e pesquisas desenvolvidas na universidade.',
    '{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"Toda quinta-feira, uma pergunta enviada pela comunidade vira ponto de partida para uma conversa com pesquisadores."}]},{"type":"heading","attrs":{"level":2},"content":[{"type":"text","text":"Perguntar é parte do método"}]},{"type":"paragraph","content":[{"type":"text","text":"Os encontros evitam respostas prontas. Em vez disso, mostram hipóteses, dúvidas e os caminhos usados para produzir evidências."}]},{"type":"bulletList","content":[{"type":"listItem","content":[{"type":"paragraph","content":[{"type":"text","text":"Encontros gratuitos e abertos"}]}]},{"type":"listItem","content":[{"type":"paragraph","content":[{"type":"text","text":"Materiais com linguagem acessível"}]}]},{"type":"listItem","content":[{"type":"paragraph","content":[{"type":"text","text":"Perguntas recebidas durante todo o mês"}]}]}]}]}',
    'published', 'public', '10000000-0000-4000-8000-000000000002',
    '23000000-0000-4000-8000-000000000102', 'Ciência aberta: pesquisa que cabe na conversa',
    'Projeto aproxima pesquisadores e comunidade em encontros semanais e acessíveis.',
    '2026-01', '2026-06-25 10:00:00-03', '2026-06-25 10:00:00-03',
    '2026-07-02 09:00:00-03', '2026-07-16 09:30:00-03'
  ),
  (
    '31000000-0000-4000-8000-000000000103', 'horta-coletiva-aprende-com-o-bairro', 'column',
    'Uma horta que aprende com o bairro',
    'Coluna semanal — por Marina Campos.',
    'O cultivo compartilhado aproxima saberes acadêmicos e experiências guardadas por moradores da região.',
    '{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"A primeira lição da horta é que nenhum calendário vence sozinho a observação de quem conhece o lugar."}]},{"type":"paragraph","content":[{"type":"text","text":"Moradores ensinaram a ler o vento entre os prédios; estudantes organizaram os registros de umidade. Juntos, redesenharam os canteiros e reduziram o desperdício de água."}]},{"type":"heading","attrs":{"level":2},"content":[{"type":"text","text":"Conhecimento em mão dupla"}]},{"type":"paragraph","content":[{"type":"text","text":"O resultado mais valioso não cabe na colheita: está na confiança criada a cada sábado de trabalho."}]}]}',
    'published', 'public', '10000000-0000-4000-8000-000000000003',
    '23000000-0000-4000-8000-000000000103', 'Uma horta universitária que aprende com o bairro',
    'Coluna sobre o encontro entre extensão, sustentabilidade e saberes da comunidade.',
    '2026-01', '2026-06-20 10:00:00-03', '2026-06-20 10:00:00-03',
    '2026-07-01 09:00:00-03', '2026-07-14 07:30:00-03'
  ),
  (
    '31000000-0000-4000-8000-000000000104', 'inventario-das-janelas', 'poem',
    'Inventário das janelas',
    null,
    'Um poema sobre as paisagens pequenas que acompanham a rotina de quem estuda.',
    '{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"na janela da sala quatro / a tarde pousa devagar"}]},{"type":"paragraph","content":[{"type":"text","text":"leva nos ombros um caderno / e o rumor das árvores"}]},{"type":"paragraph","content":[{"type":"text","text":"quem passa não sabe / mas o céu mudou de lugar"}]}]}',
    'published', 'public', '10000000-0000-4000-8000-000000000001',
    '23000000-0000-4000-8000-000000000104', 'Inventário das janelas — poema',
    'Leia o poema Inventário das janelas, publicado na primeira edição do Canarinho.',
    '2026-01', '2026-06-18 10:00:00-03', '2026-06-18 10:00:00-03',
    '2026-06-28 09:00:00-03', '2026-07-12 11:00:00-03'
  ),
  (
    '31000000-0000-4000-8000-000000000105', 'geometrias-de-uma-tarde', 'artwork',
    'Geometrias de uma tarde',
    'Ensaio visual encontra desenhos de luz na arquitetura do campus.',
    'Uma série fotográfica observa escadas, corredores e sombras durante o recesso.',
    '{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"As imagens foram produzidas entre três e cinco da tarde, quando a luz recorta passagens familiares e revela novas formas de atravessá-las."}]},{"type":"paragraph","content":[{"type":"text","text":"O ensaio integra a chamada aberta de produções artísticas da comunidade."}]}]}',
    'published', 'public', '10000000-0000-4000-8000-000000000004',
    '23000000-0000-4000-8000-000000000105', 'Geometrias de uma tarde — ensaio visual',
    'Ensaio visual registra luz, sombras e arquitetura no campus universitário.',
    '2026-01', '2026-06-15 10:00:00-03', '2026-06-15 10:00:00-03',
    '2026-06-25 09:00:00-03', '2026-07-10 15:00:00-03'
  ),
  (
    '31000000-0000-4000-8000-000000000106', 'biblioteca-viva-depois-das-seis', 'essay',
    'A biblioteca viva depois das seis',
    'Clubes de leitura reinventam o fim do dia no campus.',
    'Entre estantes e café, encontros noturnos fazem da biblioteca um lugar de escuta e criação.',
    '{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"Quando as aulas terminam, as mesas do fundo mudam de função. Cadernos dão lugar a livros compartilhados e a conversa começa sem pressa."}]},{"type":"heading","attrs":{"level":2},"content":[{"type":"text","text":"Ler também é encontrar"}]},{"type":"paragraph","content":[{"type":"text","text":"Os grupos escolhem textos curtos e mantêm vagas abertas para quem chega pela primeira vez. Não é preciso ter lido tudo: curiosidade basta."}]}]}',
    'published', 'public', '10000000-0000-4000-8000-000000000005',
    '23000000-0000-4000-8000-000000000106', 'A biblioteca viva depois das seis',
    'Clubes de leitura abertos transformam a rotina noturna da biblioteca universitária.',
    '2026-01', '2026-06-10 10:00:00-03', '2026-06-10 10:00:00-03',
    '2026-06-20 09:00:00-03', '2026-07-08 18:00:00-03'
  ),
  (
    '31000000-0000-4000-8000-000000000199', 'pauta-ainda-secreta', 'news',
    'Pauta ainda secreta', null, 'Este resumo nunca pode aparecer publicamente.',
    '{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"segredo editorial que nao pode vazar na busca"}]}]}',
    'draft', 'public', '10000000-0000-4000-8000-000000000001', null, null, null,
    null, null, null, null, null
  );

insert into public.content_authors (content_id, position, profile_id)
values
  ('31000000-0000-4000-8000-000000000101', 1, '10000000-0000-4000-8000-000000000001'),
  ('31000000-0000-4000-8000-000000000102', 1, '10000000-0000-4000-8000-000000000002'),
  ('31000000-0000-4000-8000-000000000103', 1, '10000000-0000-4000-8000-000000000003'),
  ('31000000-0000-4000-8000-000000000104', 1, '10000000-0000-4000-8000-000000000001'),
  ('31000000-0000-4000-8000-000000000105', 1, '10000000-0000-4000-8000-000000000004'),
  ('31000000-0000-4000-8000-000000000106', 1, '10000000-0000-4000-8000-000000000005'),
  ('31000000-0000-4000-8000-000000000199', 1, '10000000-0000-4000-8000-000000000001');

insert into public.content_categories (content_id, category_id, is_primary)
values
  ('31000000-0000-4000-8000-000000000101', '20000000-0000-4000-8000-000000000101', true),
  ('31000000-0000-4000-8000-000000000102', '20000000-0000-4000-8000-000000000103', true),
  ('31000000-0000-4000-8000-000000000103', '20000000-0000-4000-8000-000000000104', true),
  ('31000000-0000-4000-8000-000000000104', '20000000-0000-4000-8000-000000000102', true),
  ('31000000-0000-4000-8000-000000000105', '20000000-0000-4000-8000-000000000102', true),
  ('31000000-0000-4000-8000-000000000106', '20000000-0000-4000-8000-000000000102', true),
  ('31000000-0000-4000-8000-000000000199', '20000000-0000-4000-8000-000000000101', true);

insert into public.content_tags (content_id, tag_id)
values
  ('31000000-0000-4000-8000-000000000101', '21000000-0000-4000-8000-000000000101'),
  ('31000000-0000-4000-8000-000000000102', '21000000-0000-4000-8000-000000000104'),
  ('31000000-0000-4000-8000-000000000102', '21000000-0000-4000-8000-000000000101'),
  ('31000000-0000-4000-8000-000000000103', '21000000-0000-4000-8000-000000000101'),
  ('31000000-0000-4000-8000-000000000103', '21000000-0000-4000-8000-000000000102'),
  ('31000000-0000-4000-8000-000000000104', '21000000-0000-4000-8000-000000000103'),
  ('31000000-0000-4000-8000-000000000105', '21000000-0000-4000-8000-000000000105'),
  ('31000000-0000-4000-8000-000000000106', '21000000-0000-4000-8000-000000000103');

insert into public.edition_items (edition_id, content_id, position)
values
  ('22000000-0000-4000-8000-000000000101', '31000000-0000-4000-8000-000000000101', 1),
  ('22000000-0000-4000-8000-000000000101', '31000000-0000-4000-8000-000000000102', 2),
  ('22000000-0000-4000-8000-000000000101', '31000000-0000-4000-8000-000000000104', 3),
  ('22000000-0000-4000-8000-000000000101', '31000000-0000-4000-8000-000000000105', 4);

insert into public.content_relationships (
  source_content_id, target_content_id, position, created_by
)
values
  ('31000000-0000-4000-8000-000000000101', '31000000-0000-4000-8000-000000000103', 1, '10000000-0000-4000-8000-000000000003'),
  ('31000000-0000-4000-8000-000000000101', '31000000-0000-4000-8000-000000000102', 2, '10000000-0000-4000-8000-000000000003'),
  ('31000000-0000-4000-8000-000000000102', '31000000-0000-4000-8000-000000000101', 1, '10000000-0000-4000-8000-000000000003'),
  ('31000000-0000-4000-8000-000000000103', '31000000-0000-4000-8000-000000000106', 1, '10000000-0000-4000-8000-000000000003'),
  ('31000000-0000-4000-8000-000000000104', '31000000-0000-4000-8000-000000000106', 1, '10000000-0000-4000-8000-000000000003');

insert into public.content_placements (content_id, slot, position, created_by)
values
  ('31000000-0000-4000-8000-000000000101', 'hero', 1, '10000000-0000-4000-8000-000000000003'),
  ('31000000-0000-4000-8000-000000000102', 'featured', 1, '10000000-0000-4000-8000-000000000003'),
  ('31000000-0000-4000-8000-000000000103', 'featured', 2, '10000000-0000-4000-8000-000000000003'),
  ('31000000-0000-4000-8000-000000000104', 'featured', 3, '10000000-0000-4000-8000-000000000003'),
  ('31000000-0000-4000-8000-000000000105', 'gallery', 1, '10000000-0000-4000-8000-000000000003');
