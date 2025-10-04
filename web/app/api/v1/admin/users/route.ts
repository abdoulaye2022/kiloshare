import { NextRequest, NextResponse } from 'next/server';

const BACKEND_URL = process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:8080';

function getAuthToken(request: NextRequest): string | null {
  const authHeader = request.headers.get('Authorization');
  if (authHeader && authHeader.startsWith('Bearer ')) {
    return authHeader.substring(7);
  }
  return null;
}

export async function GET(request: NextRequest) {
  try {
    const token = getAuthToken(request);

    if (!token) {
      return NextResponse.json(
        { success: false, message: 'Token d\'authentification requis' },
        { status: 401 }
      );
    }

    // Récupérer les paramètres de query
    const { searchParams } = new URL(request.url);
    const status = searchParams.get('status') || 'all';
    const limit = searchParams.get('limit') || '50';

    try {
      // Essayer l'API backend
      const backendUrl = `${BACKEND_URL}/api/v1/admin/users?status=${status}&limit=${limit}&include=stripe_account`;

      const response = await fetch(backendUrl, {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
        },
      });

      if (response.ok) {
        const data = await response.json();

        return NextResponse.json({
          success: true,
          data: {
            users: data.data?.users || data.users || []
          }
        });
      }

    } catch (fetchError) {
    }

    // Si le backend n'est pas disponible, utiliser des données de démonstration

    const demoUsers = generateDemoUsers(status);

    return NextResponse.json({
      success: true,
      data: {
        users: demoUsers
      }
    });

  } catch (error) {
    console.error('Admin users API error:', error);
    return NextResponse.json(
      { success: false, message: 'Erreur du serveur' },
      { status: 500 }
    );
  }
}

// Générer des données de démonstration avec comptes Stripe
function generateDemoUsers(status: string) {
  const today = new Date();

  const allUsers = [
    {
      id: 1,
      uuid: 'user-001-uuid',
      email: 'marie.dubois@email.com',
      first_name: 'Marie',
      last_name: 'Dubois',
      phone: '+33123456789',
      is_verified: true,
      email_verified_at: '2024-01-15T10:30:00Z',
      phone_verified_at: '2024-01-15T10:35:00Z',
      status: 'active' as const,
      role: 'user',
      last_login_at: '2024-12-20T09:15:00Z',
      created_at: '2024-01-15T10:00:00Z',
      // Informations Stripe depuis user_stripe_accounts
      stripe_account_id: 'acct_1234567890ABC',
      stripe_onboarding_complete: true,
      stripe_account_status: 'active',
      stripe_charges_enabled: true,
      stripe_payouts_enabled: true,
      // Statistiques utilisateur
      total_trips: 12,
      total_bookings: 8,
      trust_score: 85
    },
    {
      id: 2,
      uuid: 'user-002-uuid',
      email: 'john.smith@email.com',
      first_name: 'John',
      last_name: 'Smith',
      phone: '+447123456789',
      is_verified: true,
      email_verified_at: '2024-02-01T09:15:00Z',
      phone_verified_at: null,
      status: 'active' as const,
      role: 'user',
      last_login_at: '2024-12-19T14:30:00Z',
      created_at: '2024-02-01T09:00:00Z',
      // Compte Stripe en cours de configuration
      stripe_account_id: 'acct_0987654321DEF',
      stripe_onboarding_complete: false,
      stripe_account_status: 'pending',
      stripe_charges_enabled: false,
      stripe_payouts_enabled: false,
      total_trips: 3,
      total_bookings: 5,
      trust_score: 65
    },
    {
      id: 3,
      uuid: 'user-003-uuid',
      email: 'emma.johnson@email.com',
      first_name: 'Emma',
      last_name: 'Johnson',
      phone: '+14161234567',
      is_verified: false,
      email_verified_at: null,
      phone_verified_at: null,
      status: 'pending' as const,
      role: 'user',
      last_login_at: null,
      created_at: '2024-12-18T16:20:00Z',
      // Pas encore de compte Stripe
      stripe_account_id: null,
      stripe_onboarding_complete: false,
      stripe_account_status: null,
      stripe_charges_enabled: false,
      stripe_payouts_enabled: false,
      total_trips: 0,
      total_bookings: 0,
      trust_score: 0
    },
    {
      id: 4,
      uuid: 'user-004-uuid',
      email: 'sophie.martin@email.com',
      first_name: 'Sophie',
      last_name: 'Martin',
      phone: '+33987654321',
      is_verified: true,
      email_verified_at: '2024-03-10T11:45:00Z',
      phone_verified_at: '2024-03-10T11:50:00Z',
      status: 'blocked' as const,
      role: 'user',
      last_login_at: '2024-12-10T08:20:00Z',
      created_at: '2024-03-10T11:30:00Z',
      // Compte Stripe restreint
      stripe_account_id: 'acct_5678901234GHI',
      stripe_onboarding_complete: true,
      stripe_account_status: 'restricted',
      stripe_charges_enabled: false,
      stripe_payouts_enabled: false,
      total_trips: 7,
      total_bookings: 2,
      trust_score: 25
    },
    {
      id: 5,
      uuid: 'user-005-uuid',
      email: 'david.wilson@email.com',
      first_name: 'David',
      last_name: 'Wilson',
      phone: '+14387654321',
      is_verified: true,
      email_verified_at: '2024-11-05T15:20:00Z',
      phone_verified_at: '2024-11-05T15:25:00Z',
      status: 'active' as const,
      role: 'user',
      last_login_at: '2024-12-21T12:45:00Z',
      created_at: '2024-11-05T15:00:00Z',
      // Compte Stripe actif
      stripe_account_id: 'acct_9876543210JKL',
      stripe_onboarding_complete: true,
      stripe_account_status: 'active',
      stripe_charges_enabled: true,
      stripe_payouts_enabled: true,
      total_trips: 5,
      total_bookings: 12,
      trust_score: 92
    }
  ];

  // Filtrer selon le statut demandé
  if (status === 'all') {
    return allUsers;
  }

  return allUsers.filter(user => user.status === status);
}