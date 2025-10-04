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

    // Appel à l'API backend pour récupérer le profil admin
    const response = await fetch(`${BACKEND_URL}/admin/profile`, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`,
      },
    });

    const data = await response.json();

    if (!response.ok) {
      return NextResponse.json(
        {
          success: false,
          message: data.message || 'Erreur lors de la récupération du profil'
        },
        { status: response.status }
      );
    }

    return NextResponse.json({
      success: true,
      data: {
        profile: data.data?.profile || data.data?.user || data.data
      }
    });

  } catch (error) {
    console.error('Admin profile GET error:', error);
    return NextResponse.json(
      { success: false, message: 'Erreur du serveur' },
      { status: 500 }
    );
  }
}

export async function PUT(request: NextRequest) {
  try {
    const token = getAuthToken(request);

    if (!token) {
      return NextResponse.json(
        { success: false, message: 'Token d\'authentification requis' },
        { status: 401 }
      );
    }

    const body = await request.json();
    const { first_name, last_name, email, current_password, new_password } = body;

    // Validation basique
    if (!first_name || !last_name || !email) {
      return NextResponse.json(
        { success: false, message: 'Prénom, nom et email sont requis' },
        { status: 400 }
      );
    }

    // Si nouveau mot de passe, vérifier que l'ancien est fourni
    if (new_password && !current_password) {
      return NextResponse.json(
        { success: false, message: 'Mot de passe actuel requis pour changer le mot de passe' },
        { status: 400 }
      );
    }

    // Appel à l'API backend pour mettre à jour le profil admin
    const response = await fetch(`${BACKEND_URL}/admin/profile`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`,
      },
      body: JSON.stringify(body),
    });

    const data = await response.json();

    if (!response.ok) {
      return NextResponse.json(
        {
          success: false,
          message: data.message || 'Erreur lors de la mise à jour du profil'
        },
        { status: response.status }
      );
    }

    return NextResponse.json({
      success: true,
      message: 'Profil mis à jour avec succès',
      data: {
        profile: data.data?.profile || data.data?.user || data.data
      }
    });

  } catch (error) {
    console.error('Admin profile PUT error:', error);
    return NextResponse.json(
      { success: false, message: 'Erreur du serveur' },
      { status: 500 }
    );
  }
}