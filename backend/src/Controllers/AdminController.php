<?php

declare(strict_types=1);

namespace KiloShare\Controllers;

use KiloShare\Models\User;
use KiloShare\Models\Trip;
use KiloShare\Models\Booking;
use KiloShare\Utils\Response;
use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;
use Carbon\Carbon;

class AdminController
{
    public function getDashboardStats(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');

        if (!$user->hasRole('admin')) {
            return Response::forbidden('Admin access required');
        }

        try {
            $today = Carbon::today();
            $thisWeek = Carbon::now()->startOfWeek();
            $thisMonth = Carbon::now()->startOfMonth();

            // Statistiques des utilisateurs
            $totalUsers = User::count();
            $newUsersToday = User::whereDate('created_at', $today)->count();
            $newUsersThisWeek = User::where('created_at', '>=', $thisWeek)->count();
            $activeUsers = User::active()->count();
            $verifiedUsers = User::verified()->count();

            // Statistiques des voyages
            $totalTrips = Trip::count();
            $publishedTrips = Trip::published()->count();
            $tripsToday = Trip::whereDate('created_at', $today)->count();
            $tripsThisWeek = Trip::where('created_at', '>=', $thisWeek)->count();
            $pendingTrips = Trip::where('status', Trip::STATUS_PENDING_APPROVAL)->count();

            // Statistiques des réservations
            $totalBookings = Booking::count();
            $activeBookings = Booking::active()->count();
            $bookingsToday = Booking::whereDate('created_at', $today)->count();
            $bookingsThisWeek = Booking::where('created_at', '>=', $thisWeek)->count();

            // Revenus (simulés pour l'instant)
            $revenueToday = 0;
            $revenueThisWeek = 0;
            $revenueThisMonth = 0;
            $commissionsCollected = 0;

            // Métriques de santé
            $completionRate = 0;
            $disputeRate = 0;
            $averageResolutionTime = 0;

            // Alertes critiques
            $suspectedFraud = 0;
            $urgentDisputes = 0;
            $reportedTrips = 0; // TODO: Implement when reports table is populated
            $failedPayments = 0;

            return Response::success([
                'stats' => [
                    // KPIs Financiers
                    'revenue_today' => $revenueToday,
                    'revenue_this_week' => $revenueThisWeek,
                    'revenue_this_month' => $revenueThisMonth,
                    'commissions_collected' => $commissionsCollected,
                    'transactions_pending' => 0,
                    
                    // Activité Plateforme
                    'active_users' => $activeUsers,
                    'total_users' => $totalUsers,
                    'new_registrations_today' => $newUsersToday,
                    'new_registrations_this_week' => $newUsersThisWeek,
                    'verified_users' => $verifiedUsers,
                    'published_trips_today' => $tripsToday,
                    'published_trips_this_week' => $tripsThisWeek,
                    'total_trips' => $totalTrips,
                    'published_trips' => $publishedTrips,
                    'active_bookings' => $activeBookings,
                    'total_bookings' => $totalBookings,
                    'bookings_today' => $bookingsToday,
                    'bookings_this_week' => $bookingsThisWeek,
                    
                    // Santé du Système
                    'trip_completion_rate' => $completionRate,
                    'dispute_rate' => $disputeRate,
                    'average_resolution_time_hours' => $averageResolutionTime,
                    
                    // Alertes Critiques
                    'suspected_fraud_count' => $suspectedFraud,
                    'urgent_disputes_count' => $urgentDisputes,
                    'reported_trips_count' => $reportedTrips,
                    'failed_payments_count' => $failedPayments,
                    'pending_trips_count' => $pendingTrips,
                ],
                'charts' => [
                    'user_growth' => $this->getUserGrowthData(),
                    'trip_growth' => $this->getTripGrowthData(),
                    'booking_growth' => $this->getBookingGrowthData(),
                    'revenue_growth' => $this->getRevenueGrowthData(),
                ]
            ]);

        } catch (\Exception $e) {
            return Response::serverError('Failed to fetch dashboard stats: ' . $e->getMessage());
        }
    }

