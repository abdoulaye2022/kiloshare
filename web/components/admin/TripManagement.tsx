'use client';

import { useState, useEffect } from 'react';
import adminAuth from '../../lib/admin-auth';

interface TripImage {
  id: number;
  trip_id: number;
  image_url: string;
  url?: string;
  image_path?: string;
  is_primary?: boolean;
  caption?: string;
}

interface TripImageData {
  id: number;
  trip_id: number;
  image_url?: string;
  url?: string;
  file_path?: string;
  is_primary?: boolean;
  description?: string;
}

interface Trip {
  id: number;
  uuid: string;
  title?: string;
  description?: string;
  transport_type: string | null;
  departure_city: string;
  departure_country: string;
  arrival_city: string;
  arrival_country: string;
  departure_date: string;
  arrival_date?: string;
  max_weight?: number;
  available_weight_kg?: string;
  price_per_kg: string;
  total_reward?: number;
  currency: string;
  status: string;
  is_domestic?: boolean;
  restrictions?: any;
  special_instructions?: string;
  published_at?: string;
  expires_at?: string;
  created_at: string;
  updated_at: string;
  user: {
    first_name: string;
    last_name: string;
    email: string;
    trust_score?: number;
    total_trips?: number;
  };
  trips_count?: number;
  bookings_count?: number;
  images?: TripImage[];
  trip_images?: TripImageData[];
}

