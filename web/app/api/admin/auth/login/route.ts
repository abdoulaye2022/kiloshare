import { NextRequest, NextResponse } from 'next/server';

const BACKEND_URL = process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:8080';

export async function POST(request: NextRequest) {
  try {
    const { email, password } = await request.json();

    // Validation des données
    if (!email || !password) {
      return NextResponse.json(
        { success: false, message: 'Email et mot de passe requis' },
        { status: 400 }
      );
    }

    // Appel à l'API backend pour l'authentification admin
    const response = await fetch(`${BACKEND_URL}/api/v1/admin/auth/login`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ email, password }),
    });

    const data = await response.json();

    if (!response.ok) {
      return NextResponse.json(
        { 
          success: false, 
          message: data.message || 'Échec de la connexion admin' 
        },
        { status: response.status }
      );
    }

    // Vérifier que l'utilisateur a bien le rôle admin
    if (!data.data?.user?.role || data.data.user.role !== 'admin') {
      return NextResponse.json(
        { 
          success: false, 
          message: 'Accès refusé - Seuls les administrateurs peuvent se connecter' 
        },
        { status: 403 }
      );
    }

    return NextResponse.json({
      success: true,
      message: 'Connexion admin réussie',
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
    console.error('Admin login error:', error);
    return NextResponse.json(
      { success: false, message: 'Erreur du serveur' },
      { status: 500 }
    );
  }
}