    public function getUsers(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        
        if (!$user->hasRole('admin')) {
            return Response::forbidden('Admin access required');
        }

        $queryParams = $request->getQueryParams();

        try {
            $page = (int) ($queryParams['page'] ?? 1);
            $limit = (int) ($queryParams['limit'] ?? 25);
            $search = $queryParams['search'] ?? '';
            $status = $queryParams['status'] ?? '';
            $role = $queryParams['role'] ?? '';

            $query = User::with(['trips', 'sentBookings', 'receivedBookings']);

            if ($search) {
                $query->where(function ($q) use ($search) {
                    $q->where('first_name', 'like', "%{$search}%")
                      ->orWhere('last_name', 'like', "%{$search}%")
                      ->orWhere('email', 'like', "%{$search}%");
                });
            }

            if ($status && $status !== 'all') {
                $query->where('status', $status);
            }

            if ($role) {
                $query->where('role', $role);
            }

            // Get total count first, before applying pagination
            $total = $query->count();

            $users = $query->orderBy('created_at', 'desc')
                          ->skip(($page - 1) * $limit)
                          ->take($limit)
                          ->get();

            return Response::success([
                'users' => $users->map(function ($user) {
                    return [
                        'id' => $user->id,
                        'uuid' => $user->uuid,
                        'email' => $user->email,
                        'first_name' => $user->first_name,
                        'last_name' => $user->last_name,
                        'phone' => $user->phone,
                        'status' => $user->status,
                        'role' => $user->role,
                        'is_verified' => $user->is_verified,
                        'email_verified_at' => $user->email_verified_at,
                        'last_login_at' => $user->last_login_at,
                        'created_at' => $user->created_at,
                        'trips_count' => $user->trips->count(),
                        'bookings_count' => $user->sentBookings->count() + $user->receivedBookings->count(),
                    ];
                }),
                'pagination' => [
                    'current_page' => $page,
                    'per_page' => $limit,
                    'total' => $total,
                    'total_pages' => ceil($total / $limit),
                ],
                'filters' => [
                    'search' => $search,
                    'status' => $status,
                    'role' => $role,
                ]
            ]);

        } catch (\Exception $e) {
            return Response::serverError('Failed to fetch users: ' . $e->getMessage());
        }
    }

    public function getUser(ServerRequestInterface $request): ResponseInterface
    {
        $adminUser = $request->getAttribute('user');
        $userId = $request->getAttribute('id');
        
        if (!$adminUser->hasRole('admin')) {
            return Response::forbidden('Admin access required');
        }

        try {
            $user = User::with(['trips', 'bookings.trip'])
                       ->find($userId);

            if (!$user) {
                return Response::notFound('User not found');
            }

            return Response::success([
                'user' => [
                    'id' => $user->id,
                    'uuid' => $user->uuid,
                    'email' => $user->email,
                    'first_name' => $user->first_name,
                    'last_name' => $user->last_name,
                    'phone' => $user->phone,
                    'profile_picture' => $user->profile_picture,
                    'status' => $user->status,
                    'role' => $user->role,
                    'is_verified' => $user->is_verified,
                    'email_verified_at' => $user->email_verified_at,
                    'phone_verified_at' => $user->phone_verified_at,
                    'last_login_at' => $user->last_login_at,
                    'created_at' => $user->created_at,
                    'updated_at' => $user->updated_at,
                    'trips' => $user->trips->map(function ($trip) {
                        return [
                            'id' => $trip->id,
                            'title' => $trip->title,
                            'status' => $trip->status,
                            'departure_city' => $trip->departure_city,
                            'arrival_city' => $trip->arrival_city,
                            'departure_date' => $trip->departure_date,
                            'created_at' => $trip->created_at,
                        ];
                    }),
                    'bookings' => $user->bookings->map(function ($booking) {
                        return [
                            'id' => $booking->id,
                            'status' => $booking->status,
                            'total_price' => $booking->total_price,
                            'created_at' => $booking->created_at,
                            'trip' => [
                                'title' => $booking->trip->title,
                                'departure_city' => $booking->trip->departure_city,
                                'arrival_city' => $booking->trip->arrival_city,
                            ],
                        ];
                    }),
                    'stats' => [
                        'trips_count' => $user->trips->count(),
                        'bookings_count' => $user->sentBookings->count() + $user->receivedBookings->count(),
                        'completed_trips' => $user->trips->where('status', Trip::STATUS_COMPLETED)->count(),
                        'completed_bookings' => $user->bookings->where('status', Booking::STATUS_COMPLETED)->count(),
                    ],
                ]
            ]);

        } catch (\Exception $e) {
            return Response::serverError('Failed to fetch user: ' . $e->getMessage());
        }
    }

