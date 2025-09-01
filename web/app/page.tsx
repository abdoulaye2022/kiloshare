'use client';

import React from 'react';
import { 
  Package, 
  Users, 
  Plane, 
  Shield, 
  Star,
  Download,
  CheckCircle,
  ArrowRight,
  Mail,
  Smartphone
} from 'lucide-react';

export default function HomePage() {
  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100">
      {/* Header */}
      <header className="bg-white shadow-sm">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center py-6">
            <div className="flex items-center space-x-2">
              <Package className="h-8 w-8 text-primary" />
              <h1 className="text-2xl font-bold gradient-text">KiloShare</h1>
            </div>
            <nav className="hidden md:flex space-x-8">
              <a href="#features" className="text-gray-700 hover:text-primary transition-colors">
                Fonctionnalités
              </a>
              <a href="#how-it-works" className="text-gray-700 hover:text-primary transition-colors">
                Comment ça marche
              </a>
              <a href="#download" className="text-gray-700 hover:text-primary transition-colors">
                Télécharger
              </a>
            </nav>
          </div>
        </div>
      </header>

      {/* Hero Section */}
      <section className="py-20 px-4 sm:px-6 lg:px-8">
        <div className="max-w-7xl mx-auto text-center">
          <h2 className="text-5xl md:text-6xl font-bold text-gray-900 mb-6">
            Partagez vos espaces
            <span className="gradient-text"> bagages</span>
          </h2>
          <p className="text-xl text-gray-600 mb-8 max-w-3xl mx-auto leading-relaxed">
            La plateforme qui connecte voyageurs et expéditeurs pour des transports 
            plus économiques et écologiques. Transformez vos voyages en opportunités !
          </p>
          
          {/* CTA Buttons */}
          <div className="flex flex-col sm:flex-row gap-4 justify-center mb-12">
            <button className="hero-gradient text-white px-8 py-4 rounded-full font-semibold text-lg hover:shadow-lg transform hover:scale-105 transition-all duration-200 flex items-center justify-center space-x-2">
              <Download className="h-5 w-5" />
              <span>Télécharger l'app</span>
            </button>
            <button className="bg-white text-primary border-2 border-primary px-8 py-4 rounded-full font-semibold text-lg hover:bg-primary hover:text-white transition-all duration-200">
              En savoir plus
            </button>
          </div>

          {/* Hero Stats */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-8 max-w-2xl mx-auto">
            <div className="text-center">
              <div className="text-3xl font-bold text-primary">1000+</div>
              <div className="text-gray-600">Voyageurs actifs</div>
            </div>
            <div className="text-center">
              <div className="text-3xl font-bold text-primary">50+</div>
              <div className="text-gray-600">Villes connectées</div>
            </div>
            <div className="text-center">
              <div className="text-3xl font-bold text-primary">95%</div>
              <div className="text-gray-600">Satisfaction client</div>
            </div>
          </div>
        </div>
      </section>

      {/* Features Section */}
      <section id="features" className="py-20 bg-white">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-16">
            <h3 className="text-4xl font-bold text-gray-900 mb-4">
              Pourquoi choisir KiloShare ?
            </h3>
            <p className="text-xl text-gray-600 max-w-2xl mx-auto">
              Une solution complète pour optimiser vos voyages et vos expéditions
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-8">
            {[
              {
                icon: <Users className="h-8 w-8" />,
                title: "Communauté fiable",
                description: "Profils vérifiés et système de notation pour voyager en toute confiance"
              },
              {
                icon: <Shield className="h-8 w-8" />,
                title: "Sécurisé",
                description: "Paiements protégés et assurance incluse sur tous les transports"
              },
              {
                icon: <Plane className="h-8 w-8" />,
                title: "Économique",
                description: "Réduisez vos coûts de transport jusqu'à 60% par rapport aux services traditionnels"
              },
              {
                icon: <Star className="h-8 w-8" />,
                title: "Simple d'utilisation",
                description: "Interface intuitive pour publier ou réserver un transport en quelques clics"
              }
            ].map((feature, index) => (
              <div key={index} className="text-center p-6 rounded-lg hover:shadow-lg transition-shadow">
                <div className="hero-gradient p-3 rounded-full w-fit mx-auto mb-4 text-white">
                  {feature.icon}
                </div>
                <h4 className="text-xl font-semibold mb-3 text-gray-900">{feature.title}</h4>
                <p className="text-gray-600">{feature.description}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* How it works */}
      <section id="how-it-works" className="py-20 bg-gradient-to-br from-blue-50 to-indigo-100">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-16">
            <h3 className="text-4xl font-bold text-gray-900 mb-4">
              Comment ça marche ?
            </h3>
            <p className="text-xl text-gray-600 max-w-2xl mx-auto">
              En 3 étapes simples, commencez à partager ou réserver des espaces bagages
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            {[
              {
                step: "1",
                title: "Inscrivez-vous",
                description: "Créez votre compte et complétez votre profil en quelques minutes",
                icon: <Mail className="h-8 w-8" />
              },
              {
                step: "2", 
                title: "Publiez ou cherchez",
                description: "Proposez votre espace bagage libre ou trouvez un transport disponible",
                icon: <Package className="h-8 w-8" />
              },
              {
                step: "3",
                title: "Voyagez ensemble",
                description: "Rencontrez-vous et partagez le voyage de manière économique et écologique",
                icon: <CheckCircle className="h-8 w-8" />
              }
            ].map((step, index) => (
              <div key={index} className="relative">
                <div className="bg-white rounded-lg p-8 text-center shadow-lg hover:shadow-xl transition-shadow">
                  <div className="hero-gradient text-white rounded-full w-16 h-16 flex items-center justify-center mx-auto mb-4 text-2xl font-bold">
                    {step.step}
                  </div>
                  <div className="text-primary mb-4">
                    {step.icon}
                  </div>
                  <h4 className="text-xl font-semibold mb-3 text-gray-900">{step.title}</h4>
                  <p className="text-gray-600">{step.description}</p>
                </div>
                {index < 2 && (
                  <ArrowRight className="hidden md:block absolute top-1/2 -right-4 transform -translate-y-1/2 text-primary h-8 w-8" />
                )}
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Download Section */}
      <section id="download" className="py-20 bg-white">
        <div className="max-w-4xl mx-auto text-center px-4 sm:px-6 lg:px-8">
          <h3 className="text-4xl font-bold text-gray-900 mb-6">
            Téléchargez KiloShare
          </h3>
          <p className="text-xl text-gray-600 mb-8">
            Disponible sur iOS et Android. Commencez à partager dès maintenant !
          </p>
          
          <div className="flex flex-col sm:flex-row gap-4 justify-center mb-8">
            <a
              href="#"
              className="bg-black text-white px-6 py-3 rounded-lg flex items-center space-x-3 hover:bg-gray-800 transition-colors"
            >
              <Smartphone className="h-6 w-6" />
              <div className="text-left">
                <div className="text-xs">Télécharger sur</div>
                <div className="font-semibold">App Store</div>
              </div>
            </a>
            <a
              href="#"
              className="bg-green-600 text-white px-6 py-3 rounded-lg flex items-center space-x-3 hover:bg-green-700 transition-colors"
            >
              <Smartphone className="h-6 w-6" />
              <div className="text-left">
                <div className="text-xs">Disponible sur</div>
                <div className="font-semibold">Google Play</div>
              </div>
            </a>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="bg-gray-900 text-white py-12">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="grid grid-cols-1 md:grid-cols-4 gap-8">
            <div className="col-span-2">
              <div className="flex items-center space-x-2 mb-4">
                <Package className="h-8 w-8 text-primary" />
                <h4 className="text-2xl font-bold">KiloShare</h4>
              </div>
              <p className="text-gray-400 mb-4 max-w-md">
                La plateforme de partage d'espace bagages qui connecte voyageurs et expéditeurs 
                pour des transports plus économiques et écologiques.
              </p>
            </div>
            
            <div>
              <h5 className="font-semibold mb-4">Liens rapides</h5>
              <ul className="space-y-2 text-gray-400">
                <li><a href="#" className="hover:text-white transition-colors">Accueil</a></li>
                <li><a href="#features" className="hover:text-white transition-colors">Fonctionnalités</a></li>
                <li><a href="#how-it-works" className="hover:text-white transition-colors">Comment ça marche</a></li>
                <li><a href="/verify-email" className="hover:text-white transition-colors">Vérification email</a></li>
              </ul>
            </div>
            
            <div>
              <h5 className="font-semibold mb-4">Support</h5>
              <ul className="space-y-2 text-gray-400">
                <li><a href="#" className="hover:text-white transition-colors">Centre d'aide</a></li>
                <li><a href="#" className="hover:text-white transition-colors">Contact</a></li>
                <li><a href="#" className="hover:text-white transition-colors">Confidentialité</a></li>
                <li><a href="#" className="hover:text-white transition-colors">Conditions d'utilisation</a></li>
              </ul>
            </div>
          </div>
          
          <div className="border-t border-gray-800 mt-8 pt-8 text-center text-gray-400">
            <p>&copy; 2024 KiloShare. Tous droits réservés.</p>
          </div>
        </div>
      </footer>
    </div>
  );
}