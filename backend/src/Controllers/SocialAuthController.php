<?php

declare(strict_types=1);

namespace KiloShare\Controllers;

use KiloShare\Models\User;
use KiloShare\Utils\Response;
use KiloShare\Utils\Validator;
use KiloShare\Utils\JWTHelper;
use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;
use Carbon\Carbon;

class SocialAuthController
{
    public function googleAuth(ServerRequestInterface $request): ResponseInterface
    {
        $data = json_decode($request->getBody()->getContents(), true);

        $validator = new Validator();
        $rules = [
            'id_token' => Validator::required()->stringType(),
            'email' => Validator::required()->email(),
            'name' => Validator::required()->stringType(),
            'picture' => Validator::optional(Validator::stringType()),
        ];

        if (!$validator->validate($data, $rules)) {
            return Response::validationError($validator->getErrors());
        }

        try {
            // TODO: Vérifier le token Google avec l'API Google
            // Pour l'instant, on fait confiance au token fourni par Flutter

            $email = $data['email'];
            $name = $data['name'];
            $picture = $data['picture'] ?? null;
            
            // Diviser le nom complet
            $nameParts = explode(' ', trim($name), 2);
            $firstName = $nameParts[0];
            $lastName = isset($nameParts[1]) ? $nameParts[1] : '';

            // Chercher l'utilisateur existant
            $user = User::where('email', $email)->first();

            if ($user) {
                // Utilisateur existant - mise à jour des infos sociales
                $user->social_provider = 'google';
                $user->social_id = $data['id_token']; // Utiliser une partie du token comme ID
                if (!$user->profile_picture && $picture) {
                    $user->profile_picture = $picture;
                }
                $user->last_login_at = Carbon::now();
                $user->save();
            } else {
                // Nouvel utilisateur - création
                $user = User::create([
                    'email' => $email,
                    'first_name' => $firstName,
                    'last_name' => $lastName,
                    'profile_picture' => $picture,
                    'social_provider' => 'google',
                    'social_id' => $data['id_token'],
                    'email_verified_at' => Carbon::now(), // Les comptes Google sont déjà vérifiés
                    'last_login_at' => Carbon::now(),
                    'status' => 'active',
                    'role' => 'user',
                    'is_verified' => true,
                ]);
            }

            // Générer les tokens JWT
            $accessToken = JWTHelper::generateAccessToken($user);
            $refreshToken = JWTHelper::generateRefreshToken($user);

            return Response::success([
                'access_token' => $accessToken,
                'refresh_token' => $refreshToken,
                'token_type' => 'Bearer',
                'expires_in' => 3600,
                'user' => [
                    'id' => $user->id,
                    'uuid' => $user->uuid,
                    'email' => $user->email,
                    'first_name' => $user->first_name,
                    'last_name' => $user->last_name,
                    'full_name' => $user->full_name,
                    'profile_picture' => $user->profile_picture,
                    'is_verified' => $user->is_verified,
                    'role' => $user->role,
                    'created_at' => $user->created_at,
                ]
            ], 'Google authentication successful');

        } catch (\Exception $e) {
            return Response::serverError('Google authentication failed: ' . $e->getMessage());
        }
    }

