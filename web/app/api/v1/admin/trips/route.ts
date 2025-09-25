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
    const include = searchParams.get('include') || '';

    try {
      // Essayer d'abord l'API backend
      const backendUrl = `${BACKEND_URL}/api/v1/admin/trips?status=${status}&limit=${limit}&include=${include}`;
      console.log('🔍 Appel backend trips:', backendUrl);

      const response = await fetch(backendUrl, {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
        },
      });

      if (response.ok) {
        const data = await response.json();
        console.log('✅ Backend trips data received:', data);

        // Normaliser la réponse
        return NextResponse.json({
          success: true,
          data: {
            trips: data.data?.trips || data.trips || data.data || []
          }
        });
      }

      console.log('❌ Backend trips not available, status:', response.status);
    } catch (fetchError) {
      console.log('🚨 Backend trips fetch failed:', fetchError);
    }

    // Si le backend n'est pas disponible, utiliser des données de démonstration
    console.log('⚠️ Utilisation des données de démonstration pour les trips');

    const demoTrips = generateDemoTrips(status);

    return NextResponse.json({
      success: true,
      data: {
        trips: demoTrips
      }
    });

  } catch (error) {
    console.error('Admin trips API error:', error);
    return NextResponse.json(
      { success: false, message: 'Erreur du serveur' },
      { status: 500 }
    );
  }
}

// Générer des données de démonstration avec images
function generateDemoTrips(status: string) {
  const today = new Date();
  const tomorrow = new Date(today);
  tomorrow.setDate(tomorrow.getDate() + 1);

  const allTrips = [
    {
      id: 1,
      uuid: 'trip-001-uuid',
      title: 'Paris → New York',
      transport_type: 'plane',
      departure_city: 'Paris',
      departure_country: 'France',
      arrival_city: 'New York',
      arrival_country: 'USA',
      departure_date: tomorrow.toISOString(),
      available_weight_kg: 15,
      price_per_kg: 12.50,
      currency: 'EUR',
      status: 'active',
      description: 'Voyage d\'affaires avec espace disponible pour colis légers',
      created_at: today.toISOString(),
      updated_at: today.toISOString(),
      user: {
        id: 1,
        first_name: 'Marie',
        last_name: 'Dubois',
        email: 'marie.dubois@email.com',
        phone: '+33123456789'
      },
      // Images en format trip_images (comme dans votre BDD)
      trip_images: [
        {
          id: 1,
          trip_id: 1,
          image_url: 'https://via.placeholder.com/400x300/3B82F6/FFFFFF?text=Avion+Paris-NY',
          file_path: '/uploads/trips/trip_1_image_1.jpg',
          is_primary: true,
          description: 'Vue de l\'avion'
        },
        {
          id: 2,
          trip_id: 1,
          image_url: 'https://via.placeholder.com/400x300/10B981/FFFFFF?text=Bagage+Autorise',
          file_path: '/uploads/trips/trip_1_image_2.jpg',
          is_primary: false,
          description: 'Espace bagages disponible'
        },
        {
          id: 3,
          trip_id: 1,
          image_url: 'https://via.placeholder.com/400x300/F59E0B/FFFFFF?text=Documents+Voyage',
          file_path: '/uploads/trips/trip_1_image_3.jpg',
          is_primary: false,
          description: 'Documents de voyage'
        }
      ],
      // Aussi le format images pour compatibilité
      images: [
        {
          id: 1,
          trip_id: 1,
          image_url: 'https://via.placeholder.com/400x300/3B82F6/FFFFFF?text=Avion+Paris-NY',
          image_path: '/uploads/trips/trip_1_image_1.jpg',
          is_primary: true,
          caption: 'Vue de l\'avion'
        },
        {
          id: 2,
          trip_id: 1,
          image_url: 'https://via.placeholder.com/400x300/10B981/FFFFFF?text=Bagage+Autorise',
          image_path: '/uploads/trips/trip_1_image_2.jpg',
          is_primary: false,
          caption: 'Espace bagages disponible'
        },
        {
          id: 3,
          trip_id: 1,
          image_url: 'https://via.placeholder.com/400x300/F59E0B/FFFFFF?text=Documents+Voyage',
          image_path: '/uploads/trips/trip_1_image_3.jpg',
          is_primary: false,
          caption: 'Documents de voyage'
        }
      ]
    },
    {
      id: 2,
      uuid: 'trip-002-uuid',
      title: 'London → Montreal',
      transport_type: 'plane',
      departure_city: 'London',
      departure_country: 'UK',
      arrival_city: 'Montreal',
      arrival_country: 'Canada',
      departure_date: new Date(today.getTime() + 3 * 24 * 60 * 60 * 1000).toISOString(),
      available_weight_kg: 20,
      price_per_kg: 8.00,
      currency: 'GBP',
      status: 'pending_approval',
      description: 'Vol direct avec possibilité de transport de colis fragiles',
      created_at: new Date(today.getTime() - 24 * 60 * 60 * 1000).toISOString(),
      updated_at: today.toISOString(),
      user: {
        id: 2,
        first_name: 'John',
        last_name: 'Smith',
        email: 'john.smith@email.com',
        phone: '+447123456789'
      },
      trip_images: [
        {
          id: 4,
          trip_id: 2,
          image_url: 'https://via.placeholder.com/400x300/EF4444/FFFFFF?text=Vol+London-Montreal',
          file_path: '/uploads/trips/trip_2_image_1.jpg',
          is_primary: true,
          description: 'Billet d\'avion'
        },
        {
          id: 5,
          trip_id: 2,
          image_url: 'https://via.placeholder.com/400x300/8B5CF6/FFFFFF?text=Espace+Bagage',
          file_path: '/uploads/trips/trip_2_image_2.jpg',
          is_primary: false,
          description: 'Espace disponible en soute'
        }
      ],
      images: [
        {
          id: 4,
          trip_id: 2,
          image_url: 'https://via.placeholder.com/400x300/EF4444/FFFFFF?text=Vol+London-Montreal',
          image_path: '/uploads/trips/trip_2_image_1.jpg',
          is_primary: true,
          caption: 'Billet d\'avion'
        },
        {
          id: 5,
          trip_id: 2,
          image_url: 'https://via.placeholder.com/400x300/8B5CF6/FFFFFF?text=Espace+Bagage',
          image_path: '/uploads/trips/trip_2_image_2.jpg',
          is_primary: false,
          caption: 'Espace disponible en soute'
        }
      ]
    },
    {
      id: 3,
      uuid: 'trip-003-uuid',
      title: 'Toronto → Vancouver',
      transport_type: 'car',
      departure_city: 'Toronto',
      departure_country: 'Canada',
      arrival_city: 'Vancouver',
      arrival_country: 'Canada',
      departure_date: new Date(today.getTime() + 5 * 24 * 60 * 60 * 1000).toISOString(),
      available_weight_kg: 30,
      price_per_kg: 3.50,
      currency: 'CAD',
      status: 'completed',
      description: 'Road trip avec beaucoup d\'espace disponible',
      created_at: new Date(today.getTime() - 7 * 24 * 60 * 60 * 1000).toISOString(),
      updated_at: new Date(today.getTime() - 1 * 24 * 60 * 60 * 1000).toISOString(),
      user: {
        id: 3,
        first_name: 'Emma',
        last_name: 'Johnson',
        email: 'emma.johnson@email.com',
        phone: '+14161234567'
      },
      trip_images: [], // Voyage sans images
      images: []
    }
  ];

  // Filtrer selon le statut demandé
  if (status === 'all') {
    return allTrips;
  }

  return allTrips.filter(trip => trip.status === status);
}