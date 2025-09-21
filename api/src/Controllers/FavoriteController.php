<?php

declare(strict_types=1);

namespace KiloShare\Controllers;

use KiloShare\Models\Trip;
use KiloShare\Models\TripFavorite;
use KiloShare\Utils\Response;
use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;

class FavoriteController
{
    public function getUserFavorites(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $queryParams = $request->getQueryParams();

        try {
            $page = (int) ($queryParams['page'] ?? 1);
            $limit = (int) ($queryParams['limit'] ?? 20);
            
            $favorites = TripFavorite::where('user_id', $user->id)
                                   ->with(['trip.user', 'trip.images'])
                                   ->orderBy('id', 'desc')
                                   ->skip(($page - 1) * $limit)
                                   ->take($limit)
                                   ->get();

            $total = TripFavorite::where('user_id', $user->id)->count();

            return Response::success([
                'favorites' => $favorites->map(function ($favorite) {
                    $trip = $favorite->trip;
                    return [
                        'id' => $favorite->id,
                        'trip' => [
                            'id' => $trip->id,
                            'uuid' => $trip->uuid,
                            'title' => $trip->title,
                            'departure_city' => $trip->departure_city,
                            'arrival_city' => $trip->arrival_city,
                            'departure_date' => $trip->departure_date,
                            'price_per_kg' => $trip->price_per_kg,
                            'currency' => $trip->currency,
                            'status' => $trip->status,
                            'user' => [
                                'first_name' => $trip->user->first_name,
                                'profile_picture' => $trip->user->profile_picture,
                                'is_verified' => $trip->user->is_verified,
                            ],
                            'main_image' => $trip->images->first() ? [
                                'url' => $trip->images->first()->url,
                                'thumbnail' => $trip->images->first()->thumbnail,
                            ] : null,
                        ],
                    ];
                }),
                'pagination' => [
                    'current_page' => $page,
                    'per_page' => $limit,
                    'total' => $total,
                    'total_pages' => ceil($total / $limit),
                ]
            ]);

        } catch (\Exception $e) {
            return Response::serverError('Failed to fetch favorites: ' . $e->getMessage());
        }
    }

    public function toggleFavorite(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $tripId = $request->getAttribute('id');

        try {
            $trip = Trip::find($tripId);

            if (!$trip) {
                return Response::notFound('Trip not found');
            }

            $isFavorite = TripFavorite::toggleFavorite($user->id, (int)$tripId);

            return Response::success([
                'data' => [
                    'is_favorite' => $isFavorite,
                    'trip_id' => $tripId,
                ]
            ], $isFavorite ? 'Trip added to favorites' : 'Trip removed from favorites');

        } catch (\Exception $e) {
            return Response::serverError('Failed to toggle favorite: ' . $e->getMessage());
        }
    }

    public function addToFavorites(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $tripId = $request->getAttribute('id');

        try {
            $trip = Trip::find($tripId);

            if (!$trip) {
                return Response::notFound('Trip not found');
            }

            if ($trip->user_id === $user->id) {
                return Response::error('Cannot add your own trip to favorites');
            }

            $exists = TripFavorite::where('user_id', $user->id)
                                 ->where('trip_id', $tripId)
                                 ->exists();

            if ($exists) {
                return Response::error('Trip already in favorites');
            }

            TripFavorite::create([
                'user_id' => $user->id,
                'trip_id' => $tripId,
            ]);

            return Response::success([
                'trip_id' => $tripId,
                'is_favorite' => true,
            ], 'Trip added to favorites');

        } catch (\Exception $e) {
            return Response::serverError('Failed to add to favorites: ' . $e->getMessage());
        }
    }

    public function removeFromFavorites(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $tripId = $request->getAttribute('id');

        try {
            $favorite = TripFavorite::where('user_id', $user->id)
                                   ->where('trip_id', $tripId)
                                   ->first();

            if (!$favorite) {
                // Si pas de favori trouvé, considérer comme déjà supprimé (succès)
                return Response::success([
                    'trip_id' => $tripId,
                    'is_favorite' => false,
                ], 'Trip was not in favorites');
            }

            $favorite->delete();

            return Response::success([
                'trip_id' => $tripId,
                'is_favorite' => false,
            ], 'Trip removed from favorites');

        } catch (\Exception $e) {
            return Response::serverError('Failed to remove from favorites: ' . $e->getMessage());
        }
    }

    public function checkFavoriteStatus(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $tripId = $request->getAttribute('id');

        try {
            $isFavorite = TripFavorite::isFavorite($user->id, (int) $tripId);

            return Response::success([
                'trip_id' => $tripId,
                'is_favorite' => $isFavorite,
            ]);

        } catch (\Exception $e) {
            return Response::serverError('Failed to check favorite status: ' . $e->getMessage());
        }
    }
}