'use client';

import React from 'react';
import { Package, Search, Heart, User } from 'lucide-react';

export default function TestPage() {
  return (
    <div className="min-h-screen bg-gray-50 p-4">
      <h1 className="text-2xl font-bold mb-4">Test Page</h1>
      
      <div className="bg-white p-6 rounded-lg shadow">
        <div className="flex items-center space-x-4">
          <Package className="h-6 w-6 text-blue-600" />
          <Search className="h-6 w-6 text-green-600" />
          <Heart className="h-6 w-6 text-red-600" />
          <User className="h-6 w-6 text-gray-600" />
        </div>
        
        <p className="mt-4 text-gray-700">
          Si vous voyez cette page avec les icônes, les imports fonctionnent correctement.
        </p>
      </div>
    </div>
  );
}