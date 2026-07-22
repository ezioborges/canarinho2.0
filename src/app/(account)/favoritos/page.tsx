import { listOwnFavorites } from '@/modules/community';
import { ContentGrid } from '@/modules/public-portal';

export default async function FavoritesPage() {
  const favorites = await listOwnFavorites();
  return (
    <main id="conteudo-principal" className="account-page">
      <header className="page-intro">
        <p className="eyebrow">Sua coleção</p>
        <h1>Favoritos</h1>
        <p>Matérias, poemas e imagens que você quer encontrar de novo.</p>
      </header>
      <ContentGrid contents={favorites} emptyDescription="Você ainda não salvou nenhum conteúdo." />
    </main>
  );
}
