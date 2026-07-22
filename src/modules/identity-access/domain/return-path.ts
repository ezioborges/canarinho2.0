export function safeReturnPath(value: FormDataEntryValue | string | null | undefined): string {
  if (typeof value !== 'string' || !value.startsWith('/') || value.startsWith('//')) {
    return '/submissoes';
  }

  try {
    const parsed = new URL(value, 'https://canarinho.invalid');
    return parsed.origin === 'https://canarinho.invalid'
      ? `${parsed.pathname}${parsed.search}${parsed.hash}`
      : '/submissoes';
  } catch {
    return '/submissoes';
  }
}
