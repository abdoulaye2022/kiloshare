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

export default function FundTransfersPage() {
  const [bookings, setBookings] = useState<BookingReadyForTransfer[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [processingId, setProcessingId] = useState<number | null>(null)
  const [successMessage, setSuccessMessage] = useState('')

  useEffect(() => {
    loadBookings()
  }, [])

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

      {bookings.length === 0 ? (
        <div className="card">
          <div className="card-body text-center py-5">
            <i className="bi bi-inbox fs-1 text-muted mb-3 d-block"></i>
            <h5 className="card-title">Aucun transfert en attente</h5>
            <p className="card-text text-muted">
              Il n'y a actuellement aucune réservation livrée en attente de transfert de fonds.
            </p>
          </div>
        </div>
      ) : (
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
      )}
    </div>
  )
}
