'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import adminAuth from '../../../lib/admin-auth';
import Dashboard from '../../../components/admin/Dashboard';
import TripModerationPanel from '../../../components/admin/TripModerationPanel';
import PaymentManagement from '../../../components/admin/PaymentManagement';

export default function AdminDashboard() {
  const [admin, setAdmin] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [currentView, setCurrentView] = useState<'dashboard' | 'moderation' | 'payments' | 'profile'>('dashboard');
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const router = useRouter();

  useEffect(() => {
    if (!adminAuth.isAuthenticated()) {
      router.push('/admin/login');
      return;
    }

    const adminData = adminAuth.getAdminInfo();
    if (!adminData || adminData.role !== 'admin') {
      adminAuth.logout();
      return;
    }
    
    setAdmin(adminData);
    setLoading(false);
  }, []);

  const handleLogout = () => {
    adminAuth.logout();
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-100 flex items-center justify-center">
        <div className="flex flex-col items-center space-y-4">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
          <p className="text-gray-600 text-sm">Chargement...</p>
        </div>
      </div>
    );
  }

  if (!admin) {
    return null;
  }

  const navigation = [
    { id: 'dashboard', name: 'Tableau de bord', icon: 'M3 4a1 1 0 011-1h16a1 1 0 011 1v2a1 1 0 01-1 1H4a1 1 0 01-1-1V4zM3 10a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H4a1 1 0 01-1-1v-6zM14 9a1 1 0 00-1 1v6a1 1 0 001 1h6a1 1 0 001-1v-6a1 1 0 00-1-1h-6z' },
    { id: 'moderation', name: 'Modération', icon: 'M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z' },
    { id: 'payments', name: 'Paiements', icon: 'M17 9V7a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2m2 4h10a2 2 0 002-2v-6a2 2 0 00-2-2H9a2 2 0 00-2 2v6a2 2 0 002 2zm7-5a2 2 0 11-4 0 2 2 0 014 0z' },
  ];

  return (
    <div className="flex min-h-screen bg-gray-100">
      {/* Sidebar */}
      <div className={`fixed inset-y-0 left-0 z-50 w-64 bg-white shadow-lg transform ${sidebarOpen ? 'translate-x-0' : '-translate-x-full'} transition-transform duration-300 ease-in-out lg:translate-x-0 lg:static lg:flex-shrink-0`}>
        <div className="flex flex-col h-full">
          {/* Logo */}
          <div className="flex items-center justify-center h-16 px-4 bg-blue-600">
            <h1 className="text-xl font-bold text-white">KiloShare Admin</h1>
          </div>
          
          {/* Navigation */}
          <nav className="flex-1 px-4 py-6 space-y-2">
            {navigation.map((item) => (
              <button
                key={item.id}
                onClick={() => {
                  setCurrentView(item.id as any);
                  setSidebarOpen(false);
                }}
                className={`w-full flex items-center px-4 py-3 text-sm font-medium rounded-lg transition-colors ${
                  currentView === item.id
                    ? 'bg-blue-50 text-blue-700 border-r-2 border-blue-600'
                    : 'text-gray-600 hover:bg-gray-50 hover:text-gray-900'
                }`}
              >
                <svg className="w-5 h-5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d={item.icon} />
                </svg>
                {item.name}
              </button>
            ))}
          </nav>
          
          {/* Admin Profile & Logout */}
          <div className="px-4 py-6 border-t border-gray-200">
            <div className="flex items-center mb-4">
              <div className="w-10 h-10 bg-blue-600 rounded-full flex items-center justify-center">
                <span className="text-white font-semibold text-sm">
                  {admin.name?.split(' ').map((n: string) => n[0]).join('') || 'AD'}
                </span>
              </div>
              <div className="ml-3">
                <p className="text-sm font-medium text-gray-900">{admin.name}</p>
                <p className="text-xs text-gray-500">{admin.email}</p>
              </div>
            </div>
            <button
              onClick={() => setCurrentView('profile')}
              className="w-full flex items-center px-4 py-2 text-sm text-gray-600 hover:bg-gray-50 rounded-lg mb-2"
            >
              <svg className="w-4 h-4 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
              </svg>
              Profil
            </button>
            <button
              onClick={handleLogout}
              className="w-full flex items-center px-4 py-2 text-sm text-red-600 hover:bg-red-50 rounded-lg"
            >
              <svg className="w-4 h-4 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
              </svg>
              Déconnexion
            </button>
          </div>
        </div>
      </div>

      {/* Mobile sidebar overlay */}
      {sidebarOpen && (
        <div 
          className="fixed inset-0 z-40 bg-gray-600 bg-opacity-75 lg:hidden"
          onClick={() => setSidebarOpen(false)}
        ></div>
      )}

      {/* Main content */}
      <div className="flex-1 lg:ml-0">
        {/* Top header */}
        <header className="bg-white shadow-sm border-b border-gray-200">
          <div className="flex items-center justify-between px-4 py-4 sm:px-6 lg:px-8">
            <div className="flex items-center">
              <button
                onClick={() => setSidebarOpen(true)}
                className="lg:hidden p-2 rounded-md text-gray-600 hover:text-gray-900 hover:bg-gray-50"
              >
                <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
                </svg>
              </button>
              <h1 className="ml-4 text-2xl font-semibold text-gray-900 capitalize">
                {currentView === 'dashboard' ? 'Tableau de bord' : 
                 currentView === 'moderation' ? 'Modération' : 
                 currentView === 'payments' ? 'Paiements' : 'Profil'}
              </h1>
            </div>
            <div className="flex items-center space-x-4">
              <div className="text-sm text-gray-500">
                {new Date().toLocaleDateString('fr-FR', { 
                  weekday: 'long', 
                  year: 'numeric', 
                  month: 'long', 
                  day: 'numeric' 
                })}
              </div>
            </div>
          </div>
        </header>

        {/* Page content */}
        <main className="flex-1">
          {currentView === 'dashboard' && (
            <Dashboard adminInfo={admin} onLogout={handleLogout} />
          )}
          
          {currentView === 'moderation' && (
            <TripModerationPanel adminInfo={admin} onLogout={handleLogout} />
          )}

          {currentView === 'payments' && (
            <PaymentManagement adminInfo={admin} onLogout={handleLogout} />
          )}

          {currentView === 'profile' && (
            <div className="p-6">
              <div className="max-w-2xl mx-auto bg-white rounded-lg shadow-sm border border-gray-200">
                <div className="px-6 py-4 border-b border-gray-200">
                  <h2 className="text-lg font-semibold text-gray-900">Profil Administrateur</h2>
                </div>
                <div className="p-6">
                  <div className="flex items-center mb-6">
                    <div className="w-20 h-20 bg-blue-600 rounded-full flex items-center justify-center">
                      <span className="text-white font-bold text-2xl">
                        {admin.name?.split(' ').map((n: string) => n[0]).join('') || 'AD'}
                      </span>
                    </div>
                    <div className="ml-6">
                      <h3 className="text-xl font-semibold text-gray-900">{admin.name}</h3>
                      <p className="text-gray-600">{admin.email}</p>
                      <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800 mt-2">
                        {admin.role}
                      </span>
                    </div>
                  </div>
                  <div className="grid grid-cols-1 gap-6 sm:grid-cols-2">
                    <div>
                      <label className="block text-sm font-medium text-gray-700">Nom complet</label>
                      <p className="mt-1 text-sm text-gray-900">{admin.name}</p>
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-gray-700">Email</label>
                      <p className="mt-1 text-sm text-gray-900">{admin.email}</p>
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-gray-700">Rôle</label>
                      <p className="mt-1 text-sm text-gray-900 capitalize">{admin.role}</p>
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-gray-700">ID</label>
                      <p className="mt-1 text-sm text-gray-900">{admin.id}</p>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          )}
        </main>

        {/* Footer */}
        <footer className="bg-white border-t border-gray-200 py-4 px-6">
          <div className="flex justify-between items-center text-sm text-gray-500">
            <p>&copy; 2025 KiloShare. Tous droits réservés.</p>
            <p>Version 1.0.0</p>
          </div>
        </footer>
      </div>
    </div>
  );
}