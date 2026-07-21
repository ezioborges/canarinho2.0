import { defineConfig, globalIgnores } from 'eslint/config';
import nextCoreWebVitals from 'eslint-config-next/core-web-vitals';
import nextTypeScript from 'eslint-config-next/typescript';
import { flatConfigs as importXFlatConfigs } from 'eslint-plugin-import-x';

const restrictedDeepImport = {
  group: [
    '@/modules/*/!(index|client|server|contracts)',
    '@/modules/**/!(index|client|server|contracts)',
  ],
  message:
    'Outro modulo deve ser consumido somente por uma API publica: index, client, server ou contracts.',
};

export default defineConfig([
  ...nextCoreWebVitals,
  ...nextTypeScript,
  importXFlatConfigs.recommended,
  importXFlatConfigs.typescript,
  {
    files: ['**/*.{js,mjs,ts,tsx}'],
    settings: {
      'import-x/resolver': {
        typescript: {
          project: './tsconfig.json',
        },
      },
    },
    rules: {
      '@typescript-eslint/consistent-type-imports': [
        'error',
        { fixStyle: 'inline-type-imports', prefer: 'type-imports' },
      ],
      'import-x/first': 'error',
      'import-x/newline-after-import': 'error',
      'import-x/no-cycle': 'error',
      'import-x/no-duplicates': 'error',
      'import-x/no-restricted-paths': [
        'error',
        {
          basePath: '.',
          zones: [
            {
              target: './src/modules',
              from: './src/app',
              message: 'Modulos de dominio nao podem depender de rotas Next.js.',
            },
            {
              target: './src/shared',
              from: './src/app',
              message: 'Codigo compartilhado nao pode depender de rotas Next.js.',
            },
            {
              target: './src/shared',
              from: './src/modules',
              message: 'Codigo compartilhado nao pode depender de modulos de negocio.',
            },
          ],
        },
      ],
      'no-restricted-imports': ['error', { patterns: [restrictedDeepImport] }],
    },
  },
  {
    files: ['src/modules/**'],
    rules: {
      'no-restricted-imports': [
        'error',
        {
          patterns: [
            restrictedDeepImport,
            {
              group: ['@/app/**'],
              message: 'Modulos de dominio nao podem importar rotas Next.js.',
            },
          ],
        },
      ],
    },
  },
  globalIgnores([
    '.next/**',
    'coverage/**',
    'node_modules/**',
    'supabase/functions/**',
    'aula-lockfile/**',
    'canarinho-aula-monorepo/**',
    'scripts/**',
  ]),
]);
