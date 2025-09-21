'use client';

import { useState, useCallback } from 'react';
import { useAuth } from './useAuth';

interface BookingNegotiation {
  id: number;
  booking_id: number;
  proposed_by: number;
  amount: number;
  message: string | null;
  is_accepted: boolean;
  created_at: string;
  first_name?: string;
  email?: string;
}

interface AcceptNegotiationResponse {
  success: boolean;
  message: string;
  booking: any;
  stripe_account_created?: boolean;
  stripe_account?: {
    id: number;
    user_id: number;
    stripe_account_id: string;
    status: string;
    onboarding_url: string;
    expected_amount: number;
  };
  motivational_message?: string;
  next_action?: string;
}

export function useBooking() {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const { token } = useAuth();


  const acceptBooking = useCallback(async (
    bookingId: number,
    finalPrice?: number
  ): Promise<AcceptNegotiationResponse | null> => {
    if (!token) {
      setError('Non authentifié');
      return null;
    }

    setLoading(true);
    setError(null);

    try {
      const response = await fetch(
        `${process.env.NEXT_PUBLIC_API_URL}/api/v1/bookings/${bookingId}/accept`,
        {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(finalPrice ? { final_price: finalPrice } : {})
        }
      );

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || 'Erreur lors de l\'acceptation de la réservation');
      }

      return data;

    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Erreur inconnue';
      setError(errorMessage);
      console.error('Erreur acceptBooking:', err);
      return null;
    } finally {
      setLoading(false);
    }
  }, [token]);

  const rejectBooking = useCallback(async (
    bookingId: number,
    reason?: string
  ): Promise<AcceptNegotiationResponse | null> => {
    if (!token) {
      setError('Non authentifié');
      return null;
    }

    setLoading(true);
    setError(null);

    try {
      const response = await fetch(
        `${process.env.NEXT_PUBLIC_API_URL}/api/v1/bookings/${bookingId}/reject`,
        {
          method: 'PUT',
          headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json',
          },
          body: reason ? JSON.stringify({ reason }) : undefined
        }
      );

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || 'Erreur lors du rejet de la réservation');
      }

      return data;

    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Erreur inconnue';
      setError(errorMessage);
      console.error('Erreur rejectBooking:', err);
      return null;
    } finally {
      setLoading(false);
    }
  }, [token]);

  const getBooking = useCallback(async (bookingId: number) => {
    if (!token) {
      setError('Non authentifié');
      return null;
    }

    setLoading(true);
    setError(null);

    try {
      const response = await fetch(
        `${process.env.NEXT_PUBLIC_API_URL}/api/v1/bookings/${bookingId}`,
        {
          headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json',
          }
        }
      );

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || 'Erreur lors de la récupération de la réservation');
      }

      return data.booking;

    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Erreur inconnue';
      setError(errorMessage);
      console.error('Erreur getBooking:', err);
      return null;
    } finally {
      setLoading(false);
    }
  }, [token]);

  const getUserBookings = useCallback(async (role: 'sender' | 'receiver' | 'all' = 'all') => {
    if (!token) {
      setError('Non authentifié');
      return null;
    }

    setLoading(true);
    setError(null);

    try {
      const response = await fetch(
        `${process.env.NEXT_PUBLIC_API_URL}/api/v1/bookings/list?role=${role}`,
        {
          headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json',
          }
        }
      );

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || 'Erreur lors de la récupération des réservations');
      }

      return data.bookings;

    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Erreur inconnue';
      setError(errorMessage);
      console.error('Erreur getUserBookings:', err);
      return null;
    } finally {
      setLoading(false);
    }
  }, [token]);

  const cancelBooking = useCallback(async (
    bookingId: number
  ): Promise<AcceptNegotiationResponse | null> => {
    if (!token) {
      setError('Non authentifié');
      return null;
    }

    setLoading(true);
    setError(null);

    try {
      const response = await fetch(
        `${process.env.NEXT_PUBLIC_API_URL}/api/v1/bookings/${bookingId}/cancel`,
        {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json',
          }
        }
      );

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || 'Erreur lors de l\'annulation de la réservation');
      }

      return data;

    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Erreur inconnue';
      setError(errorMessage);
      console.error('Erreur cancelBooking:', err);
      return null;
    } finally {
      setLoading(false);
    }
  }, [token]);

  return {
    loading,
    error,
    acceptBooking,
    rejectBooking,
    cancelBooking,
    getBooking,
    getUserBookings,
    clearError: () => setError(null)
  };
}