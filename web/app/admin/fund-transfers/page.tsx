'use client'

import { useState, useEffect } from 'react'
import { adminAPI } from '@/utils/adminApi'

interface BookingReadyForTransfer {
  booking_id: number
  booking_uuid: string
  trip_id: number
  trip_route: string
  transporter: {
    id: number
    name: string
    email: string
  }
  sender: {
    id: number
    name: string
    email: string
  }
  delivery_confirmed_at: string
  delivery_code_validated: boolean
  payment_status: string
  amounts: {
    total: number
    commission: number
    transfer: number
    currency: string
  }
}

interface CompletedTransfer {
  booking_id: number
  booking_uuid: string
  trip_id: number
  trip_route: string
  transporter: {
    id: number
    name: string
    email: string
  }
  sender: {
    id: number
    name: string
    email: string
  }
  transfer_details: {
    transferred_at: string
    transfer_id: string
    stripe_account_id: string
  }
  amounts: {
    total: number
    platform_fee: number
    transferred: number
    currency: string
  }
}

export default function FundTransfersPage() {
  const [activeTab, setActiveTab] = useState<'pending' | 'completed'>('pending')
  const [bookings, setBookings] = useState<BookingReadyForTransfer[]>([])
  const [completedTransfers, setCompletedTransfers] = useState<CompletedTransfer[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [processingId, setProcessingId] = useState<number | null>(null)
  const [successMessage, setSuccessMessage] = useState('')

  useEffect(() => {
    if (activeTab === 'pending') {
      loadBookings()
    } else {
      loadCompletedTransfers()
    }
  }, [activeTab])

  const loadBookings = async () => {
    try {
      setLoading(true)
      const response = await adminAPI.get('/api/v1/admin/bookings/ready-for-transfer')
      const data = await response.json()

      if (data.data?.bookings) {
        setBookings(data.data.bookings)
      }
    } catch (err: any) {
      setError(err.message || 'Erreur lors du chargement des réservations')
    } finally {
      setLoading(false)
    }
  }

  const loadCompletedTransfers = async () => {
    try {
      setLoading(true)
      const response = await adminAPI.get('/api/v1/admin/transfers/completed')
      const data = await response.json()

      if (data.data?.transfers) {
        setCompletedTransfers(data.data.transfers)
      }
    } catch (err: any) {
      setError(err.message || 'Erreur lors du chargement des transferts complétés')
    } finally {
      setLoading(false)
    }
  }

  const handleTransfer = async (bookingId: number) => {
    if (!confirm('Êtes-vous sûr de vouloir transférer les fonds au transporteur ?')) {
      return
    }

    try {
      setProcessingId(bookingId)
      setError('')
      setSuccessMessage('')

      const response = await adminAPI.post(`/api/v1/admin/bookings/${bookingId}/transfer-funds`, {})
      const data = await response.json()

      if (data.data) {
        setSuccessMessage(`Transfert réussi : ${data.data.message}`)
        await loadBookings()
      }
    } catch (err: any) {
      setError(err.message || 'Erreur lors du transfert')
    } finally {
      setProcessingId(null)
    }
  }

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleDateString('fr-FR', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    })
  }

  const formatCurrency = (amount: number, currency: string) => {
    return new Intl.NumberFormat('fr-CA', {
      style: 'currency',
      currency: currency,
    }).format(amount)
  }

  if (loading) {
    return (
      <div className="container-fluid p-4">
        <div className="text-center py-5">
          <div className="spinner-border text-primary" role="status">
            <span className="visually-hidden">Chargement...</span>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="container-fluid p-4">
      <div className="mb-4">
        <h1 className="h2 fw-bold text-dark">Transferts de fonds</h1>
        <p className="text-muted">
          Gérez les transferts de fonds vers les transporteurs après livraison confirmée
        </p>
      </div>

      {error && (
        <div className="alert alert-danger d-flex align-items-start mb-4" role="alert">
          <i className="bi bi-exclamation-circle-fill me-3 fs-5"></i>
          <div>
            <h6 className="alert-heading mb-1">Erreur</h6>
            <p className="mb-0">{error}</p>
          </div>
        </div>
      )}

      {successMessage && (
        <div className="alert alert-success d-flex align-items-start mb-4" role="alert">
          <i className="bi bi-check-circle-fill me-3 fs-5"></i>
          <div>
            <h6 className="alert-heading mb-1">Succès</h6>
            <p className="mb-0">{successMessage}</p>
          </div>
        </div>
      )}

      {/* Onglets */}
      <ul className="nav nav-tabs mb-4">
        <li className="nav-item">
          <button
            className={`nav-link ${activeTab === 'pending' ? 'active' : ''}`}
            onClick={() => setActiveTab('pending')}
          >
            <i className="bi bi-clock-history me-2"></i>
            En attente ({bookings.length})
          </button>
        </li>
        <li className="nav-item">
          <button
            className={`nav-link ${activeTab === 'completed' ? 'active' : ''}`}
            onClick={() => setActiveTab('completed')}
          >
            <i className="bi bi-check-circle me-2"></i>
            Historique ({completedTransfers.length})
          </button>
        </li>
      </ul>

      {/* Contenu de l'onglet "En attente" */}
      {activeTab === 'pending' && bookings.length === 0 ? (
        <div className="card">
          <div className="card-body text-center py-5">
            <i className="bi bi-inbox fs-1 text-muted mb-3 d-block"></i>
            <h5 className="card-title">Aucun transfert en attente</h5>
            <p className="card-text text-muted">
              Il n'y a actuellement aucune réservation livrée en attente de transfert de fonds.
            </p>
          </div>
        </div>
      ) : activeTab === 'pending' ? (
        <>
          <div className="alert alert-info mb-4">
            <i className="bi bi-info-circle me-2"></i>
            <strong>{bookings.length}</strong> réservation{bookings.length > 1 ? 's' : ''} prête{bookings.length > 1 ? 's' : ''} pour le transfert
          </div>

          <div className="row g-4">
            {bookings.map((booking) => (
              <div key={booking.booking_id} className="col-12">
                <div className="card shadow-sm">
                  <div className="card-body">
                    <div className="d-flex justify-content-between align-items-start mb-3">
                      <div className="flex-grow-1">
                        <div className="d-flex align-items-center mb-2">
                          <i className="bi bi-truck fs-5 text-muted me-2"></i>
                          <h5 className="card-title mb-0">{booking.trip_route}</h5>
                        </div>
                        <p className="text-muted small mb-0">
                          Réservation #{booking.booking_id} • {booking.booking_uuid}
                        </p>
                      </div>
                      <div className="text-end">
                        <div className="fs-3 fw-bold text-success">
                          {formatCurrency(booking.amounts.transfer, booking.amounts.currency)}
                        </div>
                        <small className="text-muted">Montant à transférer</small>
                      </div>
                    </div>

                    <div className="row mb-3">
                      <div className="col-md-6 mb-3 mb-md-0">
                        <div className="card bg-light border-0">
                          <div className="card-body">
                            <div className="d-flex align-items-center mb-2">
                              <i className="bi bi-person-fill text-muted me-2"></i>
                              <small className="text-muted fw-semibold">Transporteur</small>
                            </div>
                            <p className="mb-1 fw-semibold">{booking.transporter.name}</p>
                            <small className="text-muted">{booking.transporter.email}</small>
                          </div>
                        </div>
                      </div>
                      <div className="col-md-6">
                        <div className="card bg-light border-0">
                          <div className="card-body">
                            <div className="d-flex align-items-center mb-2">
                              <i className="bi bi-person-fill text-muted me-2"></i>
                              <small className="text-muted fw-semibold">Expéditeur</small>
                            </div>
                            <p className="mb-1 fw-semibold">{booking.sender.name}</p>
                            <small className="text-muted">{booking.sender.email}</small>
                          </div>
                        </div>
                      </div>
                    </div>

                    <div className="card bg-light border-0 mb-3">
                      <div className="card-body">
                        <div className="row text-center">
                          <div className="col-4">
                            <small className="text-muted d-block mb-1">Montant total</small>
                            <p className="fw-semibold mb-0">
                              {formatCurrency(booking.amounts.total, booking.amounts.currency)}
                            </p>
                          </div>
                          <div className="col-4">
                            <small className="text-muted d-block mb-1">Commission (15%)</small>
                            <p className="fw-semibold mb-0">
                              {formatCurrency(booking.amounts.commission, booking.amounts.currency)}
                            </p>
                          </div>
                          <div className="col-4">
                            <small className="text-muted d-block mb-1">À transférer (85%)</small>
                            <p className="fw-semibold mb-0 text-success">
                              {formatCurrency(booking.amounts.transfer, booking.amounts.currency)}
                            </p>
                          </div>
                        </div>
                      </div>
                    </div>

                    <div className="d-flex justify-content-between align-items-center pt-3 border-top">
                      <div className="d-flex gap-3">
                        <small className="text-muted">
                          <i className="bi bi-check-circle-fill text-success me-1"></i>
                          Livré le {formatDate(booking.delivery_confirmed_at)}
                        </small>
                        {booking.delivery_code_validated && (
                          <small className="text-muted">
                            <i className="bi bi-check-circle-fill text-success me-1"></i>
                            Code validé
                          </small>
                        )}
                      </div>

                      <button
                        onClick={() => handleTransfer(booking.booking_id)}
                        disabled={processingId === booking.booking_id}
                        className="btn btn-primary d-flex align-items-center"
                      >
                        <i className="bi bi-currency-dollar me-2"></i>
                        {processingId === booking.booking_id ? (
                          <>
                            <span className="spinner-border spinner-border-sm me-2" role="status" aria-hidden="true"></span>
                            Transfert en cours...
                          </>
                        ) : (
                          'Transférer les fonds'
                        )}
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </>
      ) : (
        /* Onglet "Historique" */
        completedTransfers.length === 0 ? (
          <div className="card">
            <div className="card-body text-center py-5">
              <i className="bi bi-archive fs-1 text-muted mb-3 d-block"></i>
              <h5 className="card-title">Aucun transfert complété</h5>
              <p className="card-text text-muted">
                L'historique des transferts effectués apparaîtra ici.
              </p>
            </div>
          </div>
        ) : (
          <div className="table-responsive">
            <table className="table table-hover">
              <thead className="table-light">
                <tr>
                  <th>Réservation</th>
                  <th>Voyage</th>
                  <th>Transporteur</th>
                  <th>Expéditeur</th>
                  <th>Montant total</th>
                  <th>Frais plateforme</th>
                  <th>Montant transféré</th>
                  <th>Date de transfert</th>
                  <th>ID Transfert</th>
                </tr>
              </thead>
              <tbody>
                {completedTransfers.map((transfer) => (
                  <tr key={transfer.booking_id}>
                    <td>
                      <span className="badge bg-secondary">#{transfer.booking_id}</span>
                      <br />
                      <small className="text-muted">{transfer.booking_uuid}</small>
                    </td>
                    <td>
                      <i className="bi bi-geo-alt me-1"></i>
                      {transfer.trip_route}
                    </td>
                    <td>
                      <strong>{transfer.transporter.name}</strong>
                      <br />
                      <small className="text-muted">{transfer.transporter.email}</small>
                    </td>
                    <td>
                      {transfer.sender.name}
                      <br />
                      <small className="text-muted">{transfer.sender.email}</small>
                    </td>
                    <td>
                      <strong>{formatCurrency(transfer.amounts.total, transfer.amounts.currency)}</strong>
                    </td>
                    <td className="text-danger">
                      -{formatCurrency(transfer.amounts.platform_fee, transfer.amounts.currency)}
                    </td>
                    <td className="text-success">
                      <strong>{formatCurrency(transfer.amounts.transferred, transfer.amounts.currency)}</strong>
                    </td>
                    <td>
                      <i className="bi bi-calendar3 me-1"></i>
                      {formatDate(transfer.transfer_details.transferred_at)}
                    </td>
                    <td>
                      <code className="small">{transfer.transfer_details.transfer_id}</code>
                      <br />
                      <small className="text-muted">
                        <i className="bi bi-credit-card me-1"></i>
                        {transfer.transfer_details.stripe_account_id.substring(0, 20)}...
                      </small>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )
      )}
    </div>
  )
}
