import { expect, type Page, test } from '@playwright/test';

const password = 'CanarinhoLocal123!';

async function signIn(page: Page, email: string, returnPath: string) {
  await page.goto(`/entrar?retorno=${encodeURIComponent(returnPath)}`);
  await page.getByRole('textbox', { name: 'Email', exact: true }).fill(email);
  await page.getByLabel('Senha').fill(password);
  await page.getByRole('button', { name: 'Entrar' }).click();
  await expect(page).toHaveURL(new RegExp(`${returnPath.replaceAll('/', '\\/')}$`));
}

test('visitante consulta informes e inicia inscricao consentida', async ({ page }) => {
  await page.goto('/informes');
  await expect(page.getByRole('heading', { name: 'Quadro de informes' })).toBeVisible();
  await expect(
    page.getByRole('heading', { name: 'Feira de coletivos ocupa o varandao' }),
  ).toBeVisible();
  await expect(page.getByText('Informe ainda em preparacao')).toHaveCount(0);

  const email = `newsletter-${Date.now()}@example.com`;
  await page.getByRole('textbox', { name: 'Email', exact: true }).fill(email);
  await page.getByLabel(/Quero receber a Carta do Canarinho/).check();
  await page.getByRole('button', { name: 'Inscrever meu email' }).click();
  await expect(page.getByText('Confira seu email para confirmar a inscricao.')).toBeVisible();

  await signIn(page, 'conexoes@local.canarinho.test', '/admin/comunicacoes');
  await expect(page.getByText(email)).toBeVisible();
  await expect(page.getByText('pending', { exact: true })).toBeVisible();
});

test('Conexoes publica informe e permanece fora do fluxo editorial', async ({ page }) => {
  await signIn(page, 'conexoes@local.canarinho.test', '/admin/comunicacoes');
  const form = page
    .locator('form')
    .filter({ has: page.getByRole('heading', { name: 'Novo informe' }) });
  const suffix = Date.now();
  await form.getByLabel('Título').fill(`Encontro aberto E2E ${suffix}`);
  await form.getByLabel('Slug').fill(`encontro-aberto-e2e-${suffix}`);
  await form
    .getByLabel('Resumo')
    .fill('Um encontro aberto criado para validar a jornada de informes.');
  await form
    .getByLabel('Texto')
    .fill('A comunidade pode participar do encontro sem inscrição prévia nesta semana.');
  await form.getByLabel('Permitir comentários').check();
  await form.getByRole('button', { name: 'Salvar rascunho' }).click();
  await expect(page.getByText('Informe salvo com auditoria.')).toBeVisible();

  const card = page
    .locator('.moderation-card')
    .filter({ hasText: `Encontro aberto E2E ${suffix}` });
  await card.getByLabel('Motivo para publicar').fill('Divulgação validada pelo teste E2E');
  await card.getByRole('button', { name: 'Publicar' }).click();
  await expect(page.getByText('Estado do informe atualizado.')).toBeVisible();
  await page.goto(`/informes/encontro-aberto-e2e-${suffix}`);
  await expect(page.getByRole('heading', { name: `Encontro aberto E2E ${suffix}` })).toBeVisible();

  const response = await page.goto('/admin/editorial');
  expect(response?.status()).toBe(404);
});

test('Diretor solicita exportacao protegida e auditada', async ({ page }) => {
  await signIn(page, 'diretor@local.canarinho.test', '/admin/comunicacoes');
  await page.getByLabel('Finalidade da exportação').fill('Homologação de consentimentos');
  await page.getByRole('button', { name: 'Solicitar CSV' }).click();
  await expect(page.getByText('Exportação protegida solicitada.')).toBeVisible();
  await expect(page.locator('.export-list li').first()).toContainText('pending');
});
