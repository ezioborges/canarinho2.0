import { expect, test } from '@playwright/test';

test('autor entra, salva rascunho, envia arquivo e submete sem duplicacao', async ({ page }) => {
  await page.goto('/submissoes');
  await expect(page).toHaveURL(/\/entrar\?retorno=%2Fsubmissoes/);

  await page.getByLabel('Email').fill('leitor@local.canarinho.test');
  await page.getByLabel('Senha').fill('CanarinhoLocal123!');
  await page.getByRole('button', { name: 'Entrar' }).click();
  await expect(page).toHaveURL(/\/submissoes$/);

  await page.getByRole('link', { name: 'Nova submissão' }).click();
  const uniqueTitle = `Pauta E2E ${Date.now()}`;
  await page.getByRole('textbox', { name: /^Título/ }).fill(uniqueTitle);
  await page.getByLabel('Resumo').fill('Resumo criado pelo fluxo ponta a ponta da etapa quatro.');
  await page.getByLabel('Categoria principal').selectOption({ label: 'Campus' });
  await page
    .locator('[contenteditable="true"]')
    .fill('Texto completo da submissão criado no editor estruturado.');
  await page.getByRole('button', { name: 'Salvar agora' }).click();
  await expect(page.getByRole('status')).toContainText('Rascunho salvo');
  await expect(page).toHaveURL(/\/submissoes\/[0-9a-f-]+\/editar$/);

  await page.getByLabel('Arquivo').setInputFiles({
    name: 'evidencia.pdf',
    mimeType: 'application/pdf',
    buffer: Buffer.from('%PDF-1.4\n% arquivo de teste Canarinho\n'),
  });
  const uploadResponse = page.waitForResponse(
    (response) => response.url().includes('/arquivos') && response.request().method() === 'POST',
  );
  await page.getByRole('button', { name: 'Enviar arquivo' }).click();
  const uploaded = await uploadResponse;
  expect(uploaded.status(), await uploaded.text()).toBe(201);
  await expect(page.getByText('evidencia.pdf', { exact: false })).toBeVisible();

  await page.getByLabel(/Li e aceito os termos/).check();
  const submissionResponse = page.waitForResponse(
    (response) => response.url().includes('/enviar') && response.request().method() === 'POST',
  );
  await page.getByRole('button', { name: 'Enviar para revisão' }).click();
  const submitted = await submissionResponse;
  expect(submitted.status(), await submitted.text()).toBe(200);
  await expect(page).toHaveURL(/\/submissoes\/[0-9a-f-]+\?enviada=1$/);
  await expect(page.getByText('Submissão enviada para revisão.')).toBeVisible();
  await expect(page.getByText('Enviada', { exact: true }).first()).toBeVisible();
  await expect(page.getByRole('heading', { name: uniqueTitle })).toBeVisible();
  await expect(page.getByRole('listitem')).toHaveCount(1);
});

test('perfil pode ser atualizado e a sessao pode ser encerrada', async ({ page }) => {
  await page.goto('/entrar');
  await page.getByLabel('Email').fill('leitor@local.canarinho.test');
  await page.getByLabel('Senha').fill('CanarinhoLocal123!');
  await page.getByRole('button', { name: 'Entrar' }).click();
  await expect(page).toHaveURL(/\/submissoes$/);
  await page.goto('/conta');

  await page.getByLabel('Curso').fill('Comunicação Social');
  await page.getByLabel('Vínculo').fill('Estudante');
  await page.getByRole('button', { name: 'Salvar perfil' }).click();
  await expect(page.getByText('Perfil atualizado.')).toBeVisible();

  await page.getByRole('button', { name: 'Sair' }).click();
  await expect(page).toHaveURL('/');
  await page.goto('/conta');
  await expect(page).toHaveURL(/\/entrar\?retorno=%2Fconta/);
});