    public function blockUser(ServerRequestInterface $request): ResponseInterface
    {
        $adminUser = $request->getAttribute('user');
        $userId = $request->getAttribute('id');
        
        if (!$adminUser->hasRole('admin')) {
            return Response::forbidden('Admin access required');
        }

        try {
            $user = User::find($userId);

            if (!$user) {
                return Response::notFound('User not found');
            }

            if ($user->hasRole('admin')) {
                return Response::error('Cannot block admin users');
            }

            $user->block();

            return Response::success([
                'user' => [
                    'id' => $user->id,
                    'status' => $user->status,
                ]
            ], 'User blocked successfully');

        } catch (\Exception $e) {
            return Response::serverError('Failed to block user: ' . $e->getMessage());
        }
    }

    public function unblockUser(ServerRequestInterface $request): ResponseInterface
    {
        $adminUser = $request->getAttribute('user');
        $userId = $request->getAttribute('id');
        
        if (!$adminUser->hasRole('admin')) {
            return Response::forbidden('Admin access required');
        }

        try {
            $user = User::find($userId);

            if (!$user) {
                return Response::notFound('User not found');
            }

            $user->unblock();

            return Response::success([
                'user' => [
                    'id' => $user->id,
                    'status' => $user->status,
                ]
            ], 'User unblocked successfully');

        } catch (\Exception $e) {
            return Response::serverError('Failed to unblock user: ' . $e->getMessage());
        }
    }

    public function verifyUser(ServerRequestInterface $request): ResponseInterface
    {
        $adminUser = $request->getAttribute('user');
        $userId = $request->getAttribute('id');
        
        if (!$adminUser->hasRole('admin')) {
            return Response::forbidden('Admin access required');
        }

        try {
            $user = User::find($userId);

            if (!$user) {
                return Response::notFound('User not found');
            }

            if (!$user->email_verified_at) {
                $user->markEmailAsVerified();
            }

            return Response::success([
                'user' => [
                    'id' => $user->id,
                    'is_verified' => $user->is_verified,
                    'email_verified_at' => $user->email_verified_at,
                ]
            ], 'User verified successfully');

        } catch (\Exception $e) {
            return Response::serverError('Failed to verify user: ' . $e->getMessage());
        }
    }

    private function getUserGrowthData(): array
    {
        // Retourner des données de croissance des utilisateurs sur les 30 derniers jours
        $data = [];
        for ($i = 29; $i >= 0; $i--) {
            $date = Carbon::now()->subDays($i);
            $count = User::whereDate('created_at', $date)->count();
            $data[] = [
                'date' => $date->format('Y-m-d'),
                'count' => $count,
            ];
        }
        return $data;
    }

    private function getTripGrowthData(): array
    {
        $data = [];
        for ($i = 29; $i >= 0; $i--) {
            $date = Carbon::now()->subDays($i);
            $count = Trip::whereDate('created_at', $date)->count();
            $data[] = [
                'date' => $date->format('Y-m-d'),
                'count' => $count,
            ];
        }
        return $data;
    }

    private function getBookingGrowthData(): array
    {
        $data = [];
        for ($i = 29; $i >= 0; $i--) {
            $date = Carbon::now()->subDays($i);
            $count = Booking::whereDate('created_at', $date)->count();
            $data[] = [
                'date' => $date->format('Y-m-d'),
                'count' => $count,
            ];
        }
        return $data;
    }

    private function getRevenueGrowthData(): array
    {
        // Simulé pour l'instant - à implémenter avec les vraies transactions
        $data = [];
        for ($i = 29; $i >= 0; $i--) {
            $date = Carbon::now()->subDays($i);
            $data[] = [
                'date' => $date->format('Y-m-d'),
                'amount' => rand(0, 1000), // Données simulées
            ];
        }
        return $data;
    }

