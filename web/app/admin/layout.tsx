'use client';

import React, { useEffect, useState } from 'react';
import { useRouter, usePathname } from 'next/navigation';
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
    
    
    // ONLY redirect to login if we're on a protected page and definitely NOT authenticated
    if (pathname !== '/admin/login' && !isAuthenticated && !isLoading) {
      // Check for token first before redirecting
      const hasToken = (
        localStorage.getItem('admin_token') ||
        sessionStorage.getItem('admin_token') ||
        document.cookie.includes('admin_token=')
      );
      
      
      if (!hasToken) {
        router.replace('/admin/login');
      } else {
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
    return <div>{children}</div>;
  }

  // Écran de chargement
  if (isLoading) {
    return (
      <div className="min-vh-100 bg-light d-flex align-items-center justify-content-center">
        <div className="spinner-border text-primary" role="status">
          <span className="visually-hidden">Chargement...</span>
        </div>
      </div>
    );
  }

  // Si pas d'utilisateur authentifié, ne rien afficher (la redirection va s'effectuer)
  if (!isAuthenticated || !user) {
    return null;
  }

  const menuItems = [
    { href: '/admin/dashboard', icon: 'bi-speedometer2', label: 'Dashboard' },
    { href: '/admin/stats', icon: 'bi-bar-chart', label: 'Statistiques' },
    { href: '/admin/users', icon: 'bi-people', label: 'Utilisateurs' },
    { href: '/admin/trips', icon: 'bi-airplane', label: 'Voyages' },
    { href: '/admin/transactions', icon: 'bi-credit-card', label: 'Transactions' },
    { href: '/admin/stripe-accounts', icon: 'bi-shield-check', label: 'Comptes Stripe' },
    { href: '/admin/fund-transfers', icon: 'bi-arrow-left-right', label: 'Transferts de fonds' },
    { href: '/admin/messages', icon: 'bi-chat-dots', label: 'Messages' },
  ];

  return (
    <div className="d-flex vh-100">
      {/* Sidebar */}
      <nav className="bg-dark text-white" style={{ width: '250px' }}>
        {/* Brand */}
        <div className="p-3 border-bottom border-secondary">
          <div className="d-flex justify-content-center">
            <img
              src="/dashboard_logo.png"
              alt="KiloShare Logo"
              style={{ width: '100%', height: '60px', objectFit: 'contain' }}
            />
          </div>
        </div>

        {/* Navigation */}
        <div className="p-3">
          <ul className="nav flex-column">
            {menuItems.map((item) => (
              <li key={item.href} className="nav-item mb-1">
                <a
                  href={item.href}
                  className={`nav-link text-white rounded px-3 py-2 d-flex align-items-center ${
                    pathname === item.href ? 'bg-primary' : ''
                  }`}
                  style={{ transition: 'all 0.2s' }}
                >
                  <i className={`bi ${item.icon} me-2`}></i>
                  {item.label}
                </a>
              </li>
            ))}
          </ul>
        </div>

        {/* Footer Actions */}
        <div className="mt-auto p-3 border-top border-secondary">
          {/* Profile, Settings, Logout buttons */}
          <div className="d-grid gap-2">
            <a
              href="/admin/profile"
              className={`btn ${pathname === '/admin/profile' ? 'btn-primary' : 'btn-outline-light'} d-flex align-items-center justify-content-center`}
            >
              <i className="bi bi-person-circle me-2"></i>
              Mon Profil
            </a>

            <a
              href="/admin/settings"
              className={`btn ${pathname === '/admin/settings' ? 'btn-primary' : 'btn-outline-light'} d-flex align-items-center justify-content-center`}
            >
              <i className="bi bi-gear me-2"></i>
              Configuration
            </a>

            <button
              onClick={handleLogout}
              className="btn btn-outline-danger d-flex align-items-center justify-content-center"
            >
              <i className="bi bi-box-arrow-right me-2"></i>
              Déconnexion
            </button>
          </div>
        </div>
      </nav>

      {/* Main content */}
      <div className="flex-grow-1 overflow-auto">
        {/* Top navbar */}
        <nav className="navbar navbar-expand-lg navbar-light bg-white border-bottom">
          <div className="container-fluid">
            <div className="d-flex align-items-center">
              <button
                className="btn btn-link d-md-none p-0 me-3"
                onClick={() => setSidebarOpen(!sidebarOpen)}
              >
                <i className="bi bi-list fs-4 text-muted"></i>
              </button>
              <span className="text-muted text-capitalize">
                {pathname.split('/').pop()?.replace('-', ' ') || 'Dashboard'}
              </span>
            </div>
            <div className="d-flex align-items-center">
              {/* User info removed */}
            </div>
          </div>
        </nav>

        {/* Page content */}
        <main>
          {children}
        </main>
      </div>

      {/* Mobile Sidebar Overlay */}
      {sidebarOpen && (
        <div
          className="position-fixed w-100 h-100 bg-dark bg-opacity-50 d-md-none"
          style={{ top: 0, left: 0, zIndex: 1050 }}
          onClick={() => setSidebarOpen(false)}
        />
      )}
    </div>
  );
}