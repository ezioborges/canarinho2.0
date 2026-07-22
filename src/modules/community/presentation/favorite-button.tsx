import { setFavoriteAction } from '../application/community-actions';

export function FavoriteButton({
  contentId,
  slug,
  favorite,
  authenticated,
}: {
  contentId: string;
  slug: string;
  favorite: boolean;
  authenticated: boolean;
}) {
  return (
    <form action={setFavoriteAction}>
      <input type="hidden" name="contentId" value={contentId} />
      <input type="hidden" name="slug" value={slug} />
      <input type="hidden" name="favorite" value={String(!favorite)} />
      <button className="button button--secondary" type="submit">
        {authenticated
          ? favorite
            ? 'Remover dos favoritos'
            : 'Salvar nos favoritos'
          : 'Entrar para favoritar'}
      </button>
    </form>
  );
}