    /**
     * Get trips pending approval
     */
    public function getPendingTrips(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');

        if (!$user->hasRole('admin')) {
            return Response::forbidden('Admin access required');
        }

        try {
            $trips = Trip::with(['user'])
                ->where('status', Trip::STATUS_PENDING_APPROVAL)
                ->orderBy('created_at', 'desc')
                ->get();

            $formattedTrips = [];
            foreach ($trips as $trip) {
                $formattedTrips[] = [
                    'id' => $trip->id,
                    'uuid' => $trip->uuid,
                    'transport_type' => $trip->transport_type,
                    'departure_city' => $trip->departure_city,
                    'departure_country' => $trip->departure_country,
                    'arrival_city' => $trip->arrival_city,
                    'arrival_country' => $trip->arrival_country,
                    'departure_date' => $trip->departure_date,
                    'available_weight_kg' => $trip->available_weight_kg,
                    'price_per_kg' => $trip->price_per_kg,
                    'currency' => $trip->currency,
                    'status' => $trip->status,
                    'description' => $trip->description,
                    'user' => [
                        'first_name' => $trip->user->first_name,
                        'last_name' => $trip->user->last_name,
                        'email' => $trip->user->email,
                        'trust_score' => $trip->user->trust_score ?? 0,
                        'total_trips' => Trip::where('user_id', $trip->user->id)->count(),
                    ],
                    'created_at' => $trip->created_at,
                    'updated_at' => $trip->updated_at,
                ];
            }

            return Response::success([
                'trips' => $formattedTrips,
                'total' => count($formattedTrips)
            ], 'Pending trips retrieved successfully');

        } catch (\Exception $e) {
            return Response::error('Failed to retrieve pending trips: ' . $e->getMessage());
        }
    }

    /**
     * Approve a trip
     */
    public function approveTrip(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');

        if (!$user->hasRole('admin')) {
            return Response::forbidden('Admin access required');
        }

        try {
            $data = json_decode($request->getBody()->getContents(), true);
            $tripId = $data['id'] ?? null;

            if (!$tripId) {
                return Response::badRequest('Trip ID is required');
            }

            $trip = Trip::find($tripId);
            if (!$trip) {
                return Response::notFound('Trip not found');
            }

            if ($trip->status !== Trip::STATUS_PENDING_APPROVAL) {
                return Response::badRequest('Trip is not pending approval');
            }

            $trip->status = Trip::STATUS_ACTIVE;
            $trip->approved_at = Carbon::now();
            $trip->approved_by = $user->id;
            $trip->save();

            return Response::success([
                'trip_id' => $trip->id,
                'status' => $trip->status
            ], 'Trip approved successfully');

        } catch (\Exception $e) {
            return Response::error('Failed to approve trip: ' . $e->getMessage());
        }
    }

    /**
     * Reject a trip
     */
    public function rejectTrip(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');

        if (!$user->hasRole('admin')) {
            return Response::forbidden('Admin access required');
        }

        try {
            $data = json_decode($request->getBody()->getContents(), true);
            $tripId = $data['id'] ?? null;
            $reason = $data['reason'] ?? 'No reason provided';

            if (!$tripId) {
                return Response::badRequest('Trip ID is required');
            }

            $trip = Trip::find($tripId);
            if (!$trip) {
                return Response::notFound('Trip not found');
            }

            if ($trip->status !== Trip::STATUS_PENDING_APPROVAL) {
                return Response::badRequest('Trip is not pending approval');
            }

            $trip->status = Trip::STATUS_REJECTED;
            $trip->rejection_reason = $reason;
            $trip->rejected_at = Carbon::now();
            $trip->rejected_by = $user->id;
            $trip->save();

            return Response::success([
                'trip_id' => $trip->id,
                'status' => $trip->status,
                'reason' => $reason
            ], 'Trip rejected successfully');

        } catch (\Exception $e) {
            return Response::error('Failed to reject trip: ' . $e->getMessage());
        }
    }

