import type { PublicContentCard } from '../domain/content';
import { ContentCard } from './content-card';

type ContentGridProperties = {
  contents: PublicContentCard[];
  emptyDescription?: string;
};

export function ContentGrid({
  contents,
  emptyDescription = 'Nenhum conteúdo publicado corresponde aos filtros escolhidos.',
}: ContentGridProperties) {
  if (contents.length === 0) {
    return (
      <div className="empty-state" role="status">
        <span aria-hidden="true">○</span>
        <h2>Nada por aqui ainda</h2>
        <p>{emptyDescription}</p>
      </div>
    );
  }

  return (
    <div className="content-grid">
      {contents.map((content) => (
        <ContentCard key={content.id} content={content} />
      ))}
    </div>
  );
}
