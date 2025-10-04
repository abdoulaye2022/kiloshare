/** @type {import('next').NextConfig} */
const nextConfig = {
  images: {
    domains: ['localhost', 'm2atodev.com', 'kiloshare.com'],
  },
  async rewrites() {
    const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080';
    return [
      {
        source: '/api/:path*',
        destination: `${apiUrl}/api/:path*`,
      },
    ];
  },
};

module.exports = nextConfig;