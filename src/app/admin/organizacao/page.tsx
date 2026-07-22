import {
  archiveTeamMemberAction,
  getOrganizationAdmin,
  saveTeamMemberAction,
  updateRecruitmentApplicationAction,
} from '@/modules/organization';

function single(value: string | string[] | undefined) {
  return Array.isArray(value) ? value[0] : value;
}

export default async function OrganizationAdminPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const [admin, query] = await Promise.all([getOrganizationAdmin(), searchParams]);
  return (
    <main id="conteudo-principal" className="editor-page organization-admin-page">
      <header className="page-intro">
        <p className="eyebrow">Direção</p>
        <h1>Equipe e seleção</h1>
        <p>Gestão pública da equipe e tratamento privado das candidaturas.</p>
      </header>
      {single(query.sucesso) ? (
        <p className="form-message form-message--success">{single(query.sucesso)}</p>
      ) : null}
      {single(query.erro) ? (
        <p className="form-message form-message--error">{single(query.erro)}</p>
      ) : null}
      <section className="admin-section" aria-labelledby="team-management-title">
        <h2 id="team-management-title">Membros ativos</h2>
        <div className="admin-card-grid">
          {admin.members
            .filter((member) => member.active)
            .map((member) => (
              <article className="account-card" key={member.id}>
                <h3>{member.display_name}</h3>
                <p>{member.role_title}</p>
                <details>
                  <summary>Editar e ordenar</summary>
                  <form className="team-member-form" action={saveTeamMemberAction}>
                    <input type="hidden" name="memberId" value={member.id} />
                    <label>
                      Eixo
                      <select name="areaId" defaultValue={member.area_id} required>
                        {admin.areas.map((area) => (
                          <option key={area.id} value={area.id}>
                            {area.name}
                          </option>
                        ))}
                      </select>
                    </label>
                    <label>
                      Nome
                      <input name="name" defaultValue={member.display_name} required />
                    </label>
                    <label>
                      Função
                      <input name="roleTitle" defaultValue={member.role_title} required />
                    </label>
                    <label>
                      Bio
                      <textarea name="bio" defaultValue={member.bio ?? ''} maxLength={1000} />
                    </label>
                    <label>
                      Contato público
                      <input
                        name="publicContact"
                        defaultValue={member.public_contact ?? ''}
                        maxLength={200}
                      />
                    </label>
                    <label>
                      Posição
                      <input
                        name="position"
                        type="number"
                        min={1}
                        defaultValue={member.position}
                        required
                      />
                    </label>
                    <button className="button button--secondary" type="submit">
                      Salvar alterações
                    </button>
                  </form>
                </details>
                <form action={archiveTeamMemberAction}>
                  <input type="hidden" name="memberId" value={member.id} />
                  <label>
                    Motivo para inativar
                    <input name="reason" minLength={3} required />
                  </label>
                  <button className="button button--text" type="submit">
                    Inativar membro
                  </button>
                </form>
              </article>
            ))}
        </div>
        {admin.members.some((member) => !member.active) ? (
          <details className="account-card">
            <summary>Membros inativos</summary>
            <div className="admin-card-grid">
              {admin.members
                .filter((member) => !member.active)
                .map((member) => (
                  <form className="team-member-form" action={saveTeamMemberAction} key={member.id}>
                    <input type="hidden" name="memberId" value={member.id} />
                    <input type="hidden" name="areaId" value={member.area_id} />
                    <input type="hidden" name="name" value={member.display_name} />
                    <input type="hidden" name="roleTitle" value={member.role_title} />
                    <input type="hidden" name="bio" value={member.bio ?? ''} />
                    <input type="hidden" name="publicContact" value={member.public_contact ?? ''} />
                    <input type="hidden" name="position" value={member.position} />
                    <span>{member.display_name}</span>
                    <button className="button button--text" type="submit">
                      Reativar
                    </button>
                  </form>
                ))}
            </div>
          </details>
        ) : null}
        <form className="account-card team-member-form" action={saveTeamMemberAction}>
          <h3>Adicionar membro</h3>
          <input type="hidden" name="memberId" value="" />
          <label>
            Eixo
            <select name="areaId" required>
              {admin.areas.map((area) => (
                <option key={area.id} value={area.id}>
                  {area.name}
                </option>
              ))}
            </select>
          </label>
          <label>
            Nome
            <input name="name" minLength={2} maxLength={120} required />
          </label>
          <label>
            Função
            <input name="roleTitle" minLength={2} maxLength={120} required />
          </label>
          <label>
            Bio
            <textarea name="bio" maxLength={1000} />
          </label>
          <label>
            Contato público
            <input name="publicContact" maxLength={200} />
          </label>
          <label>
            Posição
            <input name="position" type="number" min={1} defaultValue={1} required />
          </label>
          <button className="button button--primary" type="submit">
            Salvar membro
          </button>
        </form>
      </section>
      <section className="admin-section" aria-labelledby="applications-title">
        <h2 id="applications-title">Candidaturas privadas</h2>
        <p>Os registros mostram a data de expiração prevista pela política de retenção.</p>
        <div className="moderation-list">
          {admin.applications.map((application) => (
            <article className="moderation-card" key={application.id}>
              <header>
                <h3>{application.applicant_name}</h3>
                <span className="status-pill">{application.status}</span>
              </header>
              <p>
                <a href={`mailto:${application.email}`}>{application.email}</a> ·{' '}
                {application.affiliation}
              </p>
              <p>{application.message}</p>
              <small>
                Excluir após{' '}
                {new Date(application.retention_expires_at).toLocaleDateString('pt-BR')}
              </small>
              <form className="moderation-form" action={updateRecruitmentApplicationAction}>
                <input type="hidden" name="applicationId" value={application.id} />
                <label>
                  Status
                  <select name="status" defaultValue={application.status}>
                    <option value="received">Recebida</option>
                    <option value="in_review">Em análise</option>
                    <option value="shortlisted">Pré-selecionada</option>
                    <option value="rejected">Não selecionada</option>
                    <option value="withdrawn">Retirada</option>
                  </select>
                </label>
                <label>
                  Parecer interno
                  <textarea
                    name="note"
                    minLength={3}
                    maxLength={2000}
                    required
                    defaultValue={application.internal_note ?? ''}
                  />
                </label>
                <button className="button button--secondary" type="submit">
                  Salvar parecer
                </button>
              </form>
            </article>
          ))}
          {!admin.applications.length ? (
            <div className="empty-state">
              <p>Nenhuma candidatura recebida.</p>
            </div>
          ) : null}
        </div>
      </section>
    </main>
  );
}
