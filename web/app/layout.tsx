import type { Metadata } from 'next';
import { Inter } from 'next/font/google';
import './globals.css';

const inter = Inter({ subsets: ['latin'] });

export const metadata: Metadata = {
  title: 'KiloShare - Partagez vos espaces bagages',
  description: 'La plateforme de partage d\'espace bagages qui connecte voyageurs et expéditeurs pour des transports plus économiques et écologiques.',
  keywords: ['bagages', 'voyage', 'transport', 'économique', 'écologique', 'partage'],
  authors: [{ name: 'KiloShare Team' }],
  viewport: 'width=device-width, initial-scale=1',
  robots: 'index, follow',
  openGraph: {
    title: 'KiloShare - Partagez vos espaces bagages',
    description: 'Connectez voyageurs et expéditeurs pour des transports plus économiques et écologiques.',
    type: 'website',
    url: process.env.NEXT_PUBLIC_APP_URL,
    siteName: 'KiloShare',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'KiloShare - Partagez vos espaces bagages',
    description: 'Connectez voyageurs et expéditeurs pour des transports plus économiques et écologiques.',
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="fr">
      <body className={inter.className}>
        <main className="min-h-screen">
          {children}
        </main>
      </body>
    </html>
  );
}