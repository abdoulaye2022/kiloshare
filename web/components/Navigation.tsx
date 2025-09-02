'use client';

import React from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { Package, Search, MessageCircle, User, Settings } from 'lucide-react';

export default function Navigation() {
  const pathname = usePathname();

  const isActive = (path: string) => pathname === path;
  
  // Ne pas afficher sur les pages admin
  if (pathname?.startsWith('/admin')) {
    return null;
  }

  return (
    <nav className="bg-white shadow-sm border-b">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between items-center h-16">
          {/* Logo */}
          <Link href="/" className="flex items-center space-x-2">
            <Package className="h-8 w-8 text-blue-600" />
            <span className="text-xl font-bold text-gray-900">KiloShare</span>
          </Link>

          {/* Navigation Links */}
          <div className="hidden md:flex space-x-6">
            <Link
              href="/admin/search"
              className={`flex items-center space-x-2 px-3 py-2 rounded-md text-sm font-medium transition-colors ${
                isActive('/admin/search')
                  ? 'bg-blue-100 text-blue-700'
                  : 'text-gray-600 hover:text-gray-900 hover:bg-gray-50'
              }`}
            >
              <Search className="h-4 w-4" />
              <span>Rechercher</span>
            </Link>

            <Link
              href="/admin/my-trips"
              className={`flex items-center space-x-2 px-3 py-2 rounded-md text-sm font-medium transition-colors ${
                isActive('/admin/my-trips')
                  ? 'bg-blue-100 text-blue-700'
                  : 'text-gray-600 hover:text-gray-900 hover:bg-gray-50'
              }`}
            >
              <User className="h-4 w-4" />
              <span>Mes voyages</span>
              {/* Badge pour brouillons */}
              <span className="bg-orange-100 text-orange-800 text-xs font-medium px-2 py-1 rounded-full">
                2
              </span>
            </Link>

            <Link
              href="/admin/proposals"
              className={`flex items-center space-x-2 px-3 py-2 rounded-md text-sm font-medium transition-colors ${
                isActive('/admin/proposals')
                  ? 'bg-blue-100 text-blue-700'
                  : 'text-gray-600 hover:text-gray-900 hover:bg-gray-50'
              }`}
            >
              <MessageCircle className="h-4 w-4" />
              <span>Propositions</span>
              {/* Badge pour les propositions en attente */}
              <span className="bg-red-100 text-red-800 text-xs font-medium px-2 py-1 rounded-full">
                3
              </span>
            </Link>

            <Link
              href="/admin/dashboard"
              className={`flex items-center space-x-2 px-3 py-2 rounded-md text-sm font-medium transition-colors ${
                isActive('/admin/dashboard')
                  ? 'bg-blue-100 text-blue-700'
                  : 'text-gray-600 hover:text-gray-900 hover:bg-gray-50'
              }`}
            >
              <Settings className="h-4 w-4" />
              <span>Admin</span>
            </Link>
          </div>

          {/* User Menu */}
          <div className="flex items-center space-x-4">
            <div className="hidden md:flex items-center space-x-3">
              <span className="text-sm text-gray-600">Connecté en tant que</span>
              <div className="flex items-center space-x-2">
                <div className="w-8 h-8 bg-blue-100 rounded-full flex items-center justify-center">
                  <User className="h-4 w-4 text-blue-600" />
                </div>
                <span className="text-sm font-medium text-gray-900">Demo User</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </nav>
  );
}