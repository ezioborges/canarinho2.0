import {
  cancelCampaignAction,
  changeNoticeStatusAction,
  getCommunicationsAdmin,
  inactivateSubscriberAction,
  requestNewsletterExportAction,
  retryCampaignAction,
  saveCampaignAction,
  saveNoticeAction,
  scheduleCampaignAction,
  setNoticePinnedAction,
} from '@/modules/communications';

function single(value: string | string[] | undefined) {
  return Array.isArray(value) ? value[0] : value;
}

function localDateTime(value: string | null) {
  if (!value) return '';
  const date = new Date(value);
  return new Date(date.getTime() - date.getTimezoneOffset() * 60_000).toISOString().slice(0, 16);
}

export default async function CommunicationsAdminPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const [admin, query] = await Promise.all([getCommunicationsAdmin(), searchParams]);
  return (
    <main id="conteudo-principal" className="editor-page communications-admin-page">
      <header className="page-intro">
        <p className="eyebrow">Conexões</p>
        <h1>Informes e Carta do Canarinho</h1>
        <p>Comunicação consentida, entregas retomáveis e decisões sensíveis auditadas.</p>
      </header>
      {single(query.sucesso) ? (
        <p className="form-message form-message--success">{single(query.sucesso)}</p>
      ) : null}
      {single(query.erro) ? (
        <p className="form-message form-message--error">{single(query.erro)}</p>
      ) : null}

      <section className="admin-section" aria-labelledby="notices-admin-title">
        <h2 id="notices-admin-title">Informes</h2>
        <div className="communications-grid">
          {admin.notices.map((notice) => (
            <article className="moderation-card" key={notice.id}>
              <header>
                <h3>{notice.title}</h3>
                <span className="status-pill">{notice.status}</span>
              </header>
              <p>{notice.summary}</p>
              <details>
                <summary>Editar informe</summary>
                <form className="communications-form" action={saveNoticeAction}>
                  <input type="hidden" name="noticeId" value={notice.id} />
                  <label>
                    Título
                    <input name="title" defaultValue={notice.title} required />
                  </label>
                  <label>
                    Slug
                    <input name="slug" defaultValue={notice.slug} required />
                  </label>
                  <label>
                    Resumo
                    <textarea name="summary" defaultValue={notice.summary} required />
                  </label>
                  <label>
                    Texto
                    <textarea name="body" defaultValue={notice.body} required />
                  </label>
                  <label>
                    Público
                    <select name="audience" defaultValue={notice.audience}>
                      <option value="general">Geral</option>
                      <option value="students">Estudantes</option>
                      <option value="team">Equipe</option>
                      <option value="authors">Autores</option>
                      <option value="visitors">Visitantes</option>
                    </select>
                  </label>
                  <label>
                    Expira em
                    <input
                      name="expiresAt"
                      type="datetime-local"
                      defaultValue={localDateTime(notice.expires_at)}
                    />
                  </label>
                  <label className="checkbox-field">
                    <input
                      name="commentsEnabled"
                      type="checkbox"
                      defaultChecked={notice.comments_enabled}
                    />
                    <span>Permitir comentários autenticados</span>
                  </label>
                  <button className="button button--secondary" type="submit">
                    Salvar informe
                  </button>
                </form>
              </details>
              {notice.status !== 'archived' ? (
                <div className="command-row">
                  {notice.status === 'draft' ? (
                    <form action={changeNoticeStatusAction}>
                      <input type="hidden" name="noticeId" value={notice.id} />
                      <input type="hidden" name="action" value="publish" />
                      <label>
                        Motivo para publicar
                        <input name="reason" minLength={3} required />
                      </label>
                      <button className="button button--primary" type="submit">
                        Publicar
                      </button>
                    </form>
                  ) : (
                    <form action={setNoticePinnedAction}>
                      <input type="hidden" name="noticeId" value={notice.id} />
                      <input type="hidden" name="pinned" value={notice.pinned ? 'false' : 'true'} />
                      <label>
                        Motivo do destaque
                        <input name="reason" minLength={3} required />
                      </label>
                      <button className="button button--secondary" type="submit">
                        {notice.pinned ? 'Desafixar' : 'Fixar'}
                      </button>
                    </form>
                  )}
                  <form action={changeNoticeStatusAction}>
                    <input type="hidden" name="noticeId" value={notice.id} />
                    <input type="hidden" name="action" value="archive" />
                    <label>
                      Motivo para arquivar
                      <input name="reason" minLength={3} required />
                    </label>
                    <button className="button button--text" type="submit">
                      Arquivar
                    </button>
                  </form>
                </div>
              ) : null}
            </article>
          ))}
        </div>
        <form className="account-card communications-form" action={saveNoticeAction}>
          <h3>Novo informe</h3>
          <input type="hidden" name="noticeId" value="" />
          <label>
            Título
            <input name="title" minLength={3} maxLength={180} required />
          </label>
          <label>
            Slug
            <input name="slug" pattern="[a-z0-9]+(?:-[a-z0-9]+)*" required />
          </label>
          <label>
            Resumo
            <textarea name="summary" minLength={10} maxLength={500} required />
          </label>
          <label>
            Texto
            <textarea name="body" minLength={10} maxLength={10000} required />
          </label>
          <label>
            Público
            <select name="audience">
              <option value="general">Geral</option>
              <option value="students">Estudantes</option>
              <option value="team">Equipe</option>
              <option value="authors">Autores</option>
              <option value="visitors">Visitantes</option>
            </select>
          </label>
          <label>
            Expira em
            <input name="expiresAt" type="datetime-local" />
          </label>
          <label className="checkbox-field">
            <input name="commentsEnabled" type="checkbox" />
            <span>Permitir comentários</span>
          </label>
          <button className="button button--primary" type="submit">
            Salvar rascunho
          </button>
        </form>
      </section>

      <section className="admin-section" aria-labelledby="campaigns-title">
        <div className="section-heading">
          <div>
            <p className="eyebrow">Newsletter</p>
            <h2 id="campaigns-title">Campanhas</h2>
          </div>
          <form action="/api/comunicacoes/processar" method="post">
            <button className="button button--secondary" type="submit">
              Processar fila agora
            </button>
          </form>
        </div>
        <div className="communications-grid">
          {admin.campaigns.map((campaign) => {
            const counts = campaign.newsletter_deliveries.reduce<Record<string, number>>(
              (result, delivery) => ({
                ...result,
                [delivery.status]: (result[delivery.status] ?? 0) + 1,
              }),
              {},
            );
            return (
              <article className="moderation-card" key={campaign.id}>
                <header>
                  <h3>{campaign.name}</h3>
                  <span className="status-pill">{campaign.status}</span>
                </header>
                <p>
                  <strong>{campaign.subject}</strong>
                </p>
                <p>
                  Entregas:{' '}
                  {Object.entries(counts)
                    .map(([status, count]) => `${status} ${count}`)
                    .join(' · ') || 'ainda não preparadas'}
                </p>
                {campaign.status === 'draft' ? (
                  <>
                    <details>
                      <summary>Editar campanha</summary>
                      <form className="communications-form" action={saveCampaignAction}>
                        <input type="hidden" name="campaignId" value={campaign.id} />
                        <label>
                          Nome interno
                          <input name="name" defaultValue={campaign.name} required />
                        </label>
                        <label>
                          Assunto
                          <input name="subject" defaultValue={campaign.subject} required />
                        </label>
                        <label>
                          Prévia
                          <input name="previewText" defaultValue={campaign.preview_text ?? ''} />
                        </label>
                        <label>
                          Mensagem
                          <textarea name="bodyText" defaultValue={campaign.body_text} required />
                        </label>
                        <label>
                          Segmento
                          <select name="segment" defaultValue={campaign.segment}>
                            <option value="all">Todos ativos</option>
                            <option value="students">Estudantes</option>
                            <option value="authors">Autores</option>
                          </select>
                        </label>
                        <button className="button button--secondary" type="submit">
                          Salvar campanha
                        </button>
                      </form>
                    </details>
                    <form className="communications-form" action={scheduleCampaignAction}>
                      <input type="hidden" name="campaignId" value={campaign.id} />
                      <label>
                        Agendar para
                        <input name="scheduledAt" type="datetime-local" required />
                      </label>
                      <label>
                        Motivo
                        <input name="reason" minLength={3} required />
                      </label>
                      <button className="button button--primary" type="submit">
                        Agendar
                      </button>
                    </form>
                  </>
                ) : null}
                {campaign.status === 'failed' || campaign.status === 'sending' ? (
                  <form className="communications-form" action={retryCampaignAction}>
                    <input type="hidden" name="campaignId" value={campaign.id} />
                    <label>
                      Motivo do retry
                      <input name="reason" minLength={3} required />
                    </label>
                    <button className="button button--secondary" type="submit">
                      Retomar somente falhas
                    </button>
                  </form>
                ) : null}
                {['draft', 'scheduled', 'sending', 'failed'].includes(campaign.status) ? (
                  <form className="communications-form" action={cancelCampaignAction}>
                    <input type="hidden" name="campaignId" value={campaign.id} />
                    <label>
                      Motivo do cancelamento
                      <input name="reason" minLength={3} required />
                    </label>
                    <button className="button button--text" type="submit">
                      Cancelar campanha
                    </button>
                  </form>
                ) : null}
              </article>
            );
          })}
        </div>
        <form className="account-card communications-form" action={saveCampaignAction}>
          <h3>Nova campanha</h3>
          <input type="hidden" name="campaignId" value="" />
          <label>
            Nome interno
            <input name="name" minLength={3} required />
          </label>
          <label>
            Assunto
            <input name="subject" minLength={3} required />
          </label>
          <label>
            Prévia
            <input name="previewText" maxLength={240} />
          </label>
          <label>
            Mensagem
            <textarea name="bodyText" minLength={10} required />
          </label>
          <label>
            Segmento
            <select name="segment">
              <option value="all">Todos ativos</option>
              <option value="students">Estudantes</option>
              <option value="authors">Autores</option>
            </select>
          </label>
          <button className="button button--primary" type="submit">
            Criar rascunho
          </button>
        </form>
      </section>

      <section className="admin-section" aria-labelledby="subscribers-title">
        <h2 id="subscribers-title">Inscritos e consentimentos</h2>
        <div
          className="subscriber-table"
          role="region"
          aria-label="Lista de inscritos"
          tabIndex={0}
        >
          <table>
            <thead>
              <tr>
                <th>Email</th>
                <th>Status</th>
                <th>Consentimento</th>
                <th>Ação</th>
              </tr>
            </thead>
            <tbody>
              {admin.subscribers.map((subscriber) => (
                <tr key={subscriber.id}>
                  <td>{subscriber.email}</td>
                  <td>{subscriber.status}</td>
                  <td>
                    {subscriber.consent_version}
                    <br />
                    <small>{new Date(subscriber.consented_at).toLocaleString('pt-BR')}</small>
                  </td>
                  <td>
                    {subscriber.status === 'active' ? (
                      <form action={inactivateSubscriberAction}>
                        <input type="hidden" name="subscriberId" value={subscriber.id} />
                        <label className="sr-only" htmlFor={`reason-${subscriber.id}`}>
                          Motivo
                        </label>
                        <input
                          id={`reason-${subscriber.id}`}
                          name="reason"
                          placeholder="Motivo"
                          minLength={3}
                          required
                        />
                        <button className="button button--text" type="submit">
                          Inativar
                        </button>
                      </form>
                    ) : null}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      {admin.isDirector ? (
        <section className="admin-section" aria-labelledby="exports-title">
          <h2 id="exports-title">Exportações protegidas</h2>
          <p>Arquivos são privados, auditados e expiram em 24 horas.</p>
          <form className="communications-form" action={requestNewsletterExportAction}>
            <label>
              Finalidade da exportação
              <input name="reason" minLength={3} required />
            </label>
            <button className="button button--secondary" type="submit">
              Solicitar CSV
            </button>
          </form>
          <ul className="export-list">
            {admin.exports.map((item) => (
              <li key={item.id}>
                <span>
                  {new Date(item.created_at).toLocaleString('pt-BR')} · {item.status} ·{' '}
                  {item.row_count ?? 0} linhas
                </span>
                {item.status === 'ready' &&
                item.expires_at &&
                new Date(item.expires_at) > new Date() ? (
                  <a
                    className="button button--text"
                    href={`/api/comunicacoes/exportacoes/${item.id}`}
                  >
                    Baixar
                  </a>
                ) : null}
              </li>
            ))}
          </ul>
        </section>
      ) : null}
    </main>
  );
}
