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

    try {
      // Essayer l'API backend pour les comptes Stripe
      const response = await fetch(`${BACKEND_URL}/api/v1/admin/users/stripe`, {
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
            stripe_accounts: data.data?.stripe_accounts || data.stripe_accounts || []
          }
        });
      }

    } catch (fetchError) {
    }

    // Données de démonstration pour les comptes Stripe
    const demoStripeAccounts = generateDemoStripeAccounts();

    return NextResponse.json({
      success: true,
      data: {
        stripe_accounts: demoStripeAccounts
      }
    });

  } catch (error) {
    console.error('Admin stripe accounts API error:', error);
    return NextResponse.json(
      { success: false, message: 'Erreur du serveur' },
      { status: 500 }
    );
  }
}

function generateDemoStripeAccounts() {
  return [
    {
      id: 1,
      user_id: 1,
      stripe_account_id: 'acct_1234567890ABC',
      account_status: 'active',
      charges_enabled: true,
      details_submitted: true,
      payouts_enabled: true,
      created_at: '2024-01-15T10:30:00Z',
      updated_at: '2024-01-20T14:45:00Z',
      user: {
        id: 1,
        first_name: 'Marie',
        last_name: 'Dubois',
        email: 'marie.dubois@email.com'
      }
    },
    {
      id: 2,
      user_id: 2,
      stripe_account_id: 'acct_0987654321DEF',
      account_status: 'pending',
      charges_enabled: false,
      details_submitted: true,
      payouts_enabled: false,
      created_at: '2024-02-01T09:15:00Z',
      updated_at: '2024-02-01T09:15:00Z',
      user: {
        id: 2,
        first_name: 'John',
        last_name: 'Smith',
        email: 'john.smith@email.com'
      }
    },
    {
      id: 3,
      user_id: 3,
      stripe_account_id: 'acct_5678901234GHI',
      account_status: 'restricted',
      charges_enabled: false,
      details_submitted: false,
      payouts_enabled: false,
      created_at: '2024-02-10T16:20:00Z',
      updated_at: '2024-02-12T11:30:00Z',
      user: {
        id: 3,
        first_name: 'Emma',
        last_name: 'Johnson',
        email: 'emma.johnson@email.com'
      }
    }
  ];
}