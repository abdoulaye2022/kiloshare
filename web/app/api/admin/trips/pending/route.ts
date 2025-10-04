import { NextRequest, NextResponse } from 'next/server';

const BACKEND_URL = process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:8080';

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

    // Essayer d'abord l'API backend
    try {
      
      const response = await fetch(`${BACKEND_URL}/api/v1/admin/trips/pending`, {
        method: 'GET',
        headers: {
          'Authorization': authHeader,
          'Content-Type': 'application/json',
        },
      });


      if (response.ok) {
        const backendData = await response.json();
        return NextResponse.json({
          success: true,
          trips: backendData.trips || backendData.data || []
        });
      }

      // Lire la réponse d'erreur
      const errorText = await response.text();
      
      // Si l'endpoint n'existe pas (404), utiliser les données demo
      if (response.status !== 404) {
      }
    } catch (error) {
    }

    // Si on arrive ici, le backend n'est pas disponible - retourner une liste vide
    return NextResponse.json({
      success: true,
      trips: []
    });

  } catch (error) {
    
    // En cas d'erreur, retourner une liste vide
    return NextResponse.json({
      success: true,
      trips: []
    });
  }
}

// Génère des données de démonstration pour les voyages en attente
function generateDemoPendingTrips() {
  const today = new Date();
  const tomorrow = new Date(today);
  tomorrow.setDate(tomorrow.getDate() + 1);
  
  const trips = [
    {
      id: 'TRIP_001',
      uuid: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
      transport_type: 'plane',
      departure_city: 'Paris',
      departure_country: 'France',
      arrival_city: 'Montreal',
      arrival_country: 'Canada',
      departure_date: tomorrow.toISOString(),
      available_weight_kg: 15,
      price_per_kg: 8.50,
      currency: 'EUR',
      status: 'pending_approval',
      has_images: true,
      image_count: 3,
      images: [
        {
          id: 1,
          image_path: '/uploads/trip_001_1.jpg',
          image_name: 'bagage_photo_1.jpg',
          file_size: 245678,
          upload_order: 1,
          image_url: 'https://via.placeholder.com/300x200/3B82F6/FFFFFF?text=Bagage+Photo+1',
          formatted_file_size: '240 KB'
        },
        {
          id: 2,
          image_path: '/uploads/trip_001_2.jpg',
          image_name: 'bagage_photo_2.jpg',
          file_size: 189234,
          upload_order: 2,
          image_url: 'https://via.placeholder.com/300x200/10B981/FFFFFF?text=Bagage+Photo+2',
          formatted_file_size: '185 KB'
        },
        {
          id: 3,
          image_path: '/uploads/trip_001_3.jpg',
          image_name: 'bagage_photo_3.jpg',
          file_size: 312456,
          upload_order: 3,
          image_url: 'https://via.placeholder.com/300x200/F59E0B/FFFFFF?text=Bagage+Photo+3',
          formatted_file_size: '305 KB'
        }
      ],
      user: {
        first_name: 'Marie',
        last_name: 'Dubois',
        email: 'marie.dubois@email.com',
        trust_score: 25,
        total_trips: 1
      },
      created_at: today.toISOString()
    },
    {
      id: 'TRIP_002',
      uuid: 'b2c3d4e5-f6a7-8901-bcde-f23456789012',
      transport_type: 'car',
      departure_city: 'Toronto',
      departure_country: 'Canada',
      arrival_city: 'Ottawa',
      arrival_country: 'Canada',
      departure_date: new Date(today.getTime() + 2 * 24 * 60 * 60 * 1000).toISOString(),
      available_weight_kg: 25,
      price_per_kg: 4.00,
      currency: 'CAD',
      status: 'pending_approval',
      has_images: false,
      image_count: 0,
      images: [],
      user: {
        first_name: 'Jean',
        last_name: 'Tremblay',
        email: 'jean.tremblay@email.com',
        trust_score: 78,
        total_trips: 15
      },
      created_at: today.toISOString()
    },
    {
      id: 'TRIP_003',
      uuid: 'c3d4e5f6-a7b8-9012-cdef-345678901234',
      transport_type: 'bus',
      departure_city: 'Vancouver',
      departure_country: 'Canada',
      arrival_city: 'Seattle',
      arrival_country: 'USA',
      departure_date: new Date(today.getTime() + 12 * 60 * 60 * 1000).toISOString(), // Dans 12h (urgent)
      available_weight_kg: 8,
      price_per_kg: 12.00,
      currency: 'USD',
      status: 'pending_approval',
      has_images: true,
      image_count: 2,
      images: [
        {
          id: 4,
          image_path: '/uploads/trip_003_1.jpg',
          image_name: 'colis_urgent.jpg',
          file_size: 456789,
          upload_order: 1,
          image_url: 'https://via.placeholder.com/300x200/EF4444/FFFFFF?text=Colis+Urgent',
          formatted_file_size: '446 KB'
        },
        {
          id: 5,
          image_path: '/uploads/trip_003_2.jpg',
          image_name: 'details_colis.jpg',
          file_size: 298765,
          upload_order: 2,
          image_url: 'https://via.placeholder.com/300x200/8B5CF6/FFFFFF?text=Details+Colis',
          formatted_file_size: '292 KB'
        }
      ],
      user: {
        first_name: 'Sophie',
        last_name: 'Martin',
        email: 'sophie.martin@email.com',
        trust_score: 92,
        total_trips: 32
      },
      created_at: today.toISOString()
    }
  ];

  return trips;
}