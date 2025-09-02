<?php

declare(strict_types=1);

namespace KiloShare\Controllers;

use KiloShare\Models\User;
use KiloShare\Utils\Response;
use KiloShare\Utils\Validator;
use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;

class UserProfileController
{
    public function getProfile(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');

        try {
            // Renvoyer tous les champs du profil utilisateur
            return Response::success([
                'user' => [
                    'id' => $user->id,
                    'uuid' => $user->uuid,
                    'email' => $user->email,
                    'phone' => $user->phone,
                    'first_name' => $user->first_name,
                    'last_name' => $user->last_name,
                    'gender' => $user->gender,
                    'date_of_birth' => $user->date_of_birth?->format('Y-m-d'),
                    'nationality' => $user->nationality,
                    'bio' => $user->bio,
                    'website' => $user->website,
                    'profession' => $user->profession,
                    'company' => $user->company,
                    'address_line1' => $user->address_line1,
                    'address_line2' => $user->address_line2,
                    'city' => $user->city,
                    'state_province' => $user->state_province,
                    'postal_code' => $user->postal_code,
                    'country' => $user->country,
                    'preferred_language' => $user->preferred_language,
                    'timezone' => $user->timezone,
                    'emergency_contact_name' => $user->emergency_contact_name,
                    'emergency_contact_phone' => $user->emergency_contact_phone,
                    'emergency_contact_relation' => $user->emergency_contact_relation,
                    'profile_visibility' => $user->profile_visibility,
                    'newsletter_subscribed' => $user->newsletter_subscribed,
                    'marketing_emails' => $user->marketing_emails,
                    'profile_picture' => $user->profile_picture,
                    'is_verified' => $user->is_verified,
                    'email_verified_at' => $user->email_verified_at,
                    'phone_verified_at' => $user->phone_verified_at,
                    'created_at' => $user->created_at,
                    'stats' => [
                        'trips_count' => 0, // Simplifié pour éviter les erreurs
                        'bookings_count' => 0,
                        'favorites_count' => 0,
                        'average_rating' => 0,
                        'reviews_count' => 0,
                    ],
                ]
            ]);

        } catch (\Exception $e) {
            return Response::serverError('Failed to fetch profile: ' . $e->getMessage());
        }
    }

