import type { NextConfig } from 'next';

import {
  parsePublicEnvironment,
  parseServerEnvironment,
} from './src/shared/config/environment.schema';

parsePublicEnvironment(process.env);
parseServerEnvironment(process.env);

const nextConfig: NextConfig = {
  poweredByHeader: false,
  reactStrictMode: true,
  typedRoutes: true,
};

export default nextConfig;