export default function TripManagement() {
  const [trips, setTrips] = useState<Trip[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [filter, setFilter] = useState<'all' | 'draft' | 'pending_review' | 'published' | 'active' | 'rejected' | 'paused' | 'completed' | 'cancelled' | 'expired'>('all');
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedTrip, setSelectedTrip] = useState<Trip | null>(null);
  const [showTripDetails, setShowTripDetails] = useState(false);
  const [alertMessage, setAlertMessage] = useState<{ type: 'success' | 'error' | 'info' | 'warning', message: string } | null>(null);

  useEffect(() => {
    fetchTrips();
  }, [filter]);

  // Auto-dismiss alert after 5 seconds for success messages
  useEffect(() => {
    if (alertMessage && alertMessage.type === 'success') {
      const timer = setTimeout(() => {
        setAlertMessage(null);
      }, 5000);
      return () => clearTimeout(timer);
    }
  }, [alertMessage]);

  const fetchTrips = async () => {
    try {
      setLoading(true);
      setError(null);

      const endpoint = filter === 'pending_review'
        ? `/api/admin/trips/pending?include=images`
        : `/api/v1/admin/trips?status=${filter}&limit=50&include=images`;

      const token = await adminAuth.getValidAccessToken();
      if (!token) {
        setError('Token d\'authentification manquant');
        setLoading(false);
        return;
      }

      const response = await fetch(endpoint, {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
      });

      if (response.ok) {
        const data = await response.json();
        console.log('API Response:', data);
        const tripsData = data.data?.trips || data.trips || [];
        console.log('Trips data:', tripsData, 'Is array?', Array.isArray(tripsData));
        // S'assurer que c'est un tableau
        setTrips(Array.isArray(tripsData) ? tripsData : []);
        setError(null);
      } else {
        // Essayer de parser le JSON, sinon utiliser le texte brut
        let errorMessage = 'Erreur lors de la récupération des voyages';
        try {
          const errorData = await response.json();
          errorMessage = errorData.message || errorData.error || errorMessage;
        } catch (e) {
          // Si ce n'est pas du JSON, lire le texte
          const errorText = await response.text();
          console.error('Non-JSON error response:', errorText);
          errorMessage = `Erreur ${response.status}: ${errorText.substring(0, 100)}`;
        }
        setError(errorMessage);
        console.error('Failed to fetch trips:', response.status);
      }
    } catch (error) {
      console.error('Error fetching trips:', error);
      setError(`Erreur de connexion au serveur: ${error instanceof Error ? error.message : 'Erreur inconnue'}`);
      // S'assurer que trips est un tableau même en cas d'erreur
      setTrips([]);
    } finally {
      setLoading(false);
    }
  };

  const handleTripAction = async (tripId: number, action: 'approve' | 'reject' | 'publish' | 'pause' | 'resume' | 'cancel') => {
    try {
      let endpoint = '';
      let body: any = { id: tripId };

      switch (action) {
        case 'approve':
          endpoint = '/api/admin/trips/approve';
          break;
        case 'reject':
          const reason = prompt('Raison du rejet (optionnel):');
          endpoint = '/api/admin/trips/reject';
          body.reason = reason;
          break;
        default:
          console.error('Action not supported:', action);
          return;
      }

      // Appeler la route Next.js proxy (pas directement le backend)
      const token = await adminAuth.getValidAccessToken();
      if (!token) {
        setAlertMessage({ type: 'error', message: 'Session expirée. Veuillez vous reconnecter.' });
        return;
      }

      const response = await fetch(endpoint, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(body),
      });

      if (response.ok) {
        fetchTrips();
        if (selectedTrip && selectedTrip.id === tripId) {
          setSelectedTrip(null);
          setShowTripDetails(false);
        }
        setAlertMessage({
          type: 'success',
          message: action === 'approve' ? 'Annonce approuvée avec succès!' : 'Action effectuée avec succès!'
        });
      } else {
        // Essayer de parser le JSON, sinon utiliser le texte brut
        let errorMessage = 'Une erreur est survenue';
        try {
          const errorData = await response.json();
          errorMessage = errorData.message || errorData.error || errorMessage;
        } catch (e) {
          const errorText = await response.text();
          console.error('Non-JSON error response:', errorText);
          errorMessage = `Erreur ${response.status}`;
        }
        setAlertMessage({ type: 'error', message: errorMessage });
      }
    } catch (error) {
      console.error(`Error ${action}ing trip:`, error);
      setAlertMessage({
        type: 'error',
        message: `Erreur lors de l'action: ${error instanceof Error ? error.message : 'Erreur inconnue'}`
      });
    }
  };

  const getTripStatusBadge = (status: string) => {
    const badgeClasses = {
      draft: 'badge bg-secondary',
      pending_review: 'badge bg-warning text-dark',
      published: 'badge bg-success',
      active: 'badge bg-info',
      rejected: 'badge bg-danger',
      paused: 'badge bg-warning text-dark',
      completed: 'badge bg-primary',
      cancelled: 'badge bg-secondary',
      expired: 'badge bg-danger'
    };

    const statusLabels = {
      draft: 'Brouillon',
      pending_review: 'En attente',
      published: 'Publié',
      active: 'Actif',
      rejected: 'Rejeté',
      paused: 'En pause',
      completed: 'Terminé',
      cancelled: 'Annulé',
      expired: 'Expiré'
    };

    return (
      <span className={badgeClasses[status as keyof typeof badgeClasses] || 'badge bg-secondary'}>
        {statusLabels[status as keyof typeof statusLabels] || status}
      </span>
    );
  };

  const getTransportIcon = (type: string | null) => {
    switch (type) {
      case 'plane': return '✈️';
      case 'train': return '🚂';
      case 'bus': return '🚌';
      case 'car': return '🚗';
      default: return '🎒';
    }
  };

  const formatCurrency = (amount: string | number, currency: string = 'CAD') => {
    const value = typeof amount === 'string' ? parseFloat(amount) : amount;
    return new Intl.NumberFormat('fr-CA', {
      style: 'currency',
      currency: currency
    }).format(value || 0);
  };

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleDateString('fr-FR', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  // Fonction pour normaliser les images selon les différents formats API
  const getNormalizedImages = (trip: Trip): TripImage[] => {
    if (trip.images && trip.images.length > 0) {
      return trip.images.map(img => ({
        id: img.id,
        trip_id: img.trip_id,
        image_url: img.image_url || (img as any).url || img.image_path || '',
        image_path: img.image_path,
        is_primary: img.is_primary,
        caption: img.caption
      }));
    }

    if (trip.trip_images && trip.trip_images.length > 0) {
      return trip.trip_images.map(img => ({
        id: img.id,
        trip_id: img.trip_id,
        image_url: img.image_url || (img as any).url || img.file_path || '',
        image_path: img.file_path,
        is_primary: img.is_primary,
        caption: img.description
      }));
    }

    return [];
  };

  const filteredTrips = (Array.isArray(trips) ? trips : []).filter(trip => {
    const matchesSearch = searchTerm === '' ||
      trip.departure_city?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      trip.arrival_city?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      `${trip.user?.first_name || ''} ${trip.user?.last_name || ''}`.toLowerCase().includes(searchTerm.toLowerCase()) ||
      trip.user?.email?.toLowerCase().includes(searchTerm.toLowerCase());
    return matchesSearch;
  });

  if (loading) {
    return (
      <div className="container-fluid p-4">
        <div className="d-flex justify-content-center align-items-center" style={{minHeight: '400px'}}>
          <div className="spinner-border text-primary" role="status">
            <span className="visually-hidden">Chargement...</span>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="container-fluid p-4">
      {/* Header */}
      <div className="row mb-4">
        <div className="col-12">
          <div className="d-flex justify-content-between align-items-center mb-4">
            <div>
              <h2 className="h3 mb-0 fw-bold">Gestion des voyages</h2>
              <p className="text-muted mb-0">Gérez tous les voyages de la plateforme</p>
            </div>
          </div>
        </div>
      </div>

      {/* Alert Messages */}
      {alertMessage && (
        <div className="row mb-4">
          <div className="col-12">
            <div className={`alert alert-${alertMessage.type === 'error' ? 'danger' : alertMessage.type} alert-dismissible fade show`} role="alert">
              <i className={`bi ${
                alertMessage.type === 'success' ? 'bi-check-circle-fill' :
                alertMessage.type === 'error' ? 'bi-exclamation-triangle-fill' :
                alertMessage.type === 'warning' ? 'bi-exclamation-circle-fill' :
                'bi-info-circle-fill'
              } me-2`}></i>
              {alertMessage.message}
              <button
                type="button"
                className="btn-close"
                onClick={() => setAlertMessage(null)}
                aria-label="Close"
              ></button>
            </div>
          </div>
        </div>
      )}

      {/* Error Alert */}
      {error && (
        <div className="row mb-4">
          <div className="col-12">
            <div className="alert alert-danger alert-dismissible fade show" role="alert">
              <i className="bi bi-exclamation-triangle-fill me-2"></i>
              {error}
              <button
                type="button"
                className="btn-close"
                onClick={() => setError(null)}
                aria-label="Close"
              ></button>
            </div>
          </div>
        </div>
      )}

      {/* Filters and Search */}
      <div className="row mb-4">
        <div className="col-12">
          <div className="card">
            <div className="card-body">
              <div className="row g-3 align-items-center">
                <div className="col-md-3">
                  <label className="form-label fw-medium">Statut:</label>
                  <select
                    value={filter}
                    onChange={(e) => setFilter(e.target.value as any)}
                    className="form-select"
                  >
                    <option value="all">Tous</option>
                    <option value="pending_review">En attente de révision</option>
                    <option value="published">Publiés</option>
                    <option value="active">Actifs</option>
                    <option value="draft">Brouillons</option>
                    <option value="paused">En pause</option>
                    <option value="completed">Terminés</option>
                    <option value="cancelled">Annulés</option>
                    <option value="rejected">Rejetés</option>
                    <option value="expired">Expirés</option>
                  </select>
                </div>

                <div className="col-md-6">
                  <label className="form-label fw-medium">Rechercher:</label>
                  <div className="input-group">
                    <span className="input-group-text">
                      <i className="bi bi-search"></i>
                    </span>
                    <input
                      type="text"
                      placeholder="Rechercher par ville, utilisateur, email..."
                      value={searchTerm}
                      onChange={(e) => setSearchTerm(e.target.value)}
                      className="form-control"
                    />
                  </div>
                </div>

                <div className="col-md-3">
                  <div className="text-center">
                    <div className="h4 mb-0 text-primary">{filteredTrips.length}</div>
                    <small className="text-muted">voyage{filteredTrips.length !== 1 ? 's' : ''}</small>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Trips List */}
      <div className="row">
        <div className="col-12">
          <div className="card">
            <div className="card-header">
              <h5 className="card-title mb-0">
                <i className="bi bi-airplane me-2"></i>
                Liste des voyages
              </h5>
            </div>
            <div className="card-body p-0">
              {filteredTrips.length === 0 ? (
                <div className="text-center py-5">
                  <div className="text-muted mb-3" style={{fontSize: '3rem'}}>✈️</div>
                  <h5 className="text-muted">Aucun voyage trouvé</h5>
                  <p className="text-muted">
                    {searchTerm ? 'Essayez de modifier vos critères de recherche' : 'Aucun voyage ne correspond aux filtres sélectionnés'}
                  </p>
                </div>
              ) : (
                <div className="table-responsive">
                  <table className="table table-hover mb-0">
                    <thead className="table-light">
                      <tr>
                        <th>Voyage</th>
                        <th>Route</th>
                        <th>Prix</th>
                        <th>Statut</th>
                        <th>Utilisateur</th>
                        <th>Date création</th>
                        <th>Actions</th>
                      </tr>
                    </thead>
                    <tbody>
                      {filteredTrips.map((trip) => (
                        <tr key={trip.id}>
                          <td>
                            <div className="d-flex align-items-center">
                              <div className="me-3" style={{fontSize: '1.5rem'}}>
                                {getTransportIcon(trip.transport_type)}
                              </div>
                              <div className="flex-grow-1">
                                <div className="d-flex align-items-center">
                                  <div className="fw-medium me-2">
                                    {trip.title || `${trip.departure_city} → ${trip.arrival_city}`}
                                  </div>
                                  {(() => {
                                    const images = getNormalizedImages(trip);
                                    return images.length > 0 && (
                                      <span className="badge bg-info text-dark" title={`${images.length} image${images.length > 1 ? 's' : ''}`}>
                                        <i className="bi bi-images me-1"></i>
                                        {images.length}
                                      </span>
                                    );
                                  })()}
                                </div>
                                <div className="text-muted small">
                                  Départ: {formatDate(trip.departure_date)}
                                </div>
                              </div>
                            </div>
                          </td>
                          <td>
                            <div>
                              <div className="fw-medium">
                                {trip.departure_city}, {trip.departure_country}
                              </div>
                              <div className="text-muted">
                                <i className="bi bi-arrow-down me-1"></i>
                                {trip.arrival_city}, {trip.arrival_country}
                              </div>
                            </div>
                          </td>
                          <td>
                            <div className="fw-medium">
                              {formatCurrency(trip.price_per_kg, trip.currency)}/kg
                            </div>
                            {trip.available_weight_kg && (
                              <div className="text-muted small">
                                {trip.available_weight_kg} kg disponible
                              </div>
                            )}
                          </td>
                          <td>
                            {getTripStatusBadge(trip.status)}
                          </td>
                          <td>
                            <div>
                              <div className="fw-medium">
                                {trip.user.first_name} {trip.user.last_name}
                              </div>
                              <div className="text-muted small">
                                {trip.user.email}
                              </div>
                              {trip.user.total_trips && (
                                <div className="text-primary small">
                                  {trip.user.total_trips} voyage{trip.user.total_trips !== 1 ? 's' : ''}
                                </div>
                              )}
                            </div>
                          </td>
                          <td className="text-muted small">
                            {formatDate(trip.created_at)}
                          </td>
                          <td>
                            <div className="btn-group btn-group-sm">
                              <button
                                onClick={() => {
                                  setSelectedTrip(trip);
                                  setShowTripDetails(true);
                                }}
                                className="btn btn-outline-primary"
                                title="Voir les détails"
                              >
                                <i className="bi bi-eye"></i>
                              </button>

                              {trip.status === 'pending_review' && (
                                <>
                                  <button
                                    onClick={() => handleTripAction(trip.id, 'approve')}
                                    className="btn btn-outline-success"
                                    title="Approuver"
                                  >
                                    <i className="bi bi-check-circle"></i>
                                  </button>
                                  <button
                                    onClick={() => handleTripAction(trip.id, 'reject')}
                                    className="btn btn-outline-danger"
                                    title="Rejeter"
                                  >
                                    <i className="bi bi-x-circle"></i>
                                  </button>
                                </>
                              )}
                            </div>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </div>
          </div>
        </div>
      </div>

      {/* Trip Details Modal */}
      {showTripDetails && selectedTrip && (
        <div className="modal show d-block" style={{ backgroundColor: 'rgba(0,0,0,0.5)' }}>
          <div className="modal-dialog modal-xl modal-dialog-centered">
            <div className="modal-content">
              <div className="modal-header">
                <h5 className="modal-title">
                  <i className="bi bi-airplane me-2"></i>
                  Détails du voyage
                </h5>
                <button
                  type="button"
                  className="btn-close"
                  onClick={() => setShowTripDetails(false)}
                ></button>
              </div>
              <div className="modal-body">
                {/* Basic Info */}
                <div className="row g-3 mb-4">
                  <div className="col-md-6">
                    <label className="form-label fw-medium">Route</label>
                    <p className="mb-0">
                      {getTransportIcon(selectedTrip.transport_type)} {selectedTrip.departure_city}, {selectedTrip.departure_country} → {selectedTrip.arrival_city}, {selectedTrip.arrival_country}
                    </p>
                  </div>
                  <div className="col-md-6">
                    <label className="form-label fw-medium">Statut</label>
                    <div>{getTripStatusBadge(selectedTrip.status)}</div>
                  </div>
                  <div className="col-md-6">
                    <label className="form-label fw-medium">Prix par kg</label>
                    <p className="mb-0">
                      {formatCurrency(selectedTrip.price_per_kg, selectedTrip.currency)}
                    </p>
                  </div>
                  <div className="col-md-6">
                    <label className="form-label fw-medium">Poids disponible</label>
                    <p className="mb-0">
                      {selectedTrip.available_weight_kg || 'Non spécifié'} kg
                    </p>
                  </div>
                </div>

                {/* Dates */}
                <div className="row g-3 mb-4">
                  <div className="col-md-6">
                    <label className="form-label fw-medium">Date de départ</label>
                    <p className="mb-0">
                      {formatDate(selectedTrip.departure_date)}
                    </p>
                  </div>
                  <div className="col-md-6">
                    <label className="form-label fw-medium">Date de création</label>
                    <p className="mb-0">
                      {formatDate(selectedTrip.created_at)}
                    </p>
                  </div>
                </div>

                {/* Description */}
                {selectedTrip.description && (
                  <div className="mb-4">
                    <label className="form-label fw-medium">Description</label>
                    <div className="card">
                      <div className="card-body">
                        {selectedTrip.description}
                      </div>
                    </div>
                  </div>
                )}


                {/* Images */}
                {(() => {
                  const images = getNormalizedImages(selectedTrip);
                  if (images.length > 0) {
                    return (
                      <div className="mb-4">
                        <label className="form-label fw-medium">
                          <i className="bi bi-images me-2"></i>
                          Images du voyage ({images.length})
                        </label>
                        <div className="row g-3">
                          {images.map((image, index) => (
                          <div key={image.id} className="col-md-4 col-sm-6">
                            <div className="card">
                              <div className="position-relative">
                                <img
                                  src={image.image_url}
                                  alt={image.caption || `Image ${index + 1} du voyage`}
                                  className="card-img-top"
                                  style={{
                                    height: '200px',
                                    objectFit: 'cover',
                                    cursor: 'pointer'
                                  }}
                                  onClick={() => window.open(image.image_url, '_blank')}
                                />
                                {image.is_primary && (
                                  <span className="position-absolute top-0 start-0 badge bg-primary m-2">
                                    <i className="bi bi-star-fill me-1"></i>
                                    Principale
                                  </span>
                                )}
                                <div className="position-absolute top-0 end-0 m-2">
                                  <button
                                    className="btn btn-sm btn-light opacity-75"
                                    onClick={() => window.open(image.image_url, '_blank')}
                                    title="Voir en grand"
                                  >
                                    <i className="bi bi-zoom-in"></i>
                                  </button>
                                </div>
                              </div>
                              {image.caption && (
                                <div className="card-body p-2">
                                  <small className="text-muted">{image.caption}</small>
                                </div>
                              )}
                            </div>
                            </div>
                          ))}
                        </div>
                      </div>
                    );
                  } else {
                    return (
                      <div className="mb-4">
                        <label className="form-label fw-medium">
                          <i className="bi bi-images me-2"></i>
                          Images du voyage
                        </label>
                        <div className="alert alert-info">
                          <i className="bi bi-info-circle me-2"></i>
                          Aucune image trouvée pour ce voyage.
                        </div>
                      </div>
                    );
                  }
                })()}

                {/* User Info */}
                <div className="border-top pt-4">
                  <h6 className="fw-bold mb-3">
                    <i className="bi bi-person-fill me-2"></i>
                    Informations utilisateur
                  </h6>
                  <div className="row g-3">
                    <div className="col-md-6">
                      <label className="form-label fw-medium">Nom complet</label>
                      <p className="mb-0">
                        {selectedTrip.user.first_name} {selectedTrip.user.last_name}
                      </p>
                    </div>
                    <div className="col-md-6">
                      <label className="form-label fw-medium">Email</label>
                      <p className="mb-0">
                        {selectedTrip.user.email}
                      </p>
                    </div>
                    {selectedTrip.user.total_trips && (
                      <div className="col-md-6">
                        <label className="form-label fw-medium">Voyages publiés</label>
                        <p className="mb-0">
                          {selectedTrip.user.total_trips}
                        </p>
                      </div>
                    )}
                  </div>
                </div>
              </div>
              <div className="modal-footer">
                <div className="d-flex gap-2">
                  {selectedTrip.status === 'pending_review' && (
                    <>
                      <button
                        onClick={() => handleTripAction(selectedTrip.id, 'approve')}
                        className="btn btn-success"
                      >
                        <i className="bi bi-check-circle me-1"></i>
                        Approuver le voyage
                      </button>
                      <button
                        onClick={() => handleTripAction(selectedTrip.id, 'reject')}
                        className="btn btn-danger"
                      >
                        <i className="bi bi-x-circle me-1"></i>
                        Rejeter le voyage
                      </button>
                    </>
                  )}
                  <button
                    onClick={() => setShowTripDetails(false)}
                    className="btn btn-secondary"
                  >
                    Fermer
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}