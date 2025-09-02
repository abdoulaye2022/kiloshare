'use client';

import React from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { Search, User, MessageCircle, Heart, Settings } from 'lucide-react';

export default function MobileBottomNav() {
  const pathname = usePathname();

  const isActive = (path: string) => pathname === path;

  // Ne pas afficher sur la page d'accueil et les pages admin
  if (pathname === '/' || pathname?.startsWith('/admin')) return null;

  return (
    <div className="md:hidden fixed bottom-0 left-0 right-0 bg-white border-t border-gray-200 z-50">
      <div className="grid grid-cols-4 h-16">
        {/* Rechercher */}
        <Link
          href="/admin/search"
          className={`flex flex-col items-center justify-center space-y-1 ${
            isActive('/admin/search')
              ? 'text-blue-600 bg-blue-50'
              : 'text-gray-600'
          }`}
        >
          <Search className="h-5 w-5" />
          <span className="text-xs font-medium">Rechercher</span>
        </Link>

        {/* Mes voyages */}
        <Link
          href="/admin/my-trips"
          className={`flex flex-col items-center justify-center space-y-1 relative ${
            isActive('/admin/my-trips')
              ? 'text-blue-600 bg-blue-50'
              : 'text-gray-600'
          }`}
        >
          <div className="relative">
            <User className="h-5 w-5" />
            {/* Badge pour brouillons */}
            <span className="absolute -top-2 -right-2 bg-orange-500 text-white text-xs rounded-full min-w-[16px] h-4 flex items-center justify-center px-1">
              2
            </span>
          </div>
          <span className="text-xs font-medium">Mes voyages</span>
        </Link>

        {/* Propositions */}
        <Link
          href="/admin/proposals"
          className={`flex flex-col items-center justify-center space-y-1 relative ${
            isActive('/admin/proposals')
              ? 'text-blue-600 bg-blue-50'
              : 'text-gray-600'
          }`}
        >
          <div className="relative">
            <MessageCircle className="h-5 w-5" />
            {/* Badge pour propositions en attente */}
            <span className="absolute -top-2 -right-2 bg-red-500 text-white text-xs rounded-full min-w-[16px] h-4 flex items-center justify-center px-1">
              3
            </span>
          </div>
          <span className="text-xs font-medium">Propositions</span>
        </Link>

        {/* Plus/Menu */}
        <Link
          href="/admin/dashboard"
          className={`flex flex-col items-center justify-center space-y-1 ${
            isActive('/admin/dashboard') || isActive('/user/trips')
              ? 'text-blue-600 bg-blue-50'
              : 'text-gray-600'
          }`}
        >
          <Settings className="h-5 w-5" />
          <span className="text-xs font-medium">Plus</span>
        </Link>
      </div>
    </div>
  );
}