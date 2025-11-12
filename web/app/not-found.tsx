'use client'

import Link from 'next/link'

export default function NotFound() {
  return (
    <div className="min-vh-100 d-flex align-items-center justify-content-center bg-light">
      <div className="text-center px-4">
        <h1 className="display-1 fw-bold text-primary">404</h1>
        <h2 className="h3 mb-3">Page non trouvée</h2>
        <p className="text-muted mb-4">
          Désolé, la page que vous recherchez n'existe pas ou a été déplacée.
        </p>
        <div className="d-flex gap-3 justify-content-center">
          <Link href="/" className="btn btn-primary">
            <i className="bi bi-house-door me-2"></i>
            Retour à l'accueil
          </Link>
          <button onClick={() => window.history.back()} className="btn btn-outline-secondary">
            <i className="bi bi-arrow-left me-2"></i>
            Retour
          </button>
        </div>
      </div>
    </div>
  )
}
