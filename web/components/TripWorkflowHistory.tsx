'use client';

import React, { useState, useEffect } from 'react';
import { History, User, Clock, ArrowRight, AlertCircle, CheckCircle, XCircle, Pause, Play } from 'lucide-react';
import { useTripWorkflow, TransitionHistory } from '../hooks/useTripWorkflow';

interface TripWorkflowHistoryProps {
  tripId: number;
  className?: string;
}

export default function TripWorkflowHistory({ tripId, className = '' }: TripWorkflowHistoryProps) {
  const [history, setHistory] = useState<TransitionHistory[]>([]);
  const [isOpen, setIsOpen] = useState(false);

  const {
    loading,
    error,
    getTransitionHistory,
    getStatusLabel,
    getStatusColor,
    clearError
  } = useTripWorkflow();

  useEffect(() => {
    if (isOpen && history.length === 0) {
      loadHistory();
    }
  }, [isOpen]);

  const loadHistory = async () => {
    const historyData = await getTransitionHistory(tripId);
    if (historyData) {
      setHistory(historyData);
    }
  };

  const getStatusIcon = (status: string) => {
    const icons: { [key: string]: React.ComponentType<any> } = {
      'draft': AlertCircle,
      'pending_review': Clock,
      'active': CheckCircle,
      'rejected': XCircle,
      'paused': Pause,
      'booked': CheckCircle,
      'in_progress': Play,
      'completed': CheckCircle,
      'cancelled': XCircle,
      'expired': Clock
    };
    const IconComponent = icons[status] || AlertCircle;
    return <IconComponent className="h-4 w-4" />;
  };

  const getStatusBadgeClass = (status: string) => {
    const color = getStatusColor(status);
    const classes: { [key: string]: string } = {
      'gray': 'bg-gray-100 text-gray-800 border-gray-200',
      'yellow': 'bg-yellow-100 text-yellow-800 border-yellow-200',
      'green': 'bg-green-100 text-green-800 border-green-200',
      'red': 'bg-red-100 text-red-800 border-red-200',
      'orange': 'bg-orange-100 text-orange-800 border-orange-200',
      'blue': 'bg-blue-100 text-blue-800 border-blue-200',
      'purple': 'bg-purple-100 text-purple-800 border-purple-200',
      'emerald': 'bg-emerald-100 text-emerald-800 border-emerald-200'
    };
    return classes[color] || classes['gray'];
  };

  const formatDate = (dateString: string) => {
    const date = new Date(dateString);
    return new Intl.DateTimeFormat('fr-FR', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    }).format(date);
  };

  const formatRelativeTime = (dateString: string) => {
    const date = new Date(dateString);
    const now = new Date();
    const diffInSeconds = Math.floor((now.getTime() - date.getTime()) / 1000);

    if (diffInSeconds < 60) return 'Il y a quelques instants';
    if (diffInSeconds < 3600) return `Il y a ${Math.floor(diffInSeconds / 60)} min`;
    if (diffInSeconds < 86400) return `Il y a ${Math.floor(diffInSeconds / 3600)} h`;
    if (diffInSeconds < 2592000) return `Il y a ${Math.floor(diffInSeconds / 86400)} j`;
    
    return formatDate(dateString);
  };

  if (error) {
    return (
      <div className={`p-4 bg-red-50 border border-red-200 rounded-lg ${className}`}>
        <div className="flex items-center space-x-2 text-red-700">
          <AlertCircle className="h-4 w-4" />
          <span className="text-sm">Erreur lors du chargement de l'historique</span>
        </div>
      </div>
    );
  }

  return (
    <div className={className}>
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="flex items-center space-x-2 text-gray-600 hover:text-gray-900 transition-colors"
      >
        <History className="h-4 w-4" />
        <span className="text-sm font-medium">
          Historique des changements
          {history.length > 0 && (
            <span className="ml-2 px-2 py-1 bg-gray-100 text-gray-600 text-xs rounded-full">
              {history.length}
            </span>
          )}
        </span>
      </button>

      {isOpen && (
        <div className="mt-4 space-y-4">
          {loading ? (
            <div className="flex items-center justify-center p-4">
              <div className="animate-spin rounded-full h-6 w-6 border-2 border-blue-600 border-t-transparent"></div>
            </div>
          ) : history.length === 0 ? (
            <div className="text-center p-4 text-gray-500">
              <History className="h-8 w-8 mx-auto mb-2 text-gray-300" />
              <p className="text-sm">Aucun historique disponible</p>
            </div>
          ) : (
            <div className="space-y-3">
              {history.map((entry, index) => (
                <div
                  key={entry.id}
                  className="flex items-start space-x-3 p-3 bg-gray-50 rounded-lg border border-gray-200"
                >
                  {/* Timeline indicator */}
                  <div className="flex flex-col items-center">
                    <div className={`
                      w-8 h-8 rounded-full border-2 flex items-center justify-center
                      ${getStatusBadgeClass(entry.to_status)}
                    `}>
                      {getStatusIcon(entry.to_status)}
                    </div>
                    {index < history.length - 1 && (
                      <div className="w-0.5 h-6 bg-gray-300 mt-2"></div>
                    )}
                  </div>

                  {/* Content */}
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center space-x-2 mb-1">
                      {entry.from_status && (
                        <>
                          <span className={`
                            inline-flex items-center px-2 py-1 text-xs font-medium rounded-full border
                            ${getStatusBadgeClass(entry.from_status)}
                          `}>
                            {getStatusLabel(entry.from_status)}
                          </span>
                          <ArrowRight className="h-3 w-3 text-gray-400" />
                        </>
                      )}
                      <span className={`
                        inline-flex items-center px-2 py-1 text-xs font-medium rounded-full border
                        ${getStatusBadgeClass(entry.to_status)}
                      `}>
                        {getStatusLabel(entry.to_status)}
                      </span>
                    </div>

                    {/* Reason */}
                    {entry.reason && (
                      <p className="text-sm text-gray-600 mb-2">
                        {entry.reason}
                      </p>
                    )}

                    {/* Metadata */}
                    {entry.metadata && (
                      <div className="text-xs text-gray-500 mb-2">
                        {typeof entry.metadata === 'string' 
                          ? entry.metadata 
                          : JSON.stringify(entry.metadata)
                        }
                      </div>
                    )}

                    {/* Footer */}
                    <div className="flex items-center justify-between text-xs text-gray-500">
                      <div className="flex items-center space-x-2">
                        {(entry.admin_first_name || entry.admin_last_name) ? (
                          <div className="flex items-center space-x-1">
                            <User className="h-3 w-3" />
                            <span>
                              {entry.admin_first_name} {entry.admin_last_name}
                            </span>
                            <span className="text-blue-600">(Admin)</span>
                          </div>
                        ) : (
                          <div className="flex items-center space-x-1">
                            <User className="h-3 w-3" />
                            <span>Utilisateur</span>
                          </div>
                        )}
                      </div>
                      
                      <div className="flex items-center space-x-1" title={formatDate(entry.created_at)}>
                        <Clock className="h-3 w-3" />
                        <span>{formatRelativeTime(entry.created_at)}</span>
                      </div>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}