    public function updateProfile(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $data = json_decode($request->getBody()->getContents(), true);

        // Debug: Log des données reçues
        error_log('=== PROFILE UPDATE DEBUG START ===');
        error_log('User ID: ' . $user->id);
        error_log('Data received: ' . json_encode($data));

        $validator = new Validator();
        $rules = [
            'first_name' => Validator::optional(Validator::stringType()->length(1, 100)),
            'last_name' => Validator::optional(Validator::stringType()->length(1, 100)),
            'phone' => Validator::optional(Validator::stringType()->length(1, 20)),
            'gender' => Validator::optional(Validator::in(['male', 'female', 'other', ''])),
            'date_of_birth' => Validator::optional(Validator::stringType()),
            'nationality' => Validator::optional(Validator::stringType()->length(1, 100)),
            'bio' => Validator::optional(Validator::stringType()->length(1, 1000)),
            'website' => Validator::optional(Validator::stringType()),
            'profession' => Validator::optional(Validator::stringType()->length(1, 150)),
            'company' => Validator::optional(Validator::stringType()->length(1, 150)),
            'address_line1' => Validator::optional(Validator::stringType()),
            'address_line2' => Validator::optional(Validator::stringType()),
            'city' => Validator::optional(Validator::stringType()->length(1, 100)),
            'state_province' => Validator::optional(Validator::stringType()->length(1, 100)),
            'postal_code' => Validator::optional(Validator::stringType()->length(1, 20)),
            'country' => Validator::optional(Validator::stringType()->length(1, 100)),
            'preferred_language' => Validator::optional(Validator::stringType()->length(1, 10)),
            'timezone' => Validator::optional(Validator::stringType()->length(1, 50)),
            'profile_visibility' => Validator::optional(Validator::in(['public', 'private', 'friends_only'])),
            'newsletter_subscribed' => Validator::optional(Validator::in([0, 1, true, false])),
            'marketing_emails' => Validator::optional(Validator::in([0, 1, true, false])),
            'emergency_contact_name' => Validator::optional(Validator::stringType()),
            'emergency_contact_phone' => Validator::optional(Validator::stringType()),
            'emergency_contact_relation' => Validator::optional(Validator::stringType()),
            'profile_picture' => Validator::optional(Validator::stringType()),
        ];

        error_log('Validation rules set');

        if (!$validator->validate($data, $rules)) {
            error_log('Validation failed: ' . json_encode($validator->getErrors()));
            return Response::validationError($validator->getErrors());
        }

        error_log('Validation passed');

        try {
            $updatedFields = [];

            // Mise à jour de tous les champs
            if (isset($data['first_name'])) {
                $user->first_name = $data['first_name'];
                $updatedFields[] = 'first_name: ' . $data['first_name'];
            }
            if (isset($data['last_name'])) {
                $user->last_name = $data['last_name'];
                $updatedFields[] = 'last_name: ' . $data['last_name'];
            }
            if (isset($data['phone'])) {
                $user->phone = $data['phone'];
                $updatedFields[] = 'phone: ' . $data['phone'];
            }
            if (isset($data['gender'])) {
                $user->gender = $data['gender'] ?: null;
                $updatedFields[] = 'gender: ' . ($data['gender'] ?: 'null');
            }
            if (isset($data['date_of_birth'])) {
                $user->date_of_birth = $data['date_of_birth'] ?: null;
                $updatedFields[] = 'date_of_birth: ' . ($data['date_of_birth'] ?: 'null');
            }
            if (isset($data['nationality'])) {
                $user->nationality = $data['nationality'] ?: null;
                $updatedFields[] = 'nationality: ' . ($data['nationality'] ?: 'null');
            }
            if (isset($data['bio'])) {
                $user->bio = $data['bio'] ?: null;
                $updatedFields[] = 'bio: ' . ($data['bio'] ?: 'null');
            }
            if (isset($data['website'])) {
                $user->website = $data['website'] ?: null;
                $updatedFields[] = 'website: ' . ($data['website'] ?: 'null');
            }
            if (isset($data['profession'])) {
                $user->profession = $data['profession'] ?: null;
                $updatedFields[] = 'profession: ' . ($data['profession'] ?: 'null');
            }
            if (isset($data['company'])) {
                $user->company = $data['company'] ?: null;
                $updatedFields[] = 'company: ' . ($data['company'] ?: 'null');
            }
            if (isset($data['address_line1'])) {
                $user->address_line1 = $data['address_line1'] ?: null;
                $updatedFields[] = 'address_line1: ' . ($data['address_line1'] ?: 'null');
            }
            if (isset($data['address_line2'])) {
                $user->address_line2 = $data['address_line2'] ?: null;
                $updatedFields[] = 'address_line2: ' . ($data['address_line2'] ?: 'null');
            }
            if (isset($data['city'])) {
                $user->city = $data['city'] ?: null;
                $updatedFields[] = 'city: ' . ($data['city'] ?: 'null');
            }
            if (isset($data['state_province'])) {
                $user->state_province = $data['state_province'] ?: null;
                $updatedFields[] = 'state_province: ' . ($data['state_province'] ?: 'null');
            }
            if (isset($data['postal_code'])) {
                $user->postal_code = $data['postal_code'] ?: null;
                $updatedFields[] = 'postal_code: ' . ($data['postal_code'] ?: 'null');
            }
            if (isset($data['country'])) {
                $user->country = $data['country'] ?: null;
                $updatedFields[] = 'country: ' . ($data['country'] ?: 'null');
            }
            if (isset($data['preferred_language'])) {
                $user->preferred_language = $data['preferred_language'] ?: 'fr';
                $updatedFields[] = 'preferred_language: ' . ($data['preferred_language'] ?: 'fr');
            }
            if (isset($data['timezone'])) {
                $user->timezone = $data['timezone'] ?: 'Europe/Paris';
                $updatedFields[] = 'timezone: ' . ($data['timezone'] ?: 'Europe/Paris');
            }
            if (isset($data['profile_visibility'])) {
                $user->profile_visibility = $data['profile_visibility'] ?: 'public';
                $updatedFields[] = 'profile_visibility: ' . ($data['profile_visibility'] ?: 'public');
            }
            if (isset($data['newsletter_subscribed'])) {
                $user->newsletter_subscribed = $data['newsletter_subscribed'] ? 1 : 0;
                $updatedFields[] = 'newsletter_subscribed: ' . ($data['newsletter_subscribed'] ? '1' : '0');
            }
            if (isset($data['marketing_emails'])) {
                $user->marketing_emails = $data['marketing_emails'] ? 1 : 0;
                $updatedFields[] = 'marketing_emails: ' . ($data['marketing_emails'] ? '1' : '0');
            }
            if (isset($data['emergency_contact_name'])) {
                $user->emergency_contact_name = $data['emergency_contact_name'] ?: null;
                $updatedFields[] = 'emergency_contact_name: ' . ($data['emergency_contact_name'] ?: 'null');
            }
            if (isset($data['emergency_contact_phone'])) {
                $user->emergency_contact_phone = $data['emergency_contact_phone'] ?: null;
                $updatedFields[] = 'emergency_contact_phone: ' . ($data['emergency_contact_phone'] ?: 'null');
            }
            if (isset($data['emergency_contact_relation'])) {
                $user->emergency_contact_relation = $data['emergency_contact_relation'] ?: null;
                $updatedFields[] = 'emergency_contact_relation: ' . ($data['emergency_contact_relation'] ?: 'null');
            }
            if (isset($data['profile_picture'])) {
                $user->profile_picture = $data['profile_picture'] ?: null;
                $updatedFields[] = 'profile_picture: ' . ($data['profile_picture'] ?: 'null');
            }

            error_log('Fields to update: ' . implode(', ', $updatedFields));
            
            $result = $user->save();
            error_log('Save result: ' . ($result ? 'success' : 'failed'));
            
            if ($result) {
                error_log('Profile updated successfully in database');
            } else {
                error_log('Failed to save to database');
            }

            error_log('=== PROFILE UPDATE DEBUG END ===');

            return Response::success([
                'user' => [
                    'id' => $user->id,
                    'first_name' => $user->first_name,
                    'last_name' => $user->last_name,
                    'phone' => $user->phone,
                    'updated_at' => $user->updated_at,
                ]
            ], 'Profile updated successfully');

        } catch (\Exception $e) {
            return Response::serverError('Failed to update profile: ' . $e->getMessage());
        }
    }

