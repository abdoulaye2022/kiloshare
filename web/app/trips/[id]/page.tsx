import { Metadata } from 'next';
import TripDetailClient from './TripDetailClient';

interface Props {
  params: Promise<{ id: string }>
}

async function getTripData(id: string) {
  try {
    const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:8080';
    const response = await fetch(`${apiUrl}/api/v1/trips/${id}`, {
      cache: 'no-store',
    });

    if (!response.ok) {
      return null;
    }

    const data = await response.json();
    return data.data?.trip || data.trip || data;
  } catch (error) {
    console.error('Error fetching trip for metadata:', error);
    return null;
  }
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { id } = await params;
  const trip = await getTripData(id);

  if (!trip) {
    return {
      title: 'Voyage non trouvé - KiloShare',
      description: 'Ce voyage n\'est plus disponible.',
    };
  }

  const baseUrl = process.env.NEXT_PUBLIC_BASE_URL || 'https://kiloshare.com';
  const tripUrl = `${baseUrl}/trips/${id}`;
  const title = `${trip.departure_city} → ${trip.arrival_city} - ${trip.price_per_kg}€/kg`;
  const description = `Réservez cet espace bagages de ${trip.departure_city} vers ${trip.arrival_city}. Départ le ${new Date(trip.departure_date).toLocaleDateString('fr-FR')}. ${trip.remaining_weight || trip.available_weight_kg}kg disponibles à ${trip.price_per_kg}€/kg. ${trip.description || ''}`;

  // Utiliser la première image du voyage ou une image par défaut
  const imageUrl = trip.images && trip.images.length > 0
    ? trip.images[0]
    : `${baseUrl}/og-default-trip.png`;

  return {
    title,
    description,
    openGraph: {
      title,
      description,
      url: tripUrl,
      siteName: 'KiloShare',
      images: [
        {
          url: imageUrl,
          width: 1200,
          height: 630,
          alt: `${trip.departure_city} vers ${trip.arrival_city}`,
        },
      ],
      locale: 'fr_FR',
      type: 'website',
    },
    twitter: {
      card: 'summary_large_image',
      title,
      description,
      images: [imageUrl],
    },
    alternates: {
      canonical: tripUrl,
    },
    other: {
      // Méta tags pour le deep linking
      'al:ios:url': `kiloshare://trips/${id}`,
      'al:ios:app_store_id': '123456789',
      'al:ios:app_name': 'KiloShare',
      'al:android:url': `kiloshare://trips/${id}`,
      'al:android:package': 'com.m2atech.kiloshare',
      'al:android:app_name': 'KiloShare',
      'al:web:url': tripUrl,
    },
  };
}

export default function TripDetailPage() {
  return <TripDetailClient />;
}
