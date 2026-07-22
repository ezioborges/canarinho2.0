import { expect, type Page, test } from '@playwright/test';

const password = 'CanarinhoLocal123!';

async function signIn(page: Page, email: string, returnPath: string) {
  await page.goto(`/entrar?retorno=${encodeURIComponent(returnPath)}`);
  await page.getByLabel('Email').fill(email);
  await page.getByLabel('Senha').fill(password);
  await page.getByRole('button', { name: 'Entrar' }).click();
  await expect(page).toHaveURL(new RegExp(`${returnPath.replaceAll('/', '\\/')}$`));
}

async function signOut(page: Page) {
  await page.getByRole('button', { name: 'Sair' }).click();
  await expect(page).toHaveURL(/\/$/);
}

function actionForm(page: Page, buttonName: string) {
  return page.locator('form').filter({ has: page.getByRole('button', { name: buttonName }) });
}

test('autor, Revisor e Editor concluem o ciclo editorial sem contornar o banco', async ({
  page,
}) => {
  await signIn(page, 'leitor@local.canarinho.test', '/submissoes');
  await page.getByRole('link', { name: 'Nova submissão' }).click();
  const uniqueTitle = `Ciclo editorial E2E ${Date.now()}`;
  await page.getByRole('textbox', { name: /^Título/ }).fill(uniqueTitle);
  await page.getByLabel('Resumo').fill('Uma pauta criada para validar o ciclo editorial completo.');
  await page.getByLabel('Categoria principal').selectOption({ label: 'Campus' });
  await page.locator('[contenteditable="true"]').fill('Texto completo para revisão e publicação.');
  await page.getByRole('button', { name: 'Salvar agora' }).click();
  await expect(page.getByRole('status')).toContainText('Rascunho salvo');
  await page.getByLabel('Arquivo').setInputFiles({
    name: 'pauta-etapa-cinco.pdf',
    mimeType: 'application/pdf',
    buffer: Buffer.from('%PDF-1.4\n% evidencia da etapa cinco\n'),
  });
  const uploadResponse = page.waitForResponse(
    (response) => response.url().includes('/arquivos') && response.request().method() === 'POST',
  );
  await page.getByRole('button', { name: 'Enviar arquivo' }).click();
  expect((await uploadResponse).status()).toBe(201);
  await page.getByLabel(/Li e aceito os termos/).check();
  const submissionResponse = page.waitForResponse(
    (response) => response.url().includes('/enviar') && response.request().method() === 'POST',
  );
  await page.getByRole('button', { name: 'Enviar para revisão' }).click();
  const submitted = await submissionResponse;
  expect(submitted.status(), await submitted.text()).toBe(200);
  await expect(page.getByText('Submissão enviada para revisão.')).toBeVisible();

  await page.goto('/admin');
  await expect(
    page.getByRole('heading', { name: 'Esta história não pousou por aqui.' }),
  ).toBeVisible();
  await page.goto('/submissoes');
  await signOut(page);

  await signIn(page, 'revisor@local.canarinho.test', '/admin/revisao');
  await page.getByRole('link', { name: uniqueTitle }).click();
  const assignment = actionForm(page, 'Assumir revisão');
  await assignment.getByLabel('Motivo da atribuição').fill('Distribuição da fila de revisão');
  await assignment.getByRole('button', { name: 'Assumir revisão' }).click();
  await expect(page.getByText('Responsável pela revisão atualizado.')).toBeVisible();

  await page
    .getByLabel(/Comentário geral na versão/)
    .fill('Parecer geral registrado na versão submetida.');
  await page.getByRole('button', { name: 'Registrar comentário' }).click();
  await expect(page.getByText('Comentário editorial registrado na versão.')).toBeVisible();
  const approval = actionForm(page, 'Aprovar para edição');
  await approval.getByLabel('Justificativa').fill('Texto aprovado após a revisão editorial');
  await approval.getByRole('button', { name: 'Aprovar para edição' }).click();
  await expect(page.getByText('Status editorial atualizado.')).toBeVisible();
  await signOut(page);

  await signIn(page, 'editor@local.canarinho.test', '/admin/editorial');
  await page.getByRole('link', { name: uniqueTitle }).click();
  const startEditing = actionForm(page, 'Assumir edição final');
  await startEditing.getByLabel('Justificativa').fill('Preparação final para o portal');
  await startEditing.getByRole('button', { name: 'Assumir edição final' }).click();
  await expect(page.getByText('Status editorial atualizado.')).toBeVisible();

  await page.getByLabel('Tempo de leitura (minutos)').fill('3');
  await page.getByLabel('Capa pública').selectOption({ index: 1 });
  await page.getByLabel('Título SEO').fill(uniqueTitle.slice(0, 70));
  await page
    .getByLabel('Descrição SEO')
    .fill('Pauta validada pelo fluxo de revisão, edição e publicação do Canarinho.');
  await page.getByLabel('Motivo da edição').fill('Metadados e acabamento editorial concluídos');
  await page.getByRole('button', { name: 'Salvar versão editorial' }).click();
  await expect(page.getByText('Edição salva e versionada.')).toBeVisible();

  const publication = actionForm(page, 'Publicar agora');
  await publication.getByLabel('Justificativa').fill('Conteúdo completo e pronto para publicação');
  await publication.getByRole('button', { name: 'Publicar agora' }).click();
  await expect(page.getByText('Status editorial atualizado.')).toBeVisible();
  await expect(page.locator('.status-pill').getByText('Publicada', { exact: true })).toBeVisible();

  const hero = actionForm(page, 'Tornar destaque principal');
  await hero.getByLabel('Motivo da curadoria').fill('Principal pauta desta janela editorial');
  await hero.getByRole('button', { name: 'Tornar destaque principal' }).click();
  await expect(page.getByText('Destaque principal atualizado.')).toBeVisible();

  await page.goto('/');
  await expect(page.getByRole('heading', { name: uniqueTitle })).toBeVisible();
});
