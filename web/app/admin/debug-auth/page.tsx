'use client';

import React, { useState, useEffect } from 'react';
import { useAdminAuthStore } from '../../../stores/adminAuthStore';
import { adminAuth } from '../../../lib/admin-auth';
import { useClientOnly } from '../../../hooks/useClientOnly';

export default function AuthDebugPage() {
  const mounted = useClientOnly(100);
  const { user, token, isAuthenticated, checkAuth, login } = useAdminAuthStore();
  const [storageInfo, setStorageInfo] = useState<any>({});

  useEffect(() => {
    if (!mounted) return;
    
    const updateStorageInfo = () => {
      setStorageInfo({
        // Zustand store
        zustand_token: token,
        zustand_authenticated: isAuthenticated,
        zustand_user: user?.email,
        
        // Storage locations
        localStorage_admin_token: localStorage.getItem('admin_token'),
        sessionStorage_admin_token: sessionStorage.getItem('admin_token'),
        cookie_admin_token: document.cookie.includes('admin_token='),
        
        // Old admin auth
        localStorage_adminToken: localStorage.getItem('adminToken'),
        old_auth_authenticated: adminAuth.isAuthenticated(),
        old_auth_token: adminAuth.getAccessToken(),
      });
    };

    updateStorageInfo();
    const interval = setInterval(updateStorageInfo, 1000);
    
    return () => clearInterval(interval);
  }, [mounted, token, isAuthenticated, user]);

  const handleTestLogin = () => {
    const testToken = 'test-token-' + Date.now();
    const testUser = {
      id: 1,
      email: 'admin@gmail.com',
      role: 'admin'
    };
    
    login(testToken, testUser);
  };

  const handleCheckAuth = async () => {
    console.log('Manual auth check triggered');
    await checkAuth();
  };

  if (!mounted) {
    return <div>Loading...</div>;
  }

  return (
    <div className="p-6">
      <h1 className="text-2xl font-bold mb-6">🔧 Auth Debug Page</h1>
      
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="bg-white rounded-lg shadow p-4">
          <h2 className="text-lg font-semibold mb-4">🏪 Zustand Store</h2>
          <div className="space-y-2 text-sm">
            <div>Token: {storageInfo.zustand_token ? `${storageInfo.zustand_token.substring(0, 20)}...` : 'None'}</div>
            <div>Authenticated: <span className={storageInfo.zustand_authenticated ? 'text-green-600' : 'text-red-600'}>{storageInfo.zustand_authenticated ? 'YES' : 'NO'}</span></div>
            <div>User: {storageInfo.zustand_user || 'None'}</div>
          </div>
        </div>

        <div className="bg-white rounded-lg shadow p-4">
          <h2 className="text-lg font-semibold mb-4">🗄️ Storage</h2>
          <div className="space-y-2 text-sm">
            <div>localStorage (admin_token): {storageInfo.localStorage_admin_token ? `${storageInfo.localStorage_admin_token.substring(0, 20)}...` : 'None'}</div>
            <div>sessionStorage (admin_token): {storageInfo.sessionStorage_admin_token ? `${storageInfo.sessionStorage_admin_token.substring(0, 20)}...` : 'None'}</div>
            <div>Cookie (admin_token): <span className={storageInfo.cookie_admin_token ? 'text-green-600' : 'text-red-600'}>{storageInfo.cookie_admin_token ? 'YES' : 'NO'}</span></div>
          </div>
        </div>

        <div className="bg-white rounded-lg shadow p-4">
          <h2 className="text-lg font-semibold mb-4">🏛️ Old Admin Auth</h2>
          <div className="space-y-2 text-sm">
            <div>Token (adminToken): {storageInfo.localStorage_adminToken ? `${storageInfo.localStorage_adminToken.substring(0, 20)}...` : 'None'}</div>
            <div>Old Auth Token: {storageInfo.old_auth_token ? `${storageInfo.old_auth_token.substring(0, 20)}...` : 'None'}</div>
            <div>Authenticated: <span className={storageInfo.old_auth_authenticated ? 'text-green-600' : 'text-red-600'}>{storageInfo.old_auth_authenticated ? 'YES' : 'NO'}</span></div>
          </div>
        </div>

        <div className="bg-white rounded-lg shadow p-4">
          <h2 className="text-lg font-semibold mb-4">🧪 Test Actions</h2>
          <div className="space-y-2">
            <button
              onClick={handleTestLogin}
              className="w-full bg-green-600 text-white py-2 px-4 rounded"
            >
              Test Login
            </button>
            <button
              onClick={handleCheckAuth}
              className="w-full bg-blue-600 text-white py-2 px-4 rounded"
            >
              Check Auth
            </button>
          </div>
        </div>
      </div>

      <div className="mt-6 bg-gray-100 rounded-lg p-4">
        <h3 className="font-semibold mb-2">📊 Raw Data</h3>
        <pre className="text-xs overflow-auto">
          {JSON.stringify(storageInfo, null, 2)}
        </pre>
      </div>
    </div>
  );
}