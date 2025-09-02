'use client';

import React, { useEffect, useState } from 'react';
import { useRouter, usePathname } from 'next/navigation';
import AdminHeader from '../../components/admin/AdminHeader';
import AdminSidebar from '../../components/admin/AdminSidebar';
import AdminAuthDebug from '../../components/admin/AdminAuthDebug';
import { useAdminAuthStore } from '../../stores/adminAuthStore';
import { useClientOnly } from '../../hooks/useClientOnly';

interface AdminUser {
  id: number;
  email: string;
  role: string;
  first_name?: string;
  last_name?: string;
}

export default function AdminLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const router = useRouter();
  const pathname = usePathname();
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const mounted = useClientOnly(100);

  const { 
    user, 
    isAuthenticated, 
    isLoading, 
    checkAuth, 
    logout 
  } = useAdminAuthStore();

  useEffect(() => {
    // Wait for hydration
    if (!mounted) return;
    
    console.log('🏠 Admin Layout: pathname =', pathname, 'isAuthenticated =', isAuthenticated, 'isLoading =', isLoading);
    
    // ONLY redirect to login if we're on a protected page and definitely NOT authenticated
    if (pathname !== '/admin/login' && !isAuthenticated && !isLoading) {
      // Check for token first before redirecting
      const hasToken = (
        localStorage.getItem('admin_token') ||
        sessionStorage.getItem('admin_token') ||
        document.cookie.includes('admin_token=')
      );
      
      console.log('🔍 Layout check: hasToken =', hasToken);
      
      if (!hasToken) {
        console.log('❌ No token found, redirecting to login');
        router.replace('/admin/login');
      } else {
        console.log('✅ Token found, checking auth...');
        checkAuth();
      }
    }
  }, [pathname, isAuthenticated, isLoading, checkAuth, router, mounted]);

  const handleLogout = () => {
    logout();
    router.push('/admin/login');
  };

  // Si on est sur la page de login, afficher seulement le contenu
  if (pathname === '/admin/login') {
    return (
      <div className="min-h-screen bg-gray-100">
        {children}
        <AdminAuthDebug />
      </div>
    );
  }

  // Écran de chargement
  if (isLoading) {
    return (
      <div className="min-h-screen bg-gray-100 flex items-center justify-center">
        <div className="animate-spin rounded-full h-8 w-8 border-2 border-blue-600 border-t-transparent"></div>
      </div>
    );
  }

  // Si pas d'utilisateur authentifié, ne rien afficher (la redirection va s'effectuer)
  if (!isAuthenticated || !user) {
    return null;
  }

  return (
    <div className="min-h-screen bg-gray-100">
      {/* Header Admin */}
      <AdminHeader 
        user={user} 
        onLogout={handleLogout}
        onToggleSidebar={() => setSidebarOpen(!sidebarOpen)}
      />

      <div className="flex">
        {/* Sidebar */}
        <AdminSidebar 
          isOpen={sidebarOpen}
          onClose={() => setSidebarOpen(false)}
        />

        {/* Main Content */}
        <main className={`flex-1 transition-all duration-300 ${sidebarOpen ? 'ml-64' : 'ml-16'} pt-16`}>
          <div className="p-6">
            {children}
          </div>
        </main>
      </div>

      {/* Mobile Sidebar Overlay */}
      {sidebarOpen && (
        <div 
          className="fixed inset-0 bg-black bg-opacity-50 z-20 lg:hidden"
          onClick={() => setSidebarOpen(false)}
        />
      )}
      
      <AdminAuthDebug />
    </div>
  );
}