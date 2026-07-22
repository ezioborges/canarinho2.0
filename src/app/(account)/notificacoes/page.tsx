import Link from 'next/link';
import type { Route } from 'next';

import { listOwnNotifications, markNotificationReadAction } from '@/modules/communications';

export default async function NotificationsPage() {
  const notifications = await listOwnNotifications();
  return (
    <main id="conteudo-principal" className="account-page">
      <header className="page-intro">
        <p className="eyebrow">Sua conta</p>
        <h1>Notificações</h1>
        <p>Atualizações editoriais criadas fora do caminho crítico das suas ações.</p>
      </header>
      <div className="notification-list">
        {notifications.map((notification) => (
          <article
            className={`account-card${notification.read_at ? '' : ' notification--unread'}`}
            key={notification.id}
          >
            <h2>{notification.title}</h2>
            <p>{notification.body}</p>
            <time dateTime={notification.created_at}>
              {new Date(notification.created_at).toLocaleString('pt-BR')}
            </time>
            <div>
              {notification.href ? (
                <Link href={notification.href as Route}>Abrir atualização</Link>
              ) : null}
              {!notification.read_at ? (
                <form action={markNotificationReadAction}>
                  <input type="hidden" name="notificationId" value={notification.id} />
                  <button className="button button--text" type="submit">
                    Marcar como lida
                  </button>
                </form>
              ) : null}
            </div>
          </article>
        ))}
        {!notifications.length ? (
          <p className="empty-state">Nenhuma notificação por enquanto.</p>
        ) : null}
      </div>
    </main>
  );
}
