import type { NextConfig } from 'next';
import path from 'node:path';
const config: NextConfig = {
  turbopack: { root: path.resolve(import.meta.dirname, '../..') },
  poweredByHeader: false,
  reactStrictMode: true,
  experimental: { typedRoutes: false }
};
export default config;
