'use client';

import React, { useState, useEffect } from 'react';
import { 
  Play, 
  Pause, 
  Square, 
  CheckCircle, 
  Send, 
  Eye, 
  Edit, 
  X, 
  Clock, 
  AlertCircle,
  CheckCircle2,
  TruckIcon as Truck
} from 'lucide-react';
import { useTripWorkflow, WorkflowAction } from '../hooks/useTripWorkflow';

interface TripWorkflowActionsProps {
  tripId: number;
  currentStatus: string;
  onStatusChange?: (newTrip: any) => void;
  onError?: (error: string) => void;
  className?: string;
}

const iconMap: { [key: string]: React.ComponentType<any> } = {
  play: Play,
  pause: Pause,
  send: Send,
  eye: Eye,
  edit: Edit,
  check: CheckCircle,
  'check-circle-2': CheckCircle2,
  x: X,
  clock: Clock,
  truck: Truck,
  'alert-circle': AlertCircle,
  square: Square
};

const styleClasses = {
  primary: 'bg-blue-600 hover:bg-blue-700 text-white border-blue-600 hover:border-blue-700',
  secondary: 'bg-gray-100 hover:bg-gray-200 text-gray-900 border-gray-300 hover:border-gray-400',
  success: 'bg-green-600 hover:bg-green-700 text-white border-green-600 hover:border-green-700',
  warning: 'bg-orange-500 hover:bg-orange-600 text-white border-orange-500 hover:border-orange-600',
  danger: 'bg-red-600 hover:bg-red-700 text-white border-red-600 hover:border-red-700'
};

