'use client';

import { useState, useCallback } from 'react';
import { useAuth } from './useAuth';

export interface WorkflowAction {
  action: string;
  label: string;
  target_status: string;
  icon: string;
  style: 'primary' | 'secondary' | 'success' | 'warning' | 'danger';
  admin_only?: boolean;
}

export interface TransitionHistory {
  id: number;
  from_status: string | null;
  to_status: string;
  reason: string;
  created_at: string;
  admin_first_name?: string;
  admin_last_name?: string;
  admin_email?: string;
  metadata?: any;
}

export interface WorkflowStats {
  by_status: Array<{
    status: string;
    count: number;
    avg_duration_hours: number;
  }>;
  total: number;
  conversion_rates: {
    draft_to_active: number;
    active_to_booked: number;
    booked_to_completed: number;
  };
}

export function useTripWorkflow() {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const { token } = useAuth();

  const getAvailableActions = useCallback(async (tripId: number): Promise<WorkflowAction[] | null> => {
    if (!token) {
      setError('Non authentifié');
      return null;
    }

    setLoading(true);
    setError(null);

    try {
      const response = await fetch(
        `${process.env.NEXT_PUBLIC_API_URL}/api/v1/trips/${tripId}/workflow/actions`,
        {
          headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json',
          }
        }
      );

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || 'Erreur lors de la récupération des actions');
      }

      return data.actions || [];

    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Erreur inconnue';
      setError(errorMessage);
      console.error('Erreur getAvailableActions:', err);
      return null;
    } finally {
      setLoading(false);
    }
  }, [token]);

  const executeTransition = useCallback(async (
    tripId: number,
    targetStatus: string,
    reason?: string,
    metadata?: any
  ): Promise<any | null> => {
    if (!token) {
      setError('Non authentifié');
      return null;
    }

    setLoading(true);
    setError(null);

    try {
      const response = await fetch(
        `${process.env.NEXT_PUBLIC_API_URL}/api/v1/trips/${tripId}/workflow/transition`,
        {
          method: 'PUT',
          headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            target_status: targetStatus,
            reason,
            metadata
          })
        }
      );

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || 'Erreur lors de la transition');
      }

      return data.trip;

    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Erreur inconnue';
      setError(errorMessage);
      console.error('Erreur executeTransition:', err);
      return null;
    } finally {
      setLoading(false);
    }
  }, [token]);

  const publishTrip = useCallback(async (tripId: number, metadata?: any): Promise<any | null> => {
    if (!token) {
      setError('Non authentifié');
      return null;
    }

    setLoading(true);
    setError(null);

    try {
      const response = await fetch(
        `${process.env.NEXT_PUBLIC_API_URL}/api/v1/trips/${tripId}/workflow/publish`,
        {
          method: 'PUT',
          headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ metadata })
        }
      );

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || 'Erreur lors de la publication');
      }

      return data.trip;

    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Erreur inconnue';
      setError(errorMessage);
      console.error('Erreur publishTrip:', err);
      return null;
    } finally {
      setLoading(false);
    }
  }, [token]);

  const pauseTrip = useCallback(async (tripId: number, reason?: string): Promise<any | null> => {
    if (!token) {
      setError('Non authentifié');
      return null;
    }

    setLoading(true);
    setError(null);

    try {
      const response = await fetch(
        `${process.env.NEXT_PUBLIC_API_URL}/api/v1/trips/${tripId}/workflow/pause`,
        {
          method: 'PUT',
          headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ reason })
        }
      );

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || 'Erreur lors de la mise en pause');
      }

      return data.trip;

    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Erreur inconnue';
      setError(errorMessage);
      console.error('Erreur pauseTrip:', err);
      return null;
    } finally {
      setLoading(false);
    }
  }, [token]);

  const resumeTrip = useCallback(async (tripId: number): Promise<any | null> => {
    if (!token) {
      setError('Non authentifié');
      return null;
    }

    setLoading(true);
    setError(null);

    try {
      const response = await fetch(
        `${process.env.NEXT_PUBLIC_API_URL}/api/v1/trips/${tripId}/workflow/resume`,
        {
          method: 'PUT',
          headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json',
          }
        }
      );

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || 'Erreur lors de la reprise');
      }

      return data.trip;

    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Erreur inconnue';
      setError(errorMessage);
      console.error('Erreur resumeTrip:', err);
      return null;
    } finally {
      setLoading(false);
    }
  }, [token]);

  const cancelTrip = useCallback(async (
    tripId: number, 
    reason?: string, 
    details?: string
  ): Promise<any | null> => {
    if (!token) {
      setError('Non authentifié');
      return null;
    }

    setLoading(true);
    setError(null);

    try {
      const response = await fetch(
        `${process.env.NEXT_PUBLIC_API_URL}/api/v1/trips/${tripId}/workflow/cancel`,
        {
          method: 'PUT',
          headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ reason, details })
        }
      );

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || 'Erreur lors de l\'annulation');
      }

      return data.trip;

    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Erreur inconnue';
      setError(errorMessage);
      console.error('Erreur cancelTrip:', err);
      return null;
    } finally {
      setLoading(false);
    }
  }, [token]);

  const completeTrip = useCallback(async (tripId: number, feedback?: string): Promise<any | null> => {
    if (!token) {
      setError('Non authentifié');
      return null;
    }

    setLoading(true);
    setError(null);

    try {
      const response = await fetch(
        `${process.env.NEXT_PUBLIC_API_URL}/api/v1/trips/${tripId}/workflow/complete`,
        {
          method: 'PUT',
          headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ feedback })
        }
      );

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || 'Erreur lors de la finalisation');
      }

      return data.trip;

    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Erreur inconnue';
      setError(errorMessage);
      console.error('Erreur completeTrip:', err);
      return null;
    } finally {
      setLoading(false);
    }
  }, [token]);

  const startProgress = useCallback(async (tripId: number): Promise<any | null> => {
    if (!token) {
      setError('Non authentifié');
      return null;
    }

    setLoading(true);
    setError(null);

    try {
      const response = await fetch(
        `${process.env.NEXT_PUBLIC_API_URL}/api/v1/trips/${tripId}/workflow/start-progress`,
        {
          method: 'PUT',
          headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json',
          }
        }
      );

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || 'Erreur lors du démarrage du voyage');
      }

      return data.trip;

    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Erreur inconnue';
      setError(errorMessage);
      console.error('Erreur startProgress:', err);
      return null;
    } finally {
      setLoading(false);
    }
  }, [token]);

  const getTransitionHistory = useCallback(async (tripId: number): Promise<TransitionHistory[] | null> => {
    if (!token) {
      setError('Non authentifié');
      return null;
    }

    setLoading(true);
    setError(null);

    try {
      const response = await fetch(
        `${process.env.NEXT_PUBLIC_API_URL}/api/v1/trips/${tripId}/workflow/history`,
        {
          headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json',
          }
        }
      );

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || 'Erreur lors de la récupération de l\'historique');
      }

      return data.history || [];

    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Erreur inconnue';
      setError(errorMessage);
      console.error('Erreur getTransitionHistory:', err);
      return null;
    } finally {
      setLoading(false);
    }
  }, [token]);

  const getWorkflowStats = useCallback(async (): Promise<WorkflowStats | null> => {
    if (!token) {
      setError('Non authentifié');
      return null;
    }

    setLoading(true);
    setError(null);

    try {
      const response = await fetch(
        `${process.env.NEXT_PUBLIC_API_URL}/api/v1/trips/workflow/stats`,
        {
          headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json',
          }
        }
      );

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || 'Erreur lors de la récupération des statistiques');
      }

      return data.stats;

    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Erreur inconnue';
      setError(errorMessage);
      console.error('Erreur getWorkflowStats:', err);
      return null;
    } finally {
      setLoading(false);
    }
  }, [token]);

  // Utilitaires pour les statuts
  const getStatusLabel = useCallback((status: string): string => {
    const labels: { [key: string]: string } = {
      'draft': 'Brouillon',
      'pending_review': 'En attente de révision',
      'active': 'Actif',
      'rejected': 'Rejeté',
      'paused': 'En pause',
      'booked': 'Réservé',
      'in_progress': 'En cours',
      'completed': 'Terminé',
      'cancelled': 'Annulé',
      'expired': 'Expiré'
    };
    return labels[status] || status;
  }, []);

  const getStatusColor = useCallback((status: string): string => {
    const colors: { [key: string]: string } = {
      'draft': 'gray',
      'pending_review': 'yellow',
      'active': 'green',
      'rejected': 'red',
      'paused': 'orange',
      'booked': 'blue',
      'in_progress': 'purple',
      'completed': 'emerald',
      'cancelled': 'red',
      'expired': 'gray'
    };
    return colors[status] || 'gray';
  }, []);

  const getStatusIcon = useCallback((status: string): string => {
    const icons: { [key: string]: string } = {
      'draft': 'edit',
      'pending_review': 'clock',
      'active': 'check-circle',
      'rejected': 'x-circle',
      'paused': 'pause-circle',
      'booked': 'calendar-check',
      'in_progress': 'truck',
      'completed': 'check-circle-2',
      'cancelled': 'x-circle',
      'expired': 'clock-x'
    };
    return icons[status] || 'circle';
  }, []);

  const canUserEdit = useCallback((status: string): boolean => {
    const editableStatuses = ['draft', 'pending_review', 'active', 'paused', 'rejected'];
    return editableStatuses.includes(status);
  }, []);

  const isVisibleToPublic = useCallback((status: string): boolean => {
    return status === 'active';
  }, []);

  return {
    loading,
    error,
    getAvailableActions,
    executeTransition,
    publishTrip,
    pauseTrip,
    resumeTrip,
    cancelTrip,
    completeTrip,
    startProgress,
    getTransitionHistory,
    getWorkflowStats,
    getStatusLabel,
    getStatusColor,
    getStatusIcon,
    canUserEdit,
    isVisibleToPublic,
    clearError: () => setError(null)
  };
}