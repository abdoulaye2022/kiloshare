<?php

declare(strict_types=1);

namespace KiloShare\Controllers;

use KiloShare\Models\User;
use KiloShare\Models\Trip;
use KiloShare\Models\Booking;
use KiloShare\Models\Transaction;
use KiloShare\Models\UserStripeAccount;
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
                    'currency' => $trip->currency ?: 'CAD',
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
            
            if ($status && $status !== 'all') {
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
                    'currency' => $trip->currency ?: 'CAD',
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
            // Calculer les vraies statistiques depuis la base de données
            $totalTransactions = Transaction::count();
            $completedTransactions = Transaction::completed()->count();
            $pendingTransactions = Transaction::pending()->count();
            $failedTransactions = Transaction::failed()->count();

            // Calculer le revenu total et les commissions avec 15%
            $completedTxs = Transaction::completed()->get();
            $totalRevenue = $completedTxs->sum('amount');
            $totalCommission = $completedTxs->sum('commission');
            
            // Si les commissions ne sont pas calculées dans la DB, les calculer à 15%
            if ($totalCommission == 0 && $totalRevenue > 0) {
                $totalCommission = $totalRevenue * 0.15; // 15% commission
            }

            $averageTransaction = $completedTransactions > 0 ? $totalRevenue / $completedTransactions : 0;
            $successRate = $totalTransactions > 0 ? ($completedTransactions / $totalTransactions) * 100 : 0;

            // Calculer la croissance mensuelle (dernier mois vs avant-dernier mois)
            $thisMonth = Carbon::now()->startOfMonth();
            $lastMonth = Carbon::now()->subMonth()->startOfMonth();
            
            $thisMonthRevenue = Transaction::completed()
                ->where('created_at', '>=', $thisMonth)
                ->sum('amount');
                
            $lastMonthRevenue = Transaction::completed()
                ->where('created_at', '>=', $lastMonth)
                ->where('created_at', '<', $thisMonth)
                ->sum('amount');
                
            $monthlyGrowth = $lastMonthRevenue > 0 ? 
                (($thisMonthRevenue - $lastMonthRevenue) / $lastMonthRevenue) * 100 : 0;

            $stats = [
                'total_revenue' => (float) $totalRevenue,
                'total_commission' => (float) $totalCommission,
                'total_transactions' => $totalTransactions,
                'pending_count' => $pendingTransactions,
                'failed_count' => $failedTransactions,
                'completed_count' => $completedTransactions,
                'monthly_growth' => round($monthlyGrowth, 1),
                'average_transaction' => round($averageTransaction, 2),
                'success_rate' => round($successRate, 1)
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
            $limit = (int) ($queryParams['limit'] ?? 50);
            $status = $queryParams['status'] ?? 'all';
            $type = $queryParams['type'] ?? 'all';
            $offset = ($page - 1) * $limit;

            // Récupérer les transactions avec les relations et filtrer par utilisateurs actifs
            $query = Transaction::with(['booking.sender', 'booking.receiver', 'booking.trip'])
                ->whereHas('booking.sender', function($q) {
                    $q->where('status', 'active');
                })
                ->orWhereHas('booking.receiver', function($q) {
                    $q->where('status', 'active');
                });
            
            if ($status !== 'all') {
                $query->where('status', $status);
            }
            
            $total = $query->count();
            $transactions = $query->skip($offset)->take($limit)->get();

            $formattedTransactions = $transactions->map(function ($transaction) {
                $sender = $transaction->booking->sender ?? null;
                $receiver = $transaction->booking->receiver ?? null;
                $trip = $transaction->booking->trip ?? null;

                return [
                    'id' => $transaction->id,
                    'stripe_transaction_id' => $transaction->stripe_payment_intent_id ?? $transaction->uuid,
                    'user_id' => $sender->id ?? null,
                    'trip_id' => $trip->id ?? null,
                    'booking_id' => $transaction->booking_id,
                    'amount' => (float) $transaction->amount,
                    'currency' => $transaction->currency ?: 'CAD', // Par défaut CAD si pas de devise
                    'type' => 'payment', // Toutes les transactions sont des paiements dans votre système
                    'status' => $transaction->status,
                    'failure_reason' => null, // Ajoutez ce champ à votre DB si nécessaire
                    'stripe_fee' => $transaction->stripe_fees,
                    'net_amount' => $transaction->net_amount,
                    'created_at' => $transaction->created_at->toISOString(),
                    'updated_at' => $transaction->updated_at->toISOString(),
                    'user' => $sender ? [
                        'id' => $sender->id,
                        'first_name' => $sender->first_name,
                        'last_name' => $sender->last_name,
                        'email' => $sender->email,
                    ] : null,
                    'trip' => $trip ? [
                        'id' => $trip->id,
                        'departure_city' => $trip->departure_city,
                        'arrival_city' => $trip->arrival_city,
                    ] : null,
                ];
            });

            return Response::success([
                'transactions' => $formattedTransactions,
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

            $offset = ($page - 1) * $limit;

            // Utiliser PDO directement pour accéder aux données
            $host = '127.0.0.1';
            $port = '3306';
            $db = 'kiloshare';
            $user = 'root';
            $pass = '';
            $dsn = "mysql:host=$host;port=$port;dbname=$db;charset=utf8mb4";
            $pdo = new \PDO($dsn, $user, $pass, [
                \PDO::ATTR_ERRMODE => \PDO::ERRMODE_EXCEPTION,
                \PDO::ATTR_DEFAULT_FETCH_MODE => \PDO::FETCH_ASSOC,
            ]);

            // Construire la requête SQL avec jointure sur la table users
            $sql = "SELECT 
                        usa.id,
                        usa.user_id,
                        usa.stripe_account_id,
                        usa.status as account_status,
                        usa.details_submitted as onboarding_complete,
                        usa.charges_enabled,
                        usa.payouts_enabled,
                        usa.onboarding_url,
                        usa.requirements,
                        usa.created_at,
                        usa.updated_at,
                        u.first_name,
                        u.last_name,
                        u.email
                    FROM user_stripe_accounts usa
                    LEFT JOIN users u ON usa.user_id = u.id";
            
            $params = [];
            
            if ($status && $status !== 'all') {
                $sql .= " WHERE usa.status = ?";
                $params[] = $status;
            }
            
            $sql .= " ORDER BY usa.created_at DESC LIMIT $limit OFFSET $offset";

            $stmt = $pdo->prepare($sql);
            $stmt->execute($params);
            $results = $stmt->fetchAll(\PDO::FETCH_ASSOC);

            // Compter le total
            $countSql = "SELECT COUNT(*) as total FROM user_stripe_accounts usa";
            if ($status && $status !== 'all') {
                $countSql .= " WHERE usa.status = ?";
                $countStmt = $pdo->prepare($countSql);
                $countStmt->execute([$status]);
            } else {
                $countStmt = $pdo->query($countSql);
            }
            $total = $countStmt->fetch(\PDO::FETCH_ASSOC)['total'];

            // Formater les données
            $accounts = [];
            foreach ($results as $row) {
                $requirements = json_decode($row['requirements'] ?? '{}', true);
                
                $accounts[] = [
                    'id' => $row['stripe_account_id'], // Utiliser stripe_account_id comme ID externe
                    'user_id' => (int) $row['user_id'],
                    'stripe_account_id' => $row['stripe_account_id'],
                    'account_status' => $row['account_status'],
                    'onboarding_complete' => (bool) $row['onboarding_complete'],
                    'capabilities' => [
                        'card_payments' => $row['charges_enabled'] ? 'active' : 'inactive',
                        'transfers' => $row['payouts_enabled'] ? 'active' : 'inactive'
                    ],
                    'country' => 'CA', // Tous les comptes sont au Canada
                    'default_currency' => 'CAD', // Devise canadienne par défaut
                    'email' => $row['email'],
                    'business_type' => 'individual', // Type par défaut
                    'created_at' => $row['created_at'],
                    'updated_at' => $row['updated_at'],
                    'user' => [
                        'id' => (int) $row['user_id'],
                        'first_name' => $row['first_name'],
                        'last_name' => $row['last_name'],
                        'email' => $row['email']
                    ],
                    'balance' => [
                        'available' => rand(0, 5000) / 100, // Montants fictifs en CAD pour les tests
                        'pending' => rand(0, 1000) / 100
                    ],
                    'requirements' => $requirements,
                    'onboarding_url' => $row['onboarding_url']
                ];
            }

            return Response::success([
                'data' => [
                    'accounts' => $accounts
                ],
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
            // Utiliser PDO directement pour accéder aux données
            $host = '127.0.0.1';
            $port = '3306';
            $db = 'kiloshare';
            $user = 'root';
            $pass = '';
            $dsn = "mysql:host=$host;port=$port;dbname=$db;charset=utf8mb4";
            $pdo = new \PDO($dsn, $user, $pass, [
                \PDO::ATTR_ERRMODE => \PDO::ERRMODE_EXCEPTION,
                \PDO::ATTR_DEFAULT_FETCH_MODE => \PDO::FETCH_ASSOC,
            ]);
            
            // Récupérer les statistiques réelles depuis la base de données
            $totalAccountsStmt = $pdo->query("SELECT COUNT(*) as total FROM user_stripe_accounts");
            $totalAccounts = $totalAccountsStmt->fetch(\PDO::FETCH_ASSOC)['total'];
            
            $statusStatsStmt = $pdo->query("
                SELECT 
                    status,
                    COUNT(*) as count
                FROM user_stripe_accounts 
                GROUP BY status
            ");
            $statusStats = [];
            while ($row = $statusStatsStmt->fetch(\PDO::FETCH_ASSOC)) {
                $statusStats[$row['status']] = $row['count'];
            }
            
            // Calculer les statistiques
            $activeCount = $statusStats['active'] ?? 0;
            $pendingCount = $statusStats['pending'] ?? 0;
            $restrictedCount = $statusStats['restricted'] ?? 0;
            $rejectedCount = $statusStats['rejected'] ?? 0;
            $onboardingCount = $statusStats['onboarding'] ?? 0;
            
            $completionRate = $totalAccounts > 0 ? 
                round((($activeCount + $restrictedCount) / $totalAccounts) * 100, 1) : 0;
            
            // Compter les comptes avec des requirements
            $requirementsStmt = $pdo->query("
                SELECT COUNT(*) as count 
                FROM user_stripe_accounts 
                WHERE requirements IS NOT NULL 
                AND JSON_LENGTH(JSON_EXTRACT(requirements, '$.currently_due')) > 0
            ");
            $accountsWithRequirements = $requirementsStmt->fetch(\PDO::FETCH_ASSOC)['count'];
            
            $stats = [
                'active_count' => (int) $activeCount,
                'pending_count' => (int) ($pendingCount + $onboardingCount),
                'restricted_count' => (int) $restrictedCount,
                'rejected_count' => (int) $rejectedCount,
                'total_count' => (int) $totalAccounts,
                'total_balance' => rand(10000, 50000) / 100, // Montant fictif en CAD pour les tests
                'onboarding_completion_rate' => $completionRate,
                'accounts_with_requirements' => (int) $accountsWithRequirements,
                'countries_represented' => 1, // Tous au Canada pour l'instant
                'total_revenue_this_month' => rand(5000, 15000) / 100, // Fictif en CAD
                'average_balance_per_account' => $totalAccounts > 0 ? 
                    rand(1000, 8000) / 100 : 0 // Fictif en CAD
            ];

            return Response::success([
                'data' => [
                    'stats' => $stats
                ]
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

    /**
     * Get platform analytics
     */
    public function getPlatformAnalytics(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');

        if (!$user->hasRole('admin')) {
            return Response::forbidden('Admin access required');
        }

        try {
            // Simulation des analytics de plateforme
            $analytics = [
                'daily_transactions' => rand(50, 150),
                'monthly_transactions' => rand(800, 1500),
                'total_volume' => rand(15000, 50000),
                'avg_transaction_value' => rand(50, 200),
                'active_users' => rand(200, 800),
                'new_users' => rand(10, 50),
                'connected_accounts' => rand(25, 100),
                'conversion_rate' => rand(15, 35),
                'success_rate' => rand(85, 98),
                'failure_rate' => rand(2, 15),
                'refunds_count' => rand(5, 25),
                'stripe_fees' => rand(500, 2000),
                'daily_trend' => [
                    'volume' => rand(1000, 5000),
                    'volume_change' => rand(-10, 25),
                    'transactions' => rand(20, 80),
                    'transactions_change' => rand(-5, 15),
                ]
            ];

            return Response::success([
                'analytics' => $analytics
            ]);

        } catch (\Exception $e) {
            return Response::serverError('Failed to get platform analytics: ' . $e->getMessage());
        }
    }

    /**
     * Get platform metrics
     */
    public function getPlatformMetrics(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');

        if (!$user->hasRole('admin')) {
            return Response::forbidden('Admin access required');
        }

        try {
            $today = Carbon::today();
            $thisMonth = Carbon::now()->startOfMonth();

            // Calculer les métriques réelles
            $totalUsers = User::count();
            $activeUsers = User::where('last_login_at', '>=', Carbon::now()->subDays(30))->count();
            $totalTrips = Trip::count();
            $completedTrips = Trip::where('status', Trip::STATUS_COMPLETED)->count();
            $totalBookings = Booking::count();

            // Calculer les données financières réelles avec 15% de commission
            $completedTxs = Transaction::completed()->get();
            $totalRevenue = $completedTxs->sum('amount');
            $totalCommission = $completedTxs->sum('commission');
            
            // Si les commissions ne sont pas dans la DB, les calculer à 15%
            if ($totalCommission == 0 && $totalRevenue > 0) {
                $totalCommission = $totalRevenue * 0.15; // 15% commission
            }
            
            $stripeFees = $completedTxs->sum(function($tx) {
                return ($tx->amount * 0.029) + 0.30; // 2.9% + 0.30€
            });
            $netRevenue = $totalRevenue - $stripeFees;

            $metrics = [
                'total_users' => $totalUsers,
                'active_users' => $activeUsers,
                'total_trips' => $totalTrips,
                'completed_trips' => $completedTrips,
                'total_bookings' => $totalBookings,
                'total_revenue' => $totalRevenue,
                'total_commission' => $totalCommission,
                'commission_rate' => 15.0,
                'connected_accounts' => rand(20, 80),
                'active_connected_accounts' => rand(15, 60),
                'pending_transfers' => rand(0, 10),
                'stripe_fees' => $stripeFees,
                'net_revenue' => $netRevenue,
                'monthly_growth' => rand(-5, 25),
                'conversion_rate' => rand(15, 35),
            ];

            return Response::success([
                'metrics' => $metrics
            ]);

        } catch (\Exception $e) {
            return Response::serverError('Failed to get platform metrics: ' . $e->getMessage());
        }
    }

    /**
     * Get platform trends
     */
    public function getPlatformTrends(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');

        if (!$user->hasRole('admin')) {
            return Response::forbidden('Admin access required');
        }

        try {
            $queryParams = $request->getQueryParams();
            $timeframe = $queryParams['timeframe'] ?? 'daily';

            $trends = [];

            switch ($timeframe) {
                case 'daily':
                    // Derniers 7 jours
                    for ($i = 6; $i >= 0; $i--) {
                        $date = Carbon::now()->subDays($i);
                        $trends['daily'][] = [
                            'date' => $date->format('Y-m-d'),
                            'revenue' => rand(1000, 8000),
                            'transactions' => rand(10, 80),
                            'users' => rand(50, 200),
                        ];
                    }
                    break;

                case 'weekly':
                    // Dernières 4 semaines
                    for ($i = 3; $i >= 0; $i--) {
                        $startWeek = Carbon::now()->subWeeks($i)->startOfWeek();
                        $trends['weekly'][] = [
                            'week' => $startWeek->format('d/m') . ' - ' . $startWeek->endOfWeek()->format('d/m'),
                            'revenue' => rand(15000, 40000),
                            'transactions' => rand(200, 500),
                            'users' => rand(300, 800),
                        ];
                    }
                    break;

                case 'monthly':
                    // Derniers 12 mois
                    for ($i = 11; $i >= 0; $i--) {
                        $month = Carbon::now()->subMonths($i);
                        $trends['monthly'][] = [
                            'month' => $month->format('M Y'),
                            'revenue' => rand(50000, 120000),
                            'transactions' => rand(800, 2000),
                            'users' => rand(1000, 3000),
                        ];
                    }
                    break;
            }

            return Response::success([
                'trends' => $trends
            ]);

        } catch (\Exception $e) {
            return Response::serverError('Failed to get platform trends: ' . $e->getMessage());
        }
    }

    /**
     * Get commission statistics
     */
    public function getCommissionStats(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');

        if (!$user->hasRole('admin')) {
            return Response::forbidden('Admin access required');
        }

        try {
            $thisMonth = Carbon::now()->startOfMonth();
            
            // Calculer les vraies statistiques de commission à 15%
            $completedTxs = Transaction::completed()->get();
            $totalCommission = $completedTxs->sum('commission');
            
            // Si pas de commissions dans la DB, les calculer à 15%
            if ($totalCommission == 0) {
                $totalRevenue = $completedTxs->sum('amount');
                $totalCommission = $totalRevenue * 0.15;
            }
            
            $monthlyCommission = Transaction::completed()
                ->where('created_at', '>=', $thisMonth)
                ->sum('commission');
                
            if ($monthlyCommission == 0) {
                $monthlyRevenue = Transaction::completed()
                    ->where('created_at', '>=', $thisMonth)
                    ->sum('amount');
                $monthlyCommission = $monthlyRevenue * 0.15;
            }
            
            $commissionRate = 15.0; // 15%
            $commissionTransactions = Transaction::completed()->count();

            $stats = [
                'total_commission' => $totalCommission,
                'monthly_commission' => $monthlyCommission,
                'commission_rate' => $commissionRate,
                'commission_transactions' => $commissionTransactions,
            ];

            return Response::success([
                'stats' => $stats
            ]);

        } catch (\Exception $e) {
            return Response::serverError('Failed to get commission stats: ' . $e->getMessage());
        }
    }

    /**
     * Get pending transfers
     */
    public function getPendingTransfers(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');

        if (!$user->hasRole('admin')) {
            return Response::forbidden('Admin access required');
        }

        try {
            // Récupérer toutes les transactions complétées avec les données réelles
            $transactions = Transaction::with(['booking.trip.user', 'booking.user'])
                ->where('status', 'completed')
                ->orderBy('created_at', 'desc')
                ->get();

            $transfers = [];
            $userStripeAccounts = [];
            
            // Charger les comptes Stripe des utilisateurs
            $stripeAccounts = UserStripeAccount::where('status', 'active')->get();
            foreach ($stripeAccounts as $account) {
                $userStripeAccounts[$account->user_id] = $account;
            }
            
            foreach ($transactions as $transaction) {
                // Calculer les heures depuis la création de la transaction (simulant la livraison)
                $hourseSinceDelivery = $transaction->created_at 
                    ? Carbon::parse($transaction->created_at)->diffInHours(Carbon::now())
                    : rand(1, 72); // Simulation pour les données existantes

                // Calculer la commission (15% du montant total)
                $amount = $transaction->amount;
                $commission = $amount * 0.15; // 15% commission
                $transferAmount = $amount - $commission;

                // Déterminer le statut du transfert (toutes les transactions anciennes sont éligibles)
                $transferStatus = isset($transaction->transfer_status) ? $transaction->transfer_status : 'pending';
                if ($transferStatus === 'pending' && $hourseSinceDelivery >= 24) {
                    $status = 'ready';
                } else {
                    $status = $hourseSinceDelivery >= 24 ? 'ready' : 'pending';
                }

                // Obtenir les informations utilisateur (simuler les relations si elles n'existent pas)
                $booking = $transaction->booking;
                if ($booking && $booking->trip && $booking->trip->user) {
                    $transporter = $booking->trip->user;
                    $trip = $booking->trip;
                    $customer = $booking->user;
                } else {
                    // Simuler des données si les relations n'existent pas
                    $transporter = User::inRandomOrder()->first();
                    $customer = User::where('id', '!=', $transporter->id ?? 1)->inRandomOrder()->first();
                    
                    if (!$transporter || !$customer) {
                        continue; // Skip si pas d'utilisateurs disponibles
                    }
                    
                    $trip = (object)[
                        'id' => $transaction->id,
                        'departure_city' => 'Montréal',
                        'arrival_city' => 'Toronto',
                        'departure_date' => $transaction->created_at,
                    ];
                }

                // Trouver le compte Stripe du transporteur
                $stripeAccountId = isset($userStripeAccounts[$transporter->id]) 
                    ? $userStripeAccounts[$transporter->id]->stripe_account_id 
                    : null;

                $transfers[] = [
                    'id' => "transfer_" . $transaction->id,
                    'transaction_id' => $transaction->id,
                    'amount' => round($transferAmount, 2), // Montant à transférer (sans commission)
                    'total_amount' => round($amount, 2), // Montant total de la transaction
                    'currency' => 'CAD', // Dollars canadiens
                    'commission' => round($commission, 2),
                    'status' => $status,
                    'hours_since_delivery' => $hourseSinceDelivery,
                    'stripe_account_id' => $stripeAccountId,
                    'trip' => [
                        'id' => is_object($trip) ? $trip->id : ($trip['id'] ?? $transaction->id),
                        'departure_city' => is_object($trip) ? ($trip->departure_city ?? 'Montréal') : ($trip['departure_city'] ?? 'Montréal'),
                        'arrival_city' => is_object($trip) ? ($trip->arrival_city ?? 'Toronto') : ($trip['arrival_city'] ?? 'Toronto'),
                        'departure_date' => is_object($trip) ? ($trip->departure_date ?? $transaction->created_at) : ($trip['departure_date'] ?? $transaction->created_at),
                    ],
                    'transporter' => [
                        'id' => $transporter->id,
                        'first_name' => $transporter->first_name ?? 'Transporteur',
                        'last_name' => $transporter->last_name ?? 'Test',
                        'email' => $transporter->email,
                        'stripe_account_id' => $stripeAccountId,
                    ],
                    'customer' => [
                        'id' => $customer->id,
                        'first_name' => $customer->first_name ?? 'Client',
                        'last_name' => $customer->last_name ?? 'Test',
                        'email' => $customer->email,
                    ],
                    'created_at' => $transaction->created_at,
                    'updated_at' => $transaction->updated_at,
                ];
            }

            return Response::success([
                'transfers' => $transfers,
                'total_transfers' => count($transfers),
                'ready_transfers' => count(array_filter($transfers, fn($t) => $t['status'] === 'ready')),
                'pending_transfers' => count(array_filter($transfers, fn($t) => $t['status'] === 'pending')),
            ]);

        } catch (\Exception $e) {
            error_log("Error in getPendingTransfers: " . $e->getMessage());
            error_log("Stack trace: " . $e->getTraceAsString());
            return Response::serverError('Failed to get pending transfers: ' . $e->getMessage());
        }
    }

    /**
     * Approve transfer
     */
    public function approveTransfer(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');

        if (!$user->hasRole('admin')) {
            return Response::forbidden('Admin access required');
        }

        $transferId = $request->getAttribute('id');

        try {
            // Simulation de l'approbation du transfert
            // À implémenter avec la vraie logique Stripe Transfer

            return Response::success([
                'transfer_id' => $transferId,
                'status' => 'approved',
                'processed_at' => Carbon::now()->toISOString(),
            ], 'Transfer approved successfully');

        } catch (\Exception $e) {
            return Response::serverError('Failed to approve transfer: ' . $e->getMessage());
        }
    }

    /**
     * Reject transfer
     */
    public function rejectTransfer(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');

        if (!$user->hasRole('admin')) {
            return Response::forbidden('Admin access required');
        }

        $transferId = $request->getAttribute('id');

        try {
            // Simulation du rejet du transfert
            return Response::success([
                'transfer_id' => $transferId,
                'status' => 'rejected',
                'processed_at' => Carbon::now()->toISOString(),
            ], 'Transfer rejected successfully');

        } catch (\Exception $e) {
            return Response::serverError('Failed to reject transfer: ' . $e->getMessage());
        }
    }

    /**
     * Force transfer (after 24h)
     */
    public function forceTransfer(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');

        if (!$user->hasRole('admin')) {
            return Response::forbidden('Admin access required');
        }

        $transferId = $request->getAttribute('id');

        try {
            // Simulation du transfert forcé après 24h
            // À implémenter avec la vraie logique Stripe Transfer

            return Response::success([
                'transfer_id' => $transferId,
                'status' => 'forced',
                'processed_at' => Carbon::now()->toISOString(),
            ], 'Transfer forced successfully (24h rule applied)');

        } catch (\Exception $e) {
            return Response::serverError('Failed to force transfer: ' . $e->getMessage());
        }
    }
}