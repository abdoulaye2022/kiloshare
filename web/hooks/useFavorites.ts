'use client';

import { useState, useCallback } from 'react';
import { useAuth } from './useAuth';

interface Trip {
  id: number;
  uuid: string;
  departure_city: string;
  departure_country: string;
  arrival_city: string;
  arrival_country: string;
  departure_date: string;
  available_weight_kg: number;
  price_per_kg: number;
  currency: string;
  status: string;
  description?: string;
  created_at: string;
  updated_at: string;
  view_count: number;
  booking_count: number;
  favorite_count: number;
  remaining_weight?: number;
  is_featured: boolean;
  is_urgent: boolean;
}

export function useFavorites() {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const { token } = useAuth();

  const getUserFavorites = useCallback(async (): Promise<Trip[] | null> => {
    if (!token) {
      setError('Non authentifié');
      return null;
    }

    setLoading(true);
    setError(null);

    try {
      const response = await fetch(
        `${process.env.NEXT_PUBLIC_API_URL}/api/v1/trips/favorites`,
        {
          headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json',
          }
        }
      );

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || 'Erreur lors de la récupération des favoris');
      }

      return data.trips || [];

    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Erreur inconnue';
      setError(errorMessage);
      console.error('Erreur getUserFavorites:', err);
      return null;
    } finally {
      setLoading(false);
    }
  }, [token]);

  const addToFavorites = useCallback(async (tripId: number): Promise<boolean> => {
    if (!token) {
      setError('Non authentifié');
      return false;
    }

    setLoading(true);
    setError(null);

    try {
      const response = await fetch(
        `${process.env.NEXT_PUBLIC_API_URL}/api/v1/trips/${tripId}/favorite`,
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
        throw new Error(data.error || 'Erreur lors de l\'ajout aux favoris');
      }

      return true;

    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Erreur inconnue';
      setError(errorMessage);
      console.error('Erreur addToFavorites:', err);
      return false;
    } finally {
      setLoading(false);
    }
  }, [token]);

  const removeFromFavorites = useCallback(async (tripId: number): Promise<boolean> => {
    if (!token) {
      setError('Non authentifié');
      return false;
    }

    setLoading(true);
    setError(null);

    try {
      const response = await fetch(
        `${process.env.NEXT_PUBLIC_API_URL}/api/v1/trips/${tripId}/favorite`,
        {
          method: 'DELETE',
          headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json',
          }
        }
      );

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || 'Erreur lors de la suppression des favoris');
      }

      return true;

    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Erreur inconnue';
      setError(errorMessage);
      console.error('Erreur removeFromFavorites:', err);
      return false;
    } finally {
      setLoading(false);
    }
  }, [token]);

  const getFavoriteStatus = useCallback(async (tripId: number): Promise<boolean | null> => {
    if (!token) {
      setError('Non authentifié');
      return null;
    }

    try {
      const response = await fetch(
        `${process.env.NEXT_PUBLIC_API_URL}/api/v1/trips/${tripId}/favorite/status`,
        {
          headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json',
          }
        }
      );

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || 'Erreur lors de la vérification du statut favori');
      }

      return data.is_favorite || false;

    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Erreur inconnue';
      setError(errorMessage);
      console.error('Erreur getFavoriteStatus:', err);
      return null;
    }
  }, [token]);

  return {
    loading,
    error,
    getUserFavorites,
    addToFavorites,
    removeFromFavorites,
    getFavoriteStatus,
    clearError: () => setError(null)
  };
}