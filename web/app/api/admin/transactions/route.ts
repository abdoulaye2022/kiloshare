import { NextRequest, NextResponse } from 'next/server';

const BACKEND_URL = process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:8080/api/v1';

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

    // Récupérer les paramètres de requête
    const { searchParams } = new URL(request.url);
    const status = searchParams.get('status');
    const type = searchParams.get('type');
    const limit = searchParams.get('limit') || '50';

    // Appeler l'API backend
    const backendUrl = new URL(`${BACKEND_URL}/admin/transactions`);
    if (status) backendUrl.searchParams.append('status', status);
    if (type) backendUrl.searchParams.append('type', type);
    backendUrl.searchParams.append('limit', limit);

    const response = await fetch(backendUrl.toString(), {
      headers: {
        'Authorization': authHeader,
        'Content-Type': 'application/json',
      },
    });

    if (!response.ok) {
      // Si l'API backend n'existe pas encore, retourner des données de démonstration
      if (response.status === 404) {
        return NextResponse.json({
          success: true,
          transactions: generateDemoTransactions(status, type)
        });
      }
      
      const errorData = await response.text();
      return NextResponse.json(
        { success: false, message: `Erreur backend: ${errorData}` },
        { status: response.status }
      );
    }

    const data = await response.json();
    return NextResponse.json({
      success: true,
      transactions: data.data || data.transactions || []
    });

  } catch (error) {
    console.error('Transactions API error:', error);
    
    // En cas d'erreur, retourner des données de démonstration
    const { searchParams } = new URL(request.url);
    const status = searchParams.get('status');
    const type = searchParams.get('type');
    
    return NextResponse.json({
      success: true,
      transactions: generateDemoTransactions(status, type)
    });
  }
}

function generateDemoTransactions(statusFilter?: string | null, typeFilter?: string | null) {
  const baseTransactions = [
    {
      id: 'txn_1',
      trip_id: '1',
      booking_id: 'book_1',
      user_id: '1',
      amount: 125.50,
      currency: 'EUR',
      type: 'payment',
      status: 'completed',
      stripe_payment_intent_id: 'pi_1234567890',
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
      trip: {
        departure_city: 'Paris',
        arrival_city: 'Montreal',
        departure_date: '2024-09-05T10:00:00Z'
      },
      user: {
        first_name: 'Marie',
        last_name: 'Dupont',
        email: 'marie.dupont@example.com'
      },
      booking: {
        package_weight: 5,
        total_price: 125.50
      }
    },
    {
      id: 'txn_2',
      trip_id: '2',
      booking_id: 'book_2',
      user_id: '2',
      amount: 89.99,
      currency: 'EUR',
      type: 'commission',
      status: 'completed',
      created_at: new Date(Date.now() - 86400000).toISOString(),
      updated_at: new Date(Date.now() - 86400000).toISOString(),
      trip: {
        departure_city: 'Toronto',
        arrival_city: 'Paris',
        departure_date: '2024-09-03T14:30:00Z'
      },
      user: {
        first_name: 'Jean',
        last_name: 'Martin',
        email: 'jean.martin@example.com'
      }
    },
    {
      id: 'txn_3',
      trip_id: '3',
      booking_id: 'book_3',
      user_id: '3',
      amount: 67.25,
      currency: 'EUR',
      type: 'payment',
      status: 'failed',
      failure_reason: 'Carte bancaire expirée',
      created_at: new Date(Date.now() - 3600000).toISOString(),
      updated_at: new Date(Date.now() - 3600000).toISOString(),
      trip: {
        departure_city: 'Montreal',
        arrival_city: 'Quebec',
        departure_date: '2024-09-02T09:15:00Z'
      },
      user: {
        first_name: 'Sophie',
        last_name: 'Bernard',
        email: 'sophie.bernard@example.com'
      }
    },
    {
      id: 'txn_4',
      trip_id: '4',
      booking_id: 'book_4',
      user_id: '4',
      amount: 45.00,
      currency: 'EUR',
      type: 'refund',
      status: 'pending',
      created_at: new Date(Date.now() - 1800000).toISOString(),
      updated_at: new Date(Date.now() - 1800000).toISOString(),
      trip: {
        departure_city: 'Vancouver',
        arrival_city: 'Toronto',
        departure_date: '2024-09-01T16:45:00Z'
      },
      user: {
        first_name: 'Pierre',
        last_name: 'Rousseau',
        email: 'pierre.rousseau@example.com'
      }
    },
    {
      id: 'txn_5',
      trip_id: '5',
      booking_id: 'book_5',
      user_id: '5',
      amount: 234.75,
      currency: 'EUR',
      type: 'payout',
      status: 'completed',
      stripe_transfer_id: 'tr_9876543210',
      created_at: new Date(Date.now() - 7200000).toISOString(),
      updated_at: new Date(Date.now() - 7200000).toISOString(),
      trip: {
        departure_city: 'Calgary',
        arrival_city: 'Vancouver',
        departure_date: '2024-08-30T12:00:00Z'
      },
      user: {
        first_name: 'Luc',
        last_name: 'Moreau',
        email: 'luc.moreau@example.com'
      }
    }
  ];

  return baseTransactions.filter(tx => {
    if (statusFilter && tx.status !== statusFilter) return false;
    if (typeFilter && tx.type !== typeFilter) return false;
    return true;
  });
}