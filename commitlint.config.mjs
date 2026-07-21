const commitlintConfig = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'header-max-length': [2, 'always', 100],
    'scope-enum': [
      2,
      'always',
      [
        'admin',
        'analytics',
        'ci',
        'community',
        'communications',
        'deps',
        'docs',
        'editorial',
        'identity',
        'media',
        'organization',
        'portal',
        'shared',
        'supabase',
        'taxonomy',
      ],
    ],
  },
};

export default commitlintConfig;
