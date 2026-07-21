import type { ReactNode } from 'react';

import type { RichTextDocument, RichTextNode } from '../domain/content';

type RichTextProperties = {
  document: RichTextDocument;
};

function safeLink(href: string | undefined): string | null {
  if (!href) return null;

  try {
    const parsed = new URL(href, 'https://canarinho.invalid');
    return ['http:', 'https:', 'mailto:'].includes(parsed.protocol) ? href : null;
  } catch {
    return null;
  }
}

function renderChildren(node: RichTextNode, keyPrefix: string): ReactNode[] {
  return (node.content ?? []).map((child, index) => renderNode(child, `${keyPrefix}-${index}`));
}

function renderText(node: RichTextNode, key: string): ReactNode {
  let rendered: ReactNode = node.text ?? '';

  for (const mark of node.marks ?? []) {
    if (mark.type === 'bold') rendered = <strong>{rendered}</strong>;
    if (mark.type === 'italic') rendered = <em>{rendered}</em>;
    if (mark.type === 'link') {
      const href = safeLink(mark.attrs?.href);
      if (href) rendered = <a href={href}>{rendered}</a>;
    }
  }

  return <span key={key}>{rendered}</span>;
}

function renderNode(node: RichTextNode, key: string): ReactNode {
  if (node.type === 'text') return renderText(node, key);

  const children = renderChildren(node, key);

  switch (node.type) {
    case 'paragraph':
      return <p key={key}>{children}</p>;
    case 'heading': {
      const level = Math.min(4, Math.max(2, node.attrs?.level ?? 2));
      if (level === 3) return <h3 key={key}>{children}</h3>;
      if (level === 4) return <h4 key={key}>{children}</h4>;
      return <h2 key={key}>{children}</h2>;
    }
    case 'blockquote':
      return <blockquote key={key}>{children}</blockquote>;
    case 'bulletList':
      return <ul key={key}>{children}</ul>;
    case 'orderedList':
      return <ol key={key}>{children}</ol>;
    case 'listItem':
      return <li key={key}>{children}</li>;
    case 'hardBreak':
      return <br key={key} />;
    default:
      return <span key={key}>{children}</span>;
  }
}

export function RichText({ document }: RichTextProperties) {
  return (
    <div className="article-body">
      {document.content.map((node, index) => renderNode(node, `body-${index}`))}
    </div>
  );
}
