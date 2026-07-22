import { expect, type Page, test } from '@playwright/test';

const password = 'CanarinhoLocal123!';

async function signIn(page: Page, email: string, returnPath: string) {
  await page.goto(`/entrar?retorno=${encodeURIComponent(returnPath)}`);
  await page.getByLabel('Email').fill(email);
  await page.getByLabel('Senha').fill(password);
  await page.getByRole('button', { name: 'Entrar' }).click();
  await expect(page).toHaveURL(new RegExp(`${returnPath.replaceAll('/', '\\/')}$`));
}

test('galeria, equipe e candidatura formam uma jornada publica sem expor a selecao', async ({
  page,
}) => {
  await page.goto('/galeria');
  await expect(page.getByRole('heading', { name: 'Galeria' })).toBeVisible();
  await expect(page.getByRole('heading', { name: 'Geometrias de uma tarde' })).toBeVisible();

  await page.goto('/equipe');
  await expect(page.getByRole('heading', { name: 'Um jornal feito em bando' })).toBeVisible();
  await expect(page.getByRole('heading', { name: 'Caio Ribeiro' })).toBeVisible();

  const email = `candidata-${Date.now()}@example.com`;
  await page.goto('/faca-parte');
  await page.getByLabel('Nome completo').fill('Pessoa Candidata E2E');
  await page.getByLabel('Email').fill(email);
  await page.getByLabel('Curso ou vínculo').fill('Relações Internacionais');
  await page
    .getByLabel('Por que você quer participar?')
    .fill('Quero colaborar com a revisão e aprender com a rotina editorial coletiva.');
  await page.getByLabel(/Autorizo o uso destes dados/).check();
  await page.getByRole('button', { name: 'Enviar candidatura' }).click();
  await expect(page.getByText('Candidatura recebida. Entraremos em contato.')).toBeVisible();
  await expect(page.getByText(email)).toHaveCount(0);

  await signIn(page, 'diretor@local.canarinho.test', '/admin/organizacao');
  await expect(page.getByText(email)).toBeVisible();
  await expect(page.getByText('Candidaturas privadas')).toBeVisible();
});

test('Leitor comenta e favorita; Editor modera sem apagar a evidencia', async ({ page }) => {
  const articlePath = '/materias/campus-em-movimento';
  await signIn(page, 'leitor@local.canarinho.test', articlePath);

  await page.getByRole('button', { name: 'Salvar nos favoritos' }).click();
  await expect(page.getByText('Conteúdo salvo nos favoritos.')).toBeVisible();
  await page.goto('/favoritos');
  await expect(
    page.getByRole('heading', { name: 'Um campus que se move com quem chega' }),
  ).toBeVisible();

  const comment = `Comentário comunitário E2E ${Date.now()}`;
  await page.goto(articlePath);
  await page.getByLabel('Participe da conversa').fill(comment);
  await page.getByRole('button', { name: 'Publicar comentário' }).click();
  await expect(page.getByText('Comentário publicado.')).toBeVisible();
  await expect(page.getByText(comment)).toBeVisible();

  await page.goto('/favoritos');
  await page.getByRole('button', { name: 'Sair' }).click();
  await signIn(page, 'editor@local.canarinho.test', '/admin/comunidade');
  const moderationCard = page.locator('.moderation-card').filter({ hasText: comment });
  await moderationCard.getByLabel('Decisão').selectOption('hide');
  await moderationCard
    .getByLabel('Motivo')
    .fill('Ocultação E2E para validar a trilha de moderação');
  await moderationCard.getByRole('button', { name: 'Registrar moderação' }).click();
  await expect(page.getByText('Moderacao registrada.')).toBeVisible();

  await page.goto(articlePath);
  await expect(page.getByText(comment)).toHaveCount(0);
});