export default function TripWorkflowActions({
  tripId,
  currentStatus,
  onStatusChange,
  onError,
  className = ''
}: TripWorkflowActionsProps) {
  const [actions, setActions] = useState<WorkflowAction[]>([]);
  const [showReasonModal, setShowReasonModal] = useState<string | null>(null);
  const [reason, setReason] = useState('');
  const [details, setDetails] = useState('');

  const {
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
    getStatusLabel,
    clearError
  } = useTripWorkflow();

  // Charger les actions disponibles
  useEffect(() => {
    const loadActions = async () => {
      const availableActions = await getAvailableActions(tripId);
      if (availableActions) {
        setActions(availableActions);
      }
    };

    loadActions();
  }, [tripId, currentStatus, getAvailableActions]);

  // Gérer les erreurs
  useEffect(() => {
    if (error) {
      onError?.(error);
      clearError();
    }
  }, [error, onError, clearError]);

  const handleAction = async (action: WorkflowAction) => {
    // Actions nécessitant une confirmation/raison
    const actionsRequiringReason = ['pause', 'cancel', 'reject'];
    const actionsRequiringConfirmation = ['complete', 'start_progress'];

    if (actionsRequiringReason.includes(action.action) || 
        actionsRequiringConfirmation.includes(action.action)) {
      setShowReasonModal(action.action);
      return;
    }

    // Actions directes
    await executeActionDirect(action);
  };

  const executeActionDirect = async (action: WorkflowAction) => {
    let updatedTrip = null;

    try {
      switch (action.action) {
        case 'publish':
          updatedTrip = await publishTrip(tripId);
          break;

        case 'resume':
          updatedTrip = await resumeTrip(tripId);
          break;

        default:
          updatedTrip = await executeTransition(tripId, action.target_status);
          break;
      }

      if (updatedTrip) {
        onStatusChange?.(updatedTrip);
        // Recharger les actions après le changement de statut
        const newActions = await getAvailableActions(tripId);
        if (newActions) {
          setActions(newActions);
        }
      }
    } catch (err) {
      console.error('Action execution failed:', err);
    }
  };

  const executeActionWithReason = async () => {
    if (!showReasonModal) return;

    let updatedTrip = null;

    try {
      switch (showReasonModal) {
        case 'pause':
          updatedTrip = await pauseTrip(tripId, reason || 'En pause temporaire');
          break;

        case 'cancel':
          updatedTrip = await cancelTrip(tripId, reason || 'Annulé par l\'utilisateur', details);
          break;

        case 'complete':
          updatedTrip = await completeTrip(tripId, reason);
          break;

        case 'start_progress':
          updatedTrip = await startProgress(tripId);
          break;

        default:
          // Action générique avec raison
          const action = actions.find(a => a.action === showReasonModal);
          if (action) {
            updatedTrip = await executeTransition(tripId, action.target_status, reason);
          }
          break;
      }

      if (updatedTrip) {
        onStatusChange?.(updatedTrip);
        // Recharger les actions après le changement de statut
        const newActions = await getAvailableActions(tripId);
        if (newActions) {
          setActions(newActions);
        }
      }

      setShowReasonModal(null);
      setReason('');
      setDetails('');
    } catch (err) {
      console.error('Action with reason execution failed:', err);
    }
  };

  const getActionIcon = (iconName: string) => {
    const IconComponent = iconMap[iconName] || AlertCircle;
    return <IconComponent className="h-4 w-4" />;
  };

  const getModalConfig = (actionType: string) => {
    const configs = {
      pause: {
        title: 'Mettre en pause',
        message: 'Pourquoi voulez-vous mettre cette annonce en pause ?',
        placeholder: 'Raison de la mise en pause (optionnel)',
        confirmText: 'Mettre en pause',
        requiresReason: false,
        hasDetails: false
      },
      cancel: {
        title: 'Annuler l\'annonce',
        message: 'Êtes-vous sûr de vouloir annuler cette annonce ?',
        placeholder: 'Raison de l\'annulation (optionnel)',
        confirmText: 'Annuler l\'annonce',
        requiresReason: false,
        hasDetails: true
      },
      complete: {
        title: 'Marquer comme terminé',
        message: 'Comment s\'est déroulé le voyage ?',
        placeholder: 'Commentaires sur le voyage (optionnel)',
        confirmText: 'Marquer comme terminé',
        requiresReason: false,
        hasDetails: false
      },
      start_progress: {
        title: 'Commencer le voyage',
        message: 'Êtes-vous prêt à commencer le voyage ?',
        confirmText: 'Commencer le voyage',
        requiresReason: false,
        placeholder: undefined,
        hasDetails: false
      }
    };

    return configs[actionType as keyof typeof configs] || {
      title: 'Confirmer l\'action',
      message: 'Êtes-vous sûr de vouloir effectuer cette action ?',
      confirmText: 'Confirmer',
      requiresReason: false,
      placeholder: undefined,
      hasDetails: false
    };
  };

  if (actions.length === 0) {
    return null;
  }

  return (
    <>
      <div className={`flex flex-wrap gap-2 ${className}`}>
        {/* Statut actuel */}
        <div className="flex items-center space-x-2 px-3 py-2 bg-gray-50 rounded-lg border">
          <div className="text-sm font-medium text-gray-600">
            Statut: <span className="text-gray-900">{getStatusLabel(currentStatus)}</span>
          </div>
        </div>

        {/* Actions disponibles */}
        {actions.map((action, index) => (
          <button
            key={index}
            onClick={() => handleAction(action)}
            disabled={loading}
            className={`
              inline-flex items-center space-x-2 px-4 py-2 text-sm font-medium 
              border rounded-lg transition-colors duration-200
              focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500
              disabled:opacity-50 disabled:cursor-not-allowed
              ${styleClasses[action.style]}
            `}
          >
            {loading ? (
              <div className="animate-spin rounded-full h-4 w-4 border-2 border-current border-t-transparent" />
            ) : (
              getActionIcon(action.icon)
            )}
            <span>{action.label}</span>
          </button>
        ))}
      </div>

      {/* Modal de confirmation/raison */}
      {showReasonModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-xl max-w-md w-full p-6">
            <h3 className="text-lg font-semibold text-gray-900 mb-4">
              {getModalConfig(showReasonModal).title}
            </h3>
            
            <p className="text-gray-600 mb-4">
              {getModalConfig(showReasonModal).message}
            </p>

            {getModalConfig(showReasonModal).placeholder && (
              <div className="mb-4">
                <textarea
                  value={reason}
                  onChange={(e) => setReason(e.target.value)}
                  placeholder={getModalConfig(showReasonModal).placeholder}
                  rows={3}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent resize-none"
                />
              </div>
            )}

            {getModalConfig(showReasonModal).hasDetails && (
              <div className="mb-4">
                <textarea
                  value={details}
                  onChange={(e) => setDetails(e.target.value)}
                  placeholder="Détails supplémentaires (optionnel)"
                  rows={2}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent resize-none"
                />
              </div>
            )}

            <div className="flex space-x-3">
              <button
                onClick={() => {
                  setShowReasonModal(null);
                  setReason('');
                  setDetails('');
                }}
                className="flex-1 px-4 py-2 text-sm font-medium text-gray-700 bg-gray-100 hover:bg-gray-200 border border-gray-300 rounded-lg transition-colors"
              >
                Annuler
              </button>
              
              <button
                onClick={executeActionWithReason}
                disabled={loading || (getModalConfig(showReasonModal).requiresReason && !reason.trim())}
                className="flex-1 px-4 py-2 text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 border border-blue-600 rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {loading ? (
                  <div className="flex items-center justify-center space-x-2">
                    <div className="animate-spin rounded-full h-4 w-4 border-2 border-white border-t-transparent" />
                    <span>En cours...</span>
                  </div>
                ) : (
                  getModalConfig(showReasonModal).confirmText
                )}
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}