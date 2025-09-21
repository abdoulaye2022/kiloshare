<?php

namespace KiloShare\Controllers;

use KiloShare\Models\BookingNegotiation;
use KiloShare\Models\Trip;
use KiloShare\Utils\Response;
use KiloShare\Utils\ValidationHelper;
use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;

class BookingNegotiationController extends BaseController
{
    /**
     * Créer une nouvelle négociation
     */
    public function createNegotiation(ServerRequestInterface $request): ResponseInterface
    {
        try {
            $user = $request->getAttribute('user');
            $data = $request->getParsedBody();

            // Validation
            $validation = ValidationHelper::validate($data, [
                'trip_id' => 'required|integer',
                'proposed_price' => 'required|numeric|min:1',
                'proposed_weight' => 'numeric|min:0.1',
                'package_description' => 'required|string|max:1000',
                'pickup_address' => 'required|string|max:500',
                'delivery_address' => 'required|string|max:500',
                'special_instructions' => 'string|max:500',
            ]);

            if (!$validation['valid']) {
                return Response::error('Données invalides', $validation['errors'], 400);
            }

            // Vérifier que le voyage existe et est disponible
            $trip = Trip::find($data['trip_id']);
            if (!$trip) {
                return Response::error('Voyage non trouvé', null, 404);
            }

            if ($trip->user_id === $user->id) {
                return Response::error('Vous ne pouvez pas faire une proposition sur votre propre voyage', null, 400);
            }

            if ($trip->status !== Trip::STATUS_ACTIVE) {
                return Response::error('Ce voyage n\'est plus disponible pour de nouvelles réservations', null, 400);
            }

            // Vérifier s'il n'y a pas déjà une négociation active pour cet expéditeur
            $existingNegotiation = BookingNegotiation::where('trip_id', $data['trip_id'])
                ->where('sender_id', $user->id)
                ->where('status', BookingNegotiation::STATUS_PENDING)
                ->first();

            if ($existingNegotiation) {
                return Response::error('Vous avez déjà une négociation en cours pour ce voyage', null, 400);
            }

            // Créer la négociation
            $negotiation = BookingNegotiation::create([
                'trip_id' => $data['trip_id'],
                'sender_id' => $user->id,
                'status' => BookingNegotiation::STATUS_PENDING,
                'proposed_weight' => $data['proposed_weight'] ?? null,
                'proposed_price' => $data['proposed_price'],
                'package_description' => $data['package_description'],
                'pickup_address' => $data['pickup_address'],
                'delivery_address' => $data['delivery_address'],
                'special_instructions' => $data['special_instructions'] ?? null,
                'messages' => [],
                'expires_at' => now()->addDays(7) // Expire dans 7 jours
            ]);

            // Charger les relations
            $negotiation->load(['trip', 'sender']);

            return Response::success('Négociation créée avec succès', [
                'negotiation' => $negotiation
            ]);

        } catch (\Exception $e) {
            error_log("Erreur création négociation: " . $e->getMessage());
            return Response::error('Erreur lors de la création de la négociation', null, 500);
        }
    }

    /**
     * Lister les négociations pour un voyage (voyageur)
     */
    public function getNegotiationsForTrip(ServerRequestInterface $request): ResponseInterface
    {
        try {
            $user = $request->getAttribute('user');
            $tripId = $request->getAttribute('trip_id');

            // Vérifier que le voyage appartient à l'utilisateur
            $trip = Trip::where('id', $tripId)
                ->where('user_id', $user->id)
                ->first();

            if (!$trip) {
                return Response::error('Voyage non trouvé ou vous n\'êtes pas autorisé', null, 404);
            }

            $negotiations = BookingNegotiation::where('trip_id', $tripId)
                ->with(['sender'])
                ->orderBy('created_at', 'desc')
                ->get();

            return Response::success('Négociations récupérées', [
                'negotiations' => $negotiations
            ]);

        } catch (\Exception $e) {
            error_log("Erreur récupération négociations: " . $e->getMessage());
            return Response::error('Erreur lors de la récupération des négociations', null, 500);
        }
    }

    /**
     * Lister les négociations d'un expéditeur
     */
    public function getMyNegotiations(ServerRequestInterface $request): ResponseInterface
    {
        try {
            $user = $request->getAttribute('user');

            $negotiations = BookingNegotiation::where('sender_id', $user->id)
                ->with(['trip', 'trip.user'])
                ->orderBy('created_at', 'desc')
                ->get();

            return Response::success('Négociations récupérées', [
                'negotiations' => $negotiations
            ]);

        } catch (\Exception $e) {
            error_log("Erreur récupération négociations: " . $e->getMessage());
            return Response::error('Erreur lors de la récupération des négociations', null, 500);
        }
    }

