'use client';

import React from 'react';

export default function HomePage() {
  return (
    <div className="min-vh-100" style={{background: 'linear-gradient(135deg, #f8f9ff 0%, #e3f2fd 100%)'}}>
      {/* Header */}
      <header className="bg-white shadow-sm">
        <div className="container">
          <div className="d-flex justify-content-between align-items-center py-4">
            <div className="d-flex align-items-center">
              <i className="bi bi-box-seam fs-2 text-primary me-2"></i>
              <h1 className="h2 mb-0 fw-bold text-primary">KiloShare</h1>
            </div>
            <nav className="d-none d-md-flex">
              <a href="#features" className="nav-link text-secondary me-4">
                Fonctionnalités
              </a>
              <a href="#how-it-works" className="nav-link text-secondary me-4">
                Comment ça marche
              </a>
              <a href="#download" className="nav-link text-secondary">
                Télécharger
              </a>
            </nav>
          </div>
        </div>
      </header>

      {/* Hero Section */}
      <section className="py-5">
        <div className="container text-center">
          <div className="row justify-content-center">
            <div className="col-lg-10">
              <h2 className="display-2 fw-bold text-dark mb-4">
                Partagez vos espaces
                <span className="text-primary"> bagages</span>
              </h2>
              <p className="fs-5 text-muted mb-5 mx-auto" style={{maxWidth: '600px'}}>
                La plateforme qui connecte voyageurs et expéditeurs pour des transports
                plus économiques et écologiques. Transformez vos voyages en opportunités !
              </p>

              {/* CTA Buttons */}
              <div className="d-flex flex-column flex-sm-row gap-3 justify-content-center mb-5">
                <button className="btn btn-primary btn-lg px-4 py-3 rounded-pill">
                  <i className="bi bi-download me-2"></i>
                  Télécharger l'app
                </button>
                <button className="btn btn-outline-primary btn-lg px-4 py-3 rounded-pill">
                  En savoir plus
                </button>
              </div>

              {/* Hero Stats */}
              <div className="row justify-content-center mt-5">
                <div className="col-md-8">
                  <div className="row g-4">
                    <div className="col-md-4">
                      <div className="text-center">
                        <div className="h2 fw-bold text-primary mb-1">1000+</div>
                        <div className="text-muted">Voyageurs actifs</div>
                      </div>
                    </div>
                    <div className="col-md-4">
                      <div className="text-center">
                        <div className="h2 fw-bold text-primary mb-1">50+</div>
                        <div className="text-muted">Villes connectées</div>
                      </div>
                    </div>
                    <div className="col-md-4">
                      <div className="text-center">
                        <div className="h2 fw-bold text-primary mb-1">95%</div>
                        <div className="text-muted">Satisfaction client</div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Features Section */}
      <section id="features" className="py-5 bg-white">
        <div className="container">
          <div className="text-center mb-5">
            <h3 className="display-4 fw-bold text-dark mb-3">
              Pourquoi choisir KiloShare ?
            </h3>
            <p className="fs-5 text-muted">
              Une solution complète pour optimiser vos voyages et vos expéditions
            </p>
          </div>

          <div className="row g-4">
            {[
              {
                icon: "bi-people",
                title: "Communauté fiable",
                description: "Profils vérifiés et système de notation pour voyager en toute confiance"
              },
              {
                icon: "bi-shield-check",
                title: "Sécurisé",
                description: "Paiements protégés et assurance incluse sur tous les transports"
              },
              {
                icon: "bi-airplane",
                title: "Économique",
                description: "Réduisez vos coûts de transport jusqu'à 60% par rapport aux services traditionnels"
              },
              {
                icon: "bi-star-fill",
                title: "Simple d'utilisation",
                description: "Interface intuitive pour publier ou réserver un transport en quelques clics"
              }
            ].map((feature, index) => (
              <div key={index} className="col-md-6 col-lg-3">
                <div className="text-center p-4 h-100">
                  <div className="bg-primary text-white rounded-circle d-inline-flex align-items-center justify-content-center mb-3" style={{width: '60px', height: '60px'}}>
                    <i className={`bi ${feature.icon} fs-4`}></i>
                  </div>
                  <h4 className="h5 fw-semibold mb-3">{feature.title}</h4>
                  <p className="text-muted">{feature.description}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* How it works */}
      <section id="how-it-works" className="py-5 bg-light">
        <div className="container">
          <div className="text-center mb-5">
            <h3 className="display-4 fw-bold text-dark mb-3">
              Comment ça marche ?
            </h3>
            <p className="fs-5 text-muted">
              En 3 étapes simples, commencez à partager ou réserver des espaces bagages
            </p>
          </div>

          <div className="row g-4">
            {[
              {
                step: "1",
                title: "Inscrivez-vous",
                description: "Créez votre compte et complétez votre profil en quelques minutes",
                icon: "bi-envelope"
              },
              {
                step: "2",
                title: "Publiez ou cherchez",
                description: "Proposez votre espace bagage libre ou trouvez un transport disponible",
                icon: "bi-box-seam"
              },
              {
                step: "3",
                title: "Voyagez ensemble",
                description: "Rencontrez-vous et partagez le voyage de manière économique et écologique",
                icon: "bi-check-circle"
              }
            ].map((step, index) => (
              <div key={index} className="col-md-4">
                <div className="bg-white rounded-3 p-4 text-center shadow-sm h-100">
                  <div className="bg-primary text-white rounded-circle d-inline-flex align-items-center justify-content-center mb-3" style={{width: '60px', height: '60px', fontSize: '1.5rem', fontWeight: 'bold'}}>
                    {step.step}
                  </div>
                  <div className="mb-3">
                    <i className={`bi ${step.icon} fs-1 text-primary`}></i>
                  </div>
                  <h4 className="h5 fw-semibold mb-3">{step.title}</h4>
                  <p className="text-muted">{step.description}</p>
                </div>
                {index < 2 && (
                  <div className="d-none d-md-flex align-items-center justify-content-center position-absolute" style={{right: '-20px', top: '50%', transform: 'translateY(-50%)', zIndex: 1}}>
                    <i className="bi bi-arrow-right fs-3 text-primary"></i>
                  </div>
                )}
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Download Section */}
      <section id="download" className="py-5 bg-white">
        <div className="container">
          <div className="row justify-content-center">
            <div className="col-lg-8 text-center">
              <h3 className="display-4 fw-bold text-dark mb-3">
                Téléchargez KiloShare
              </h3>
              <p className="fs-5 text-muted mb-4">
                Disponible sur iOS et Android. Commencez à partager dès maintenant !
              </p>

              <div className="d-flex flex-column flex-sm-row gap-3 justify-content-center">
                <a href="#" className="btn btn-dark btn-lg d-flex align-items-center">
                  <i className="bi bi-phone me-3 fs-4"></i>
                  <div className="text-start">
                    <div className="small">Télécharger sur</div>
                    <div className="fw-semibold">App Store</div>
                  </div>
                </a>
                <a href="#" className="btn btn-success btn-lg d-flex align-items-center">
                  <i className="bi bi-phone me-3 fs-4"></i>
                  <div className="text-start">
                    <div className="small">Disponible sur</div>
                    <div className="fw-semibold">Google Play</div>
                  </div>
                </a>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="bg-dark text-white py-5">
        <div className="container">
          <div className="row g-4">
            <div className="col-md-6">
              <div className="d-flex align-items-center mb-3">
                <i className="bi bi-box-seam fs-2 text-primary me-2"></i>
                <h4 className="h3 mb-0 fw-bold">KiloShare</h4>
              </div>
              <p className="text-light-emphasis">
                La plateforme de partage d'espace bagages qui connecte voyageurs et expéditeurs
                pour des transports plus économiques et écologiques.
              </p>
            </div>

            <div className="col-md-3">
              <h5 className="fw-semibold mb-3">Liens rapides</h5>
              <ul className="list-unstyled">
                <li className="mb-2"><a href="#" className="text-light-emphasis text-decoration-none">Accueil</a></li>
                <li className="mb-2"><a href="#features" className="text-light-emphasis text-decoration-none">Fonctionnalités</a></li>
                <li className="mb-2"><a href="#how-it-works" className="text-light-emphasis text-decoration-none">Comment ça marche</a></li>
                <li className="mb-2"><a href="/verify-email" className="text-light-emphasis text-decoration-none">Vérification email</a></li>
              </ul>
            </div>

            <div className="col-md-3">
              <h5 className="fw-semibold mb-3">Support</h5>
              <ul className="list-unstyled">
                <li className="mb-2"><a href="#" className="text-light-emphasis text-decoration-none">Centre d'aide</a></li>
                <li className="mb-2"><a href="#" className="text-light-emphasis text-decoration-none">Contact</a></li>
                <li className="mb-2"><a href="#" className="text-light-emphasis text-decoration-none">Confidentialité</a></li>
                <li className="mb-2"><a href="#" className="text-light-emphasis text-decoration-none">Conditions d'utilisation</a></li>
              </ul>
            </div>
          </div>

          <hr className="my-4 border-secondary" />
          <div className="text-center text-light-emphasis">
            <p className="mb-0">&copy; 2024 KiloShare. Tous droits réservés.</p>
          </div>
        </div>
      </footer>
    </div>
  );
}