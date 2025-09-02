'use client';

import React, { useEffect } from 'react';
import { useAdminAuthStore } from '../../stores/adminAuthStore';

interface AdminAuthProviderProps {
  children: React.ReactNode;
}

export default function AdminAuthProvider({ children }: AdminAuthProviderProps) {
  const { checkAuth } = useAdminAuthStore();

  useEffect(() => {
    // Check authentication on app startup
    checkAuth();
  }, [checkAuth]);

  return <>{children}</>;
}