    public function appleAuth(ServerRequestInterface $request): ResponseInterface
    {
        $data = json_decode($request->getBody()->getContents(), true);

        $validator = new Validator();
        $rules = [
            'identity_token' => Validator::required()->stringType(),
            'email' => Validator::optional(Validator::email()),
            'name' => Validator::optional(Validator::stringType()),
            'user_identifier' => Validator::required()->stringType(),
        ];

        if (!$validator->validate($data, $rules)) {
            return Response::validationError($validator->getErrors());
        }

        try {
            // TODO: Vérifier le token Apple avec l'API Apple
            // Pour l'instant, on fait confiance au token fourni par Flutter

            $userIdentifier = $data['user_identifier'];
            $email = $data['email'] ?? null;
            $name = $data['name'] ?? null;

            // Chercher l'utilisateur existant par social_id (Apple ID)
            $user = User::where('social_provider', 'apple')
                       ->where('social_id', $userIdentifier)
                       ->first();

            // Si pas trouvé par social_id et email fourni, chercher par email
            if (!$user && $email) {
                $user = User::where('email', $email)->first();
            }

            if ($user) {
                // Utilisateur existant
                $user->social_provider = 'apple';
                $user->social_id = $userIdentifier;
                $user->last_login_at = Carbon::now();
                $user->save();
            } else {
                // Nouvel utilisateur
                if (!$email) {
                    return Response::error('Email is required for new Apple Sign In users');
                }

                $nameParts = $name ? explode(' ', trim($name), 2) : ['Apple', 'User'];
                $firstName = $nameParts[0];
                $lastName = isset($nameParts[1]) ? $nameParts[1] : '';

                $user = User::create([
                    'email' => $email,
                    'first_name' => $firstName,
                    'last_name' => $lastName,
                    'social_provider' => 'apple',
                    'social_id' => $userIdentifier,
                    'email_verified_at' => Carbon::now(), // Les comptes Apple sont déjà vérifiés
                    'last_login_at' => Carbon::now(),
                    'status' => 'active',
                    'role' => 'user',
                    'is_verified' => true,
                ]);
            }

            // Générer les tokens JWT
            $accessToken = JWTHelper::generateAccessToken($user);
            $refreshToken = JWTHelper::generateRefreshToken($user);

            return Response::success([
                'access_token' => $accessToken,
                'refresh_token' => $refreshToken,
                'token_type' => 'Bearer',
                'expires_in' => 3600,
                'user' => [
                    'id' => $user->id,
                    'uuid' => $user->uuid,
                    'email' => $user->email,
                    'first_name' => $user->first_name,
                    'last_name' => $user->last_name,
                    'full_name' => $user->full_name,
                    'profile_picture' => $user->profile_picture,
                    'is_verified' => $user->is_verified,
                    'role' => $user->role,
                    'created_at' => $user->created_at,
                ]
            ], 'Apple authentication successful');

        } catch (\Exception $e) {
            return Response::serverError('Apple authentication failed: ' . $e->getMessage());
        }
    }

    public function facebookAuth(ServerRequestInterface $request): ResponseInterface
    {
        $data = json_decode($request->getBody()->getContents(), true);

        $validator = new Validator();
        $rules = [
            'access_token' => Validator::required()->stringType(),
            'email' => Validator::required()->email(),
            'name' => Validator::required()->stringType(),
            'id' => Validator::required()->stringType(),
            'picture' => Validator::optional(Validator::stringType()),
        ];

        if (!$validator->validate($data, $rules)) {
            return Response::validationError($validator->getErrors());
        }

        try {
            // TODO: Vérifier le token Facebook avec l'API Facebook

            $email = $data['email'];
            $name = $data['name'];
            $facebookId = $data['id'];
            $picture = $data['picture'] ?? null;
            
            $nameParts = explode(' ', trim($name), 2);
            $firstName = $nameParts[0];
            $lastName = isset($nameParts[1]) ? $nameParts[1] : '';

            // Chercher l'utilisateur existant
            $user = User::where('email', $email)
                       ->orWhere(function($query) use ($facebookId) {
                           $query->where('social_provider', 'facebook')
                                 ->where('social_id', $facebookId);
                       })
                       ->first();

            if ($user) {
                // Utilisateur existant
                $user->social_provider = 'facebook';
                $user->social_id = $facebookId;
                if (!$user->profile_picture && $picture) {
                    $user->profile_picture = $picture;
                }
                $user->last_login_at = Carbon::now();
                $user->save();
            } else {
                // Nouvel utilisateur
                $user = User::create([
                    'email' => $email,
                    'first_name' => $firstName,
                    'last_name' => $lastName,
                    'profile_picture' => $picture,
                    'social_provider' => 'facebook',
                    'social_id' => $facebookId,
                    'email_verified_at' => Carbon::now(),
                    'last_login_at' => Carbon::now(),
                    'status' => 'active',
                    'role' => 'user',
                    'is_verified' => true,
                ]);
            }

            // Générer les tokens JWT
            $accessToken = JWTHelper::generateAccessToken($user);
            $refreshToken = JWTHelper::generateRefreshToken($user);

            return Response::success([
                'access_token' => $accessToken,
                'refresh_token' => $refreshToken,
                'token_type' => 'Bearer',
                'expires_in' => 3600,
                'user' => [
                    'id' => $user->id,
                    'uuid' => $user->uuid,
                    'email' => $user->email,
                    'first_name' => $user->first_name,
                    'last_name' => $user->last_name,
                    'full_name' => $user->full_name,
                    'profile_picture' => $user->profile_picture,
                    'is_verified' => $user->is_verified,
                    'role' => $user->role,
                    'created_at' => $user->created_at,
                ]
            ], 'Facebook authentication successful');

        } catch (\Exception $e) {
            return Response::serverError('Facebook authentication failed: ' . $e->getMessage());
        }
    }
}