    /**
     * Accepter une négociation
     */
    public function acceptNegotiation(ServerRequestInterface $request): ResponseInterface
    {
        try {
            $user = $request->getAttribute('user');
            $negotiationId = $request->getAttribute('negotiation_id');

            $negotiation = BookingNegotiation::with(['trip'])
                ->where('id', $negotiationId)
                ->first();

            if (!$negotiation) {
                return Response::error('Négociation non trouvée', null, 404);
            }

            // Vérifier que c'est le propriétaire du voyage
            if ($negotiation->trip->user_id !== $user->id) {
                return Response::error('Non autorisé', null, 403);
            }

            if (!$negotiation->accept()) {
                return Response::error('Impossible d\'accepter cette négociation (expirée ou déjà traitée)', null, 400);
            }

            // Charger la réservation créée
            $negotiation->load(['booking']);

            return Response::success('Négociation acceptée et réservation créée', [
                'negotiation' => $negotiation,
                'booking' => $negotiation->booking
            ]);

        } catch (\Exception $e) {
            error_log("Erreur acceptation négociation: " . $e->getMessage());
            return Response::error('Erreur lors de l\'acceptation de la négociation', null, 500);
        }
    }

    /**
     * Rejeter une négociation
     */
    public function rejectNegotiation(ServerRequestInterface $request): ResponseInterface
    {
        try {
            $user = $request->getAttribute('user');
            $negotiationId = $request->getAttribute('negotiation_id');

            $negotiation = BookingNegotiation::with(['trip'])
                ->where('id', $negotiationId)
                ->first();

            if (!$negotiation) {
                return Response::error('Négociation non trouvée', null, 404);
            }

            // Vérifier que c'est le propriétaire du voyage
            if ($negotiation->trip->user_id !== $user->id) {
                return Response::error('Non autorisé', null, 403);
            }

            if (!$negotiation->reject()) {
                return Response::error('Impossible de rejeter cette négociation (expirée ou déjà traitée)', null, 400);
            }

            return Response::success('Négociation rejetée');

        } catch (\Exception $e) {
            error_log("Erreur rejet négociation: " . $e->getMessage());
            return Response::error('Erreur lors du rejet de la négociation', null, 500);
        }
    }

    /**
     * Faire une contre-proposition
     */
    public function counterPropose(ServerRequestInterface $request): ResponseInterface
    {
        try {
            $user = $request->getAttribute('user');
            $negotiationId = $request->getAttribute('negotiation_id');
            $data = $request->getParsedBody();

            // Validation
            $validation = ValidationHelper::validate($data, [
                'counter_price' => 'required|numeric|min:1',
                'message' => 'string|max:500',
            ]);

            if (!$validation['valid']) {
                return Response::error('Données invalides', $validation['errors'], 400);
            }

            $negotiation = BookingNegotiation::with(['trip'])
                ->where('id', $negotiationId)
                ->first();

            if (!$negotiation) {
                return Response::error('Négociation non trouvée', null, 404);
            }

            // Vérifier que c'est le propriétaire du voyage
            if ($negotiation->trip->user_id !== $user->id) {
                return Response::error('Non autorisé', null, 403);
            }

            if (!$negotiation->counterPropose($data['counter_price'], $data['message'] ?? null)) {
                return Response::error('Impossible de faire une contre-proposition (expirée ou déjà traitée)', null, 400);
            }

            return Response::success('Contre-proposition envoyée', [
                'negotiation' => $negotiation->fresh()
            ]);

        } catch (\Exception $e) {
            error_log("Erreur contre-proposition: " . $e->getMessage());
            return Response::error('Erreur lors de la contre-proposition', null, 500);
        }
    }

    /**
     * Ajouter un message à une négociation
     */
    public function addMessage(ServerRequestInterface $request): ResponseInterface
    {
        try {
            $user = $request->getAttribute('user');
            $negotiationId = $request->getAttribute('negotiation_id');
            $data = $request->getParsedBody();

            // Validation
            $validation = ValidationHelper::validate($data, [
                'message' => 'required|string|max:1000',
            ]);

            if (!$validation['valid']) {
                return Response::error('Données invalides', $validation['errors'], 400);
            }

            $negotiation = BookingNegotiation::with(['trip'])
                ->where('id', $negotiationId)
                ->first();

            if (!$negotiation) {
                return Response::error('Négociation non trouvée', null, 404);
            }

            // Vérifier que l'utilisateur fait partie de la négociation
            if ($negotiation->sender_id !== $user->id && $negotiation->trip->user_id !== $user->id) {
                return Response::error('Non autorisé', null, 403);
            }

            if (!$negotiation->addMessage($user->id, $data['message'])) {
                return Response::error('Impossible d\'ajouter le message', null, 400);
            }

            return Response::success('Message ajouté', [
                'negotiation' => $negotiation->fresh()
            ]);

        } catch (\Exception $e) {
            error_log("Erreur ajout message: " . $e->getMessage());
            return Response::error('Erreur lors de l\'ajout du message', null, 500);
        }
    }
}