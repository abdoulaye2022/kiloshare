'use client';

export default function ProposalsPage() {
  return (
    <div className="min-h-screen bg-gray-50">
      <header className="bg-white shadow-sm">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center py-6">
            <div>
              <h1 className="text-3xl font-bold text-gray-900">
                Mes propositions
              </h1>
              <p className="text-gray-600 mt-1">
                Gérez vos demandes de transport
              </p>
            </div>
          </div>
        </div>
      </header>

      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="text-center py-12">
          <div className="mx-auto h-12 w-12 text-gray-400 mb-4">
            📦
          </div>
          <h3 className="mt-2 text-sm font-medium text-gray-900">
            Page en construction
          </h3>
          <p className="mt-1 text-sm text-gray-500">
            Cette page sera bientôt disponible pour gérer vos propositions.
          </p>
        </div>
      </main>
    </div>
  );
}