    /**
     * Get all trips with filters
     */
    public function getAllTrips(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');

        if (!$user->hasRole('admin')) {
            return Response::forbidden('Admin access required');
        }

        try {
            $queryParams = $request->getQueryParams();
            $status = $queryParams['status'] ?? null;
            $limit = (int)($queryParams['limit'] ?? 50);
            $offset = (int)($queryParams['offset'] ?? 0);

            $query = Trip::with(['user']);
            
            if ($status) {
                $query->where('status', $status);
            }

            $total = $query->count();
            $trips = $query->orderBy('created_at', 'desc')
                ->skip($offset)
                ->take($limit)
                ->get();

            $formattedTrips = [];
            foreach ($trips as $trip) {
                $formattedTrips[] = [
                    'id' => $trip->id,
                    'uuid' => $trip->uuid,
                    'transport_type' => $trip->transport_type,
                    'departure_city' => $trip->departure_city,
                    'departure_country' => $trip->departure_country,
                    'arrival_city' => $trip->arrival_city,
                    'arrival_country' => $trip->arrival_country,
                    'departure_date' => $trip->departure_date,
                    'available_weight_kg' => $trip->available_weight_kg,
                    'price_per_kg' => $trip->price_per_kg,
                    'currency' => $trip->currency,
                    'status' => $trip->status,
                    'user' => [
                        'first_name' => $trip->user->first_name,
                        'last_name' => $trip->user->last_name,
                        'email' => $trip->user->email,
                    ],
                    'created_at' => $trip->created_at,
                    'updated_at' => $trip->updated_at,
                ];
            }

            return Response::success([
                'trips' => $formattedTrips,
                'total' => $total,
                'limit' => $limit,
                'offset' => $offset
            ], 'Trips retrieved successfully');

        } catch (\Exception $e) {
            return Response::error('Failed to retrieve trips: ' . $e->getMessage());
        }
    }

    /**
     * Get payment statistics
     */
    public function getPaymentStats(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');

        if (!$user->hasRole('admin')) {
            return Response::forbidden('Admin access required');
        }

        try {
            // Pour l'instant, retourner des statistiques simulées
            // À implémenter avec les vraies données de paiement
            $stats = [
                'total_revenue' => 15250.75,
                'total_transactions' => 156,
                'pending_payments' => 23,
                'failed_payments' => 5,
                'commission_earned' => 762.54,
                'monthly_growth' => 15.5,
                'average_transaction' => 97.76,
                'successful_rate' => 96.8
            ];

            return Response::success([
                'stats' => $stats
            ], 'Payment stats retrieved successfully');

        } catch (\Exception $e) {
            return Response::serverError('Failed to retrieve payment stats: ' . $e->getMessage());
        }
    }

    /**
     * Get payment transactions
     */
    public function getPaymentTransactions(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');

        if (!$user->hasRole('admin')) {
            return Response::forbidden('Admin access required');
        }

        $queryParams = $request->getQueryParams();

        try {
            $page = (int) ($queryParams['page'] ?? 1);
            $limit = (int) ($queryParams['limit'] ?? 25);
            $offset = ($page - 1) * $limit;

            // Pour l'instant, retourner des données simulées
            // À implémenter avec les vraies données de paiement
            $transactions = [];
            $total = 156;

            for ($i = 0; $i < min($limit, $total - $offset); $i++) {
                $transactions[] = [
                    'id' => $offset + $i + 1,
                    'transaction_id' => 'TXN_' . str_pad((string)($offset + $i + 1), 6, '0', STR_PAD_LEFT),
                    'user_email' => 'user' . ($offset + $i + 1) . '@example.com',
                    'amount' => rand(2500, 15000) / 100,
                    'commission' => rand(125, 750) / 100,
                    'currency' => 'EUR',
                    'status' => ['completed', 'pending', 'failed'][rand(0, 2)],
                    'payment_method' => ['card', 'bank_transfer', 'paypal'][rand(0, 2)],
                    'created_at' => Carbon::now()->subDays(rand(0, 30))->format('Y-m-d H:i:s'),
                ];
            }

            return Response::success([
                'transactions' => $transactions,
                'pagination' => [
                    'current_page' => $page,
                    'per_page' => $limit,
                    'total' => $total,
                    'total_pages' => ceil($total / $limit),
                ]
            ], 'Payment transactions retrieved successfully');

        } catch (\Exception $e) {
            return Response::serverError('Failed to retrieve payment transactions: ' . $e->getMessage());
        }
    }

