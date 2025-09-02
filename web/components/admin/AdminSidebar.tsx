'use client';

import React from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import {
  LayoutDashboard,
  Users,
  Package,
  CreditCard,
  FileText,
  Settings,
  BarChart3,
  Shield,
  MessageSquare,
  MapPin,
  X
} from 'lucide-react';

interface AdminSidebarProps {
  isOpen: boolean;
  onClose: () => void;
}

export default function AdminSidebar({ isOpen, onClose }: AdminSidebarProps) {
  const pathname = usePathname();

  const isActive = (path: string) => pathname === path;

  const menuItems = [
    {
      title: 'Vue d\'ensemble',
      items: [
        {
          label: 'Dashboard',
          href: '/admin/dashboard',
          icon: LayoutDashboard,
          active: isActive('/admin/dashboard')
        },
        {
          label: 'Statistiques',
          href: '/admin/stats',
          icon: BarChart3,
          active: isActive('/admin/stats')
        }
      ]
    },
    {
      title: 'Gestion',
      items: [
        {
          label: 'Utilisateurs',
          href: '/admin/users',
          icon: Users,
          active: isActive('/admin/users'),
          badge: '42'
        },
        {
          label: 'Voyages',
          href: '/admin/trips',
          icon: MapPin,
          active: isActive('/admin/trips'),
          badge: '8'
        },
        {
          label: 'Transactions',
          href: '/admin/transactions',
          icon: CreditCard,
          active: isActive('/admin/transactions')
        },
        {
          label: 'Comptes Stripe',
          href: '/admin/stripe-accounts',
          icon: Shield,
          active: isActive('/admin/stripe-accounts')
        }
      ]
    },
    {
      title: 'Communication',
      items: [
        {
          label: 'Messages',
          href: '/admin/messages',
          icon: MessageSquare,
          active: isActive('/admin/messages'),
          badge: '3'
        },
        {
          label: 'Rapports',
          href: '/admin/reports',
          icon: FileText,
          active: isActive('/admin/reports')
        }
      ]
    },
    {
      title: 'Configuration',
      items: [
        {
          label: 'Paramètres',
          href: '/admin/settings',
          icon: Settings,
          active: isActive('/admin/settings')
        }
      ]
    }
  ];

  return (
    <>
      <aside className={`fixed left-0 top-16 bottom-0 bg-white border-r border-gray-200 transition-all duration-300 z-25 ${
        isOpen ? 'w-64' : 'w-16'
      }`}>
        <div className="flex flex-col h-full">
          {/* Close button for mobile */}
          <div className="lg:hidden flex justify-end p-4">
            <button
              onClick={onClose}
              className="p-2 rounded-md text-gray-400 hover:text-gray-600 hover:bg-gray-100"
            >
              <X className="h-5 w-5" />
            </button>
          </div>

          {/* Navigation */}
          <nav className="flex-1 px-3 py-4 space-y-8">
            {menuItems.map((section, sectionIndex) => (
              <div key={sectionIndex}>
                {/* Section title */}
                {isOpen && (
                  <h3 className="px-3 text-xs font-semibold text-gray-500 uppercase tracking-wider mb-3">
                    {section.title}
                  </h3>
                )}

                {/* Section items */}
                <div className="space-y-1">
                  {section.items.map((item, itemIndex) => {
                    const Icon = item.icon;
                    return (
                      <Link
                        key={itemIndex}
                        href={item.href}
                        className={`flex items-center px-3 py-2 text-sm font-medium rounded-md transition-colors group ${
                          item.active
                            ? 'bg-blue-100 text-blue-700 border-r-2 border-blue-700'
                            : 'text-gray-600 hover:text-gray-900 hover:bg-gray-50'
                        }`}
                      >
                        <Icon className={`h-5 w-5 ${isOpen ? 'mr-3' : 'mx-auto'} ${
                          item.active ? 'text-blue-700' : 'text-gray-400 group-hover:text-gray-500'
                        }`} />
                        
                        {isOpen && (
                          <div className="flex-1 flex items-center justify-between">
                            <span>{item.label}</span>
                            {item.badge && (
                              <span className="bg-gray-100 text-gray-600 text-xs px-2 py-1 rounded-full">
                                {item.badge}
                              </span>
                            )}
                          </div>
                        )}
                      </Link>
                    );
                  })}
                </div>
              </div>
            ))}
          </nav>

          {/* Footer */}
          <div className="p-4 border-t border-gray-200">
            {isOpen && (
              <div className="text-xs text-gray-500">
                <p className="font-medium">KiloShare Admin</p>
                <p>Version 1.0.0</p>
              </div>
            )}
          </div>
        </div>
      </aside>
    </>
  );
}