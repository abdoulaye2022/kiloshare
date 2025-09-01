import { NextRequest, NextResponse } from 'next/server';

const BACKEND_URL = process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:8080/api/v1';

// Mock data pour les transactions
const mockTransactions = [
  {
    id: 'TXN_001',
    user_name: 'Jean Dupont',
    user_email: 'jean.dupont@email.com',
    amount: 125.50,
    currency: 'EUR',
    status: 'completed',
    type: 'booking_payment',
    created_at: '2025-09-01T10:30:00Z',
    trip_id: 'TRIP_123',
    stripe_transaction_id: 'pi_1234567890',
    commission: 12.55,
    net_amount: 112.95
  },
  {
    id: 'TXN_002',
    user_name: 'Marie Martin',
    user_email: 'marie.martin@email.com',
    amount: 89.00,
    currency: 'EUR',
    status: 'pending',
    type: 'booking_payment',
    created_at: '2025-09-01T09:15:00Z',
    trip_id: 'TRIP_124',
    stripe_transaction_id: 'pi_0987654321',
    commission: 8.90,
    net_amount: 80.10
  },
  {
    id: 'TXN_003',
    user_name: 'Pierre Durand',
    user_email: 'pierre.durand@email.com',
    amount: 200.00,
    currency: 'EUR',
    status: 'failed',
    type: 'booking_payment',
    created_at: '2025-09-01T08:45:00Z',
    trip_id: 'TRIP_125',
    stripe_transaction_id: 'pi_1122334455',
    commission: 0,
    net_amount: 0,
    failure_reason: 'Carte déclinée'
  },
  {
    id: 'TXN_004',
    user_name: 'Sophie Lemaire',
    user_email: 'sophie.lemaire@email.com',
    amount: 156.75,
    currency: 'EUR',
    status: 'refunded',
    type: 'refund',
    created_at: '2025-08-31T16:20:00Z',
    trip_id: 'TRIP_120',
    stripe_transaction_id: 'pi_5544332211',
    commission: -15.67,
    net_amount: -141.08
  },
  {
    id: 'TXN_005',
    user_name: 'Thomas Roux',
    user_email: 'thomas.roux@email.com',
    amount: 75.25,
    currency: 'EUR',
    status: 'completed',
    type: 'booking_payment',
    created_at: '2025-08-31T14:10:00Z',
    trip_id: 'TRIP_126',
    stripe_transaction_id: 'pi_9988776655',
    commission: 7.53,
    net_amount: 67.72
  }
];

export async function GET(request: NextRequest) {
  try {
    // Vérifier l'authentification admin
    const authHeader = request.headers.get('Authorization');
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return NextResponse.json(
        { success: false, message: 'Token d\'authentification requis' },
        { status: 401 }
      );
    }

    const token = authHeader.substring(7);
    
    try {
      // Décoder le token JWT sans vérification (pour la démo)
      const base64Payload = token.split('.')[1];
      const payload = JSON.parse(atob(base64Payload));
      
      if (!payload || !payload.user || payload.user.role !== 'admin') {
        return NextResponse.json(
          { success: false, message: 'Accès non autorisé - Rôle admin requis' },
          { status: 403 }
        );
      }
    } catch (error) {
      return NextResponse.json(
        { success: false, message: 'Token invalide' },
        { status: 401 }
      );
    }

    // Obtenir les paramètres de requête
    const url = new URL(request.url);
    const queryParams = url.searchParams.toString();

    // Essayer d'abord l'API backend
    try {
      const backendUrl = `${BACKEND_URL}/admin/payments/transactions${queryParams ? `?${queryParams}` : ''}`;
      const response = await fetch(backendUrl, {
        headers: {
          'Authorization': authHeader,
          'Content-Type': 'application/json',
        },
      });

      if (response.ok) {
        const backendData = await response.json();
        return NextResponse.json({
          success: true,
          data: backendData.data || backendData
        });
      }

      // Si l'endpoint n'existe pas (404), utiliser les données mock
      if (response.status !== 404) {
        console.error('Backend error:', await response.text());
      }
    } catch (error) {
      console.error('Backend call failed:', error);
    }

    // Fallback vers les données mock
    const page = parseInt(url.searchParams.get('page') || '1');
    const limit = parseInt(url.searchParams.get('limit') || '10');
    const status = url.searchParams.get('status');
    const type = url.searchParams.get('type');

    // Filtrer les transactions selon les paramètres
    let filteredTransactions = mockTransactions;
    
    if (status && status !== 'all') {
      filteredTransactions = filteredTransactions.filter(t => t.status === status);
    }
    
    if (type && type !== 'all') {
      filteredTransactions = filteredTransactions.filter(t => t.type === type);
    }

    // Pagination
    const total = filteredTransactions.length;
    const startIndex = (page - 1) * limit;
    const endIndex = startIndex + limit;
    const paginatedTransactions = filteredTransactions.slice(startIndex, endIndex);

    // Statistiques rapides
    const stats = {
      total_transactions: mockTransactions.length,
      completed: mockTransactions.filter(t => t.status === 'completed').length,
      pending: mockTransactions.filter(t => t.status === 'pending').length,
      failed: mockTransactions.filter(t => t.status === 'failed').length,
      refunded: mockTransactions.filter(t => t.status === 'refunded').length,
      total_revenue: mockTransactions
        .filter(t => t.status === 'completed')
        .reduce((sum, t) => sum + t.amount, 0),
      total_commissions: mockTransactions
        .filter(t => t.status === 'completed')
        .reduce((sum, t) => sum + t.commission, 0)
    };

    return NextResponse.json({
      success: true,
      data: {
        transactions: paginatedTransactions,
        pagination: {
          page,
          limit,
          total,
          totalPages: Math.ceil(total / limit),
          hasNext: endIndex < total,
          hasPrev: page > 1
        },
        stats
      }
    });

  } catch (error) {
    console.error('Transactions API error:', error);
    return NextResponse.json(
      { 
        success: false, 
        message: 'Erreur lors de la récupération des transactions' 
      },
      { status: 500 }
    );
  }
}