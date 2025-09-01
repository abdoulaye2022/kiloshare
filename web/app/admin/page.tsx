'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';

export default function AdminRoot() {
  const router = useRouter();

  useEffect(() => {
    // Vérifier si l'admin est connecté
    const token = localStorage.getItem('adminToken');
    
    if (token) {
      // Rediriger vers le dashboard
      router.push('/admin/dashboard');
    } else {
      // Rediriger vers la page de login
      router.push('/admin/login');
    }
  }, [router]);

  return (
    <div className="min-h-screen flex items-center justify-center">
      <div className="animate-spin rounded-full h-32 w-32 border-b-2 border-blue-600"></div>
    </div>
  );
}