'use client';

import type { Metadata } from 'next';
import { Inter } from 'next/font/google';
import { usePathname } from 'next/navigation';
import Navigation from '../components/Navigation';
import MobileBottomNav from '../components/MobileBottomNav';
import AdminStoreInitializer from '../components/admin/AdminStoreInitializer';
import './globals.css';

const inter = Inter({ subsets: ['latin'] });

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const pathname = usePathname();
  const isAdminPage = pathname?.startsWith('/admin');
  const isHomePage = pathname === '/';
  
  return (
    <html lang="fr">
      <body className={inter.className}>
        <AdminStoreInitializer />
        
        {!isAdminPage && !isHomePage && (
          <>
            {/* Navigation desktop */}
            <Navigation />
          </>
        )}
        
        <main className={!isAdminPage && !isHomePage ? "pb-16 md:pb-0" : ""}>
          {children}
        </main>
        
        {!isAdminPage && !isHomePage && (
          <>
            {/* Navigation mobile en bas */}
            <MobileBottomNav />
          </>
        )}
      </body>
    </html>
  );
}