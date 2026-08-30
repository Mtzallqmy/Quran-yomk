import type { NextConfig } from 'next';
const config: NextConfig = {
  poweredByHeader: false,
  reactStrictMode: true,
  experimental: { typedRoutes: false }
};
export default config;