    public function uploadProfilePicture(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');

        try {
            // TODO: Implémenter l'upload d'image
            // Pour l'instant, retourner un succès fictif
            
            return Response::success([
                'message' => 'Profile picture uploaded successfully'
            ]);

        } catch (\Exception $e) {
            return Response::serverError('Failed to upload profile picture: ' . $e->getMessage());
        }
    }

    public function deleteAccount(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $data = json_decode($request->getBody()->getContents(), true);

        if (!isset($data['password'])) {
            return Response::validationError(['password' => 'Password confirmation required']);
        }

        if (!password_verify($data['password'], $user->password_hash)) {
            return Response::error('Invalid password confirmation');
        }

        try {
            // Soft delete
            $user->delete();

            return Response::success([
                'message' => 'Account deleted successfully'
            ]);

        } catch (\Exception $e) {
            return Response::serverError('Failed to delete account: ' . $e->getMessage());
        }
    }

    public function getUserPublicProfile(ServerRequestInterface $request): ResponseInterface
    {
        $userId = $request->getAttribute('id');

        try {
            $user = User::with(['receivedReviews.reviewer'])
                       ->find($userId);

            if (!$user) {
                return Response::notFound('User not found');
            }

            return Response::success([
                'user' => [
                    'id' => $user->id,
                    'uuid' => $user->uuid,
                    'first_name' => $user->first_name,
                    'profile_picture' => $user->profile_picture,
                    'is_verified' => $user->is_verified,
                    'created_at' => $user->created_at,
                    'stats' => [
                        'trips_count' => $user->trips()->published()->count(),
                        'average_rating' => $user->receivedReviews()->avg('rating') ?: 0,
                        'reviews_count' => $user->receivedReviews()->count(),
                    ],
                    'recent_reviews' => $user->receivedReviews()
                        ->public()
                        ->latest()
                        ->take(5)
                        ->get()
                        ->map(function ($review) {
                            return [
                                'id' => $review->id,
                                'rating' => $review->rating,
                                'title' => $review->title,
                                'comment' => $review->comment,
                                'created_at' => $review->created_at,
                                'reviewer' => [
                                    'first_name' => $review->reviewer->first_name,
                                    'profile_picture' => $review->reviewer->profile_picture,
                                ],
                            ];
                        }),
                ]
            ]);

        } catch (\Exception $e) {
            return Response::serverError('Failed to fetch user profile: ' . $e->getMessage());
        }
    }
}