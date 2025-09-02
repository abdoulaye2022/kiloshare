'use client';

import React from 'react';

export default function AdminSearchPage() {
  return (
    <div className="p-6">
      {/* Header */}
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900 mb-2">Recherche de Voyages</h1>
        <p className="text-gray-600">Trouvez des voyages disponibles pour vos colis</p>
      </div>

      {/* Message temporaire */}
      <div className="bg-blue-50 border border-blue-200 rounded-lg p-6 text-center">
        <div className="text-blue-600 mb-2">
          <svg className="mx-auto h-12 w-12" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
          </svg>
        </div>
        <h3 className="text-lg font-semibold text-blue-900 mb-2">Page de Recherche</h3>
        <p className="text-blue-700">Cette page sera bientôt disponible avec des fonctionnalités de recherche avancée.</p>
        
        {/* Recherche fonctionnelle sera implémentée ici */}
        <div className="mt-4">
          <p className="text-sm text-blue-600 mb-2">En attendant, utilisez :</p>
          <a 
            href="/trips" 
            className="inline-flex items-center px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
          >
            Voir les voyages publics
            <svg className="ml-2 h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-2M10 6V4a2 2 0 012-2h2a2 2 0 012 2v2M10 6h4" />
            </svg>
          </a>
        </div>
      </div>
    </div>
  );
}