    /**
     * Get connected Stripe accounts
     */
    public function getConnectedAccounts(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');

        if (!$user->hasRole('admin')) {
            return Response::forbidden('Admin access required');
        }

        $queryParams = $request->getQueryParams();

        try {
            $page = (int) ($queryParams['page'] ?? 1);
            $limit = (int) ($queryParams['limit'] ?? 25);
            $status = $queryParams['status'] ?? '';

            // Pour l'instant, retourner des données simulées
            // À implémenter avec les vraies données Stripe
            $accounts = [];
            $total = 0;

            // Simuler quelques comptes connectés si nécessaire pour les tests
            if ($status === 'all' || empty($status)) {
                for ($i = 1; $i <= 5; $i++) {
                    $accounts[] = [
                        'id' => "acc_test_$i",
                        'user_id' => $i + 1,
                        'stripe_account_id' => "acct_1A2B3C4D5E6F$i",
                        'account_status' => ['active', 'pending', 'restricted'][rand(0, 2)],
                        'onboarding_complete' => rand(0, 1) === 1,
                        'country' => ['FR', 'GB', 'US', 'DE', 'ES'][rand(0, 4)],
                        'default_currency' => ['EUR', 'GBP', 'USD'][rand(0, 2)],
                        'email' => "user$i@example.com",
                        'business_type' => ['individual', 'company'][rand(0, 1)],
                        'created_at' => Carbon::now()->subDays(rand(1, 30))->format('Y-m-d H:i:s'),
                        'updated_at' => Carbon::now()->subDays(rand(0, 5))->format('Y-m-d H:i:s'),
                        'user' => [
                            'id' => $i + 1,
                            'first_name' => 'User',
                            'last_name' => (string)($i + 1),
                            'email' => "user$i@example.com"
                        ],
                        'balance' => [
                            'available' => rand(0, 50000) / 100,
                            'pending' => rand(0, 10000) / 100
                        ],
                        'requirements' => [
                            'currently_due' => [],
                            'eventually_due' => ['individual.id_number'],
                            'past_due' => [],
                            'pending_verification' => ['document']
                        ]
                    ];
                }
                $total = 5;
            }

            return Response::success([
                'accounts' => array_slice($accounts, ($page - 1) * $limit, $limit),
                'pagination' => [
                    'current_page' => $page,
                    'per_page' => $limit,
                    'total' => $total,
                    'total_pages' => ceil($total / $limit),
                ]
            ], 'Connected accounts retrieved successfully');

        } catch (\Exception $e) {
            return Response::serverError('Failed to retrieve connected accounts: ' . $e->getMessage());
        }
    }

    /**
     * Get connected accounts statistics
     */
    public function getConnectedAccountsStats(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');

        if (!$user->hasRole('admin')) {
            return Response::forbidden('Admin access required');
        }

        try {
            // Pour l'instant, retourner des statistiques simulées
            // À implémenter avec les vraies données Stripe
            $stats = [
                'total_accounts' => 5,
                'active_accounts' => 3,
                'pending_accounts' => 1,
                'restricted_accounts' => 1,
                'rejected_accounts' => 0,
                'onboarding_completion_rate' => 80.0,
                'total_balance_available' => 12500.75,
                'total_balance_pending' => 2300.50,
                'monthly_growth' => 12.5,
                'average_balance_per_account' => 2500.15,
                'accounts_with_requirements' => 2,
                'countries_represented' => 4
            ];

            return Response::success([
                'stats' => $stats
            ], 'Connected accounts stats retrieved successfully');

        } catch (\Exception $e) {
            return Response::serverError('Failed to retrieve connected accounts stats: ' . $e->getMessage());
        }
    }

    /**
     * Perform action on connected account
     */
    public function performAccountAction(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');

        if (!$user->hasRole('admin')) {
            return Response::forbidden('Admin access required');
        }

        $accountId = $request->getAttribute('id');
        $data = json_decode($request->getBody()->getContents(), true);

        try {
            // Pour l'instant, simuler les actions
            // À implémenter avec les vraies actions Stripe
            $action = $data['action'] ?? '';
            
            switch ($action) {
                case 'approve':
                case 'enable':
                    $message = "Account $accountId has been enabled successfully";
                    break;
                case 'restrict':
                case 'disable':
                    $message = "Account $accountId has been disabled successfully";
                    break;
                case 'reject':
                    $message = "Account $accountId has been rejected successfully";
                    break;
                case 'review':
                case 'request_info':
                    $message = "Account $accountId has been marked for review successfully";
                    break;
                default:
                    return Response::error('Invalid action', [], 400);
            }

            return Response::success([
                'account_id' => $accountId,
                'action' => $action,
                'status' => 'completed'
            ], $message);

        } catch (\Exception $e) {
            return Response::serverError('Failed to perform account action: ' . $e->getMessage());
        }
    }
}