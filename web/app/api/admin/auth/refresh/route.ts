import { NextRequest, NextResponse } from 'next/server';

const BACKEND_URL = process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:8080';

export async function POST(request: NextRequest) {
  try {
    const { refresh_token } = await request.json();

    // Validation du refresh token
    if (!refresh_token) {
      return NextResponse.json(
        { success: false, message: 'Refresh token requis' },
        { status: 400 }
      );
    }

    // Appel à l'API backend pour le refresh
    const response = await fetch(`${BACKEND_URL}/api/v1/auth/refresh`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ refresh_token }),
    });

    const data = await response.json();

    if (!response.ok) {
      return NextResponse.json(
        { 
          success: false, 
          message: data.message || 'Échec du refresh token' 
        },
        { status: response.status }
      );
    }

    // Vérifier que l'utilisateur a toujours le rôle admin
    if (!data.data?.user?.role || data.data.user.role !== 'admin') {
      return NextResponse.json(
        { 
          success: false, 
          message: 'Accès refusé - Rôle administrateur requis' 
        },
        { status: 403 }
      );
    }

    return NextResponse.json({
      success: true,
      message: 'Token rafraîchi avec succès',
      token: data.data.tokens.access_token,
      refresh_token: data.data.tokens.refresh_token,
      expires_in: data.data.tokens.expires_in,
      admin: {
        id: data.data.user.id,
        email: data.data.user.email,
        name: `${data.data.user.first_name || ''} ${data.data.user.last_name || ''}`.trim(),
        role: data.data.user.role
      }
    });

  } catch (error) {
    console.error('Admin refresh token error:', error);
    return NextResponse.json(
      { success: false, message: 'Erreur du serveur' },
      { status: 500 }
    );
  }
}