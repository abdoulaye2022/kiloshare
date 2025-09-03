'use client';

import React, { useState, useEffect } from 'react';
import { useAdminAuthStore } from '../../stores/adminAuthStore';
import Cookies from 'js-cookie';

export default function AdminAuthDebug() {
  const { user, token, isAuthenticated, isLoading } = useAdminAuthStore();
  const [mounted, setMounted] = useState(false);
  const [storageData, setStorageData] = useState({
    localStorage: null as string | null,
    sessionStorage: null as string | null,
    cookie: null as string | undefined
  });
  
  // Only render after hydration
  useEffect(() => {
    setMounted(true);
    
    // Get storage data safely after mount
    setStorageData({
      localStorage: localStorage.getItem('admin_token'),
      sessionStorage: sessionStorage.getItem('admin_token'),
      cookie: Cookies.get('admin_token')
    });
  }, []);
  
  // Don't render during SSR or always in production
  if (!mounted) {
    return null;
  }

  // Never render in any environment (production ready)
  return null;

  return (
    <div className="fixed bottom-4 right-4 bg-black bg-opacity-80 text-white p-4 rounded-lg text-xs z-50 max-w-sm">
      <h3 className="font-bold mb-2">🔧 Admin Auth Debug</h3>
      <div className="space-y-1">
        <div>Store Auth: <span className={isAuthenticated ? 'text-green-400' : 'text-red-400'}>{isAuthenticated ? 'YES' : 'NO'}</span></div>
        <div>Loading: <span className={isLoading ? 'text-yellow-400' : 'text-gray-400'}>{isLoading ? 'YES' : 'NO'}</span></div>
        <div>User: {user?.email || 'None'}</div>
        <div>Store Token: {token ? `${token.substring(0, 10)}...` : 'None'}</div>
        <div>localStorage: {storageData.localStorage ? `${storageData.localStorage.substring(0, 10)}...` : 'None'}</div>
        <div>sessionStorage: {storageData.sessionStorage ? `${storageData.sessionStorage.substring(0, 10)}...` : 'None'}</div>
        <div>Cookie: {storageData.cookie ? `${storageData.cookie.substring(0, 10)}...` : 'None'}</div>
      </div>
    </div>
  );
}