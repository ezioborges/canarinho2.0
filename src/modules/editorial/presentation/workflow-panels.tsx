import { setPrimaryHeroAction, transitionEditorialAction } from '../application/editorial-actions';
import { availableEditorialActions, type EditorialRole } from '../domain/workflow';
import type { EditorialStatus } from '../domain/submission';

const feedbackMessages: Record<string, string> = {
  revisao_atribuida: 'Responsável pela revisão atualizado.',
  comentario_adicionado: 'Comentário editorial registrado na versão.',
  status_atualizado: 'Status editorial atualizado.',
  edicao_salva: 'Edição salva e versionada.',
  versao_restaurada: 'Versão restaurada com ponto de retorno preservado.',
  destaque_atualizado: 'Destaque principal atualizado.',
  stale_content_version: 'Outra pessoa alterou esta matéria. Recarregue antes de tentar novamente.',
  reviewer_cannot_approve_own_content: 'Revisores não podem aprovar a própria matéria.',
  content_missing_publication_requirements:
    'Faltam categoria, autoria, SEO, capa pública com texto alternativo ou conteúdo.',
  editorial_transition_not_allowed:
    'Essa transição não é permitida para seu papel ou estado atual.',
  editor_is_not_responsible: 'A edição está atribuída a outra pessoa.',
  future_schedule_required: 'Escolha uma data e hora futura.',
  operacao_nao_concluida: 'Não foi possível concluir a operação.',
  transicao_invalida: 'Revise a justificativa e os dados da transição.',
  comentario_invalido: 'Escreva um comentário com ao menos três caracteres.',
  edicao_invalida: 'Revise os campos da edição final.',
  conteudo_invalido: 'O documento editorial está inválido.',
  restauracao_invalida: 'Não foi possível validar a restauração.',
};

export function WorkflowFeedback({
  success,
  error,
}: {
  success: string | undefined;
  error: string | undefined;
}) {
  const code = success ?? error;
  if (!code) return null;
  return (
    <p className={`form-message ${error ? 'form-message--error' : 'form-message--success'}`}>
      {feedbackMessages[code] ?? feedbackMessages.operacao_nao_concluida}
    </p>
  );
}

function TransitionForm({
  contentId,
  lockVersion,
  area,
  status,
  label,
  schedule = false,
  directorException = false,
}: {
  contentId: string;
  lockVersion: number;
  area: 'revisao' | 'editorial';
  status: EditorialStatus;
  label: string;
  schedule?: boolean;
  directorException?: boolean;
}) {
  return (
    <form className="workflow-action" action={transitionEditorialAction}>
      <input type="hidden" name="contentId" value={contentId} />
      <input type="hidden" name="lockVersion" value={lockVersion} />
      <input type="hidden" name="area" value={area} />
      <input type="hidden" name="status" value={status} />
      <input type="hidden" name="directorException" value={String(directorException)} />
      {schedule ? (
        <label>
          Data e hora de publicação
          <input name="schedule" type="datetime-local" required />
        </label>
      ) : null}
      <label>
        Justificativa
        <textarea name="justification" minLength={3} maxLength={2000} rows={2} required />
      </label>
      <button className="button button--secondary" type="submit">
        {label}
      </button>
    </form>
  );
}

export function ReviewTransitions({
  contentId,
  lockVersion,
  status,
  roles,
}: {
  contentId: string;
  lockVersion: number;
  status: EditorialStatus;
  roles: EditorialRole[];
}) {
  const actions = availableEditorialActions(status, roles);
  return (
    <div className="workflow-actions">
      {actions.includes('request_changes') ? (
        <TransitionForm
          contentId={contentId}
          lockVersion={lockVersion}
          area="revisao"
          status="changes_requested"
          label="Solicitar ajustes"
        />
      ) : null}
      {actions.includes('approve') ? (
        <TransitionForm
          contentId={contentId}
          lockVersion={lockVersion}
          area="revisao"
          status="approved"
          label="Aprovar para edição"
        />
      ) : null}
      {actions.includes('reject') ? (
        <TransitionForm
          contentId={contentId}
          lockVersion={lockVersion}
          area="revisao"
          status="rejected"
          label="Rejeitar submissão"
        />
      ) : null}
      {actions.includes('reopen') ? (
        <TransitionForm
          contentId={contentId}
          lockVersion={lockVersion}
          area="revisao"
          status="submitted"
          label="Reabrir submissão"
        />
      ) : null}
    </div>
  );
}

export function EditorTransitions({
  contentId,
  lockVersion,
  status,
  roles,
}: {
  contentId: string;
  lockVersion: number;
  status: EditorialStatus;
  roles: EditorialRole[];
}) {
  const actions = availableEditorialActions(status, roles);
  return (
    <div className="workflow-actions">
      {actions.includes('start_editing') ? (
        <TransitionForm
          contentId={contentId}
          lockVersion={lockVersion}
          area="editorial"
          status="in_editing"
          label="Assumir edição final"
        />
      ) : null}
      {actions.includes('cancel_schedule') ? (
        <TransitionForm
          contentId={contentId}
          lockVersion={lockVersion}
          area="editorial"
          status="in_editing"
          label="Cancelar agendamento"
        />
      ) : null}
      {actions.includes('schedule') ? (
        <TransitionForm
          contentId={contentId}
          lockVersion={lockVersion}
          area="editorial"
          status="scheduled"
          label="Agendar publicação"
          schedule
        />
      ) : null}
      {actions.includes('publish') ? (
        <TransitionForm
          contentId={contentId}
          lockVersion={lockVersion}
          area="editorial"
          status="published"
          label="Publicar agora"
        />
      ) : null}
      {actions.includes('archive') ? (
        <TransitionForm
          contentId={contentId}
          lockVersion={lockVersion}
          area="editorial"
          status="archived"
          label="Arquivar"
        />
      ) : null}
      {actions.includes('republish') ? (
        <TransitionForm
          contentId={contentId}
          lockVersion={lockVersion}
          area="editorial"
          status="published"
          label="Republicar"
        />
      ) : null}
      {actions.includes('director_publish') ? (
        <TransitionForm
          contentId={contentId}
          lockVersion={lockVersion}
          area="editorial"
          status="published"
          label="Publicar por exceção da Direção"
          directorException
        />
      ) : null}
      {status === 'published' ? (
        <form className="workflow-action" action={setPrimaryHeroAction}>
          <input type="hidden" name="contentId" value={contentId} />
          <label>
            Motivo da curadoria
            <textarea name="justification" minLength={3} maxLength={2000} rows={2} required />
          </label>
          <button className="button button--secondary" type="submit">
            Tornar destaque principal
          </button>
        </form>
      ) : null}
    </div>
  );
}
