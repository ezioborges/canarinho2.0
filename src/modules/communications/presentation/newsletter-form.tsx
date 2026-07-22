import { subscribeNewsletterAction } from '../application/communications-actions';

export function NewsletterForm({ returnPath = '/' }: { returnPath?: '/' | '/informes' }) {
  return (
    <form className="newsletter-form" action={subscribeNewsletterAction}>
      <input type="hidden" name="returnPath" value={returnPath} />
      <div className="honeypot" aria-hidden="true">
        <label>
          Website
          <input name="website" tabIndex={-1} autoComplete="off" />
        </label>
      </div>
      <label>
        Email
        <input name="email" type="email" autoComplete="email" required />
      </label>
      <label className="checkbox-field">
        <input name="consent" type="checkbox" required />
        <span>
          Quero receber a Carta do Canarinho e concordo com o uso do email para essa finalidade.
          Posso me descadastrar a qualquer momento.
        </span>
      </label>
      <button className="button button--primary" type="submit">
        Inscrever meu email
      </button>
      <small>Enviaremos uma mensagem para confirmar a inscrição.</small>
    </form>
  );
}
