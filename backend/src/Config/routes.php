<?php

declare(strict_types=1);

use Slim\App;
use Slim\Routing\RouteCollectorProxy;
use KiloShare\Controllers\AuthController;
use KiloShare\Controllers\SocialAuthController;
use KiloShare\Controllers\PhoneAuthController;
use KiloShare\Controllers\TestController;
use App\Modules\Profile\Controllers\ProfileController;
use App\Modules\Trips\Controllers\TripController;
use KiloShare\Middleware\AuthMiddleware;
use KiloShare\Middleware\OptionalAuthMiddleware;
use KiloShare\Middleware\AdminAuthMiddleware;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

return function (App $app) {
    // Health check endpoint
    $app->get('/', function (Request $request, Response $response) {
        $response->getBody()->write(json_encode([
            'success' => true,
            'message' => 'KiloShare API is running',
            'version' => '1.0.0',
            'timestamp' => date('Y-m-d H:i:s')
        ]));
        return $response->withHeader('Content-Type', 'application/json');
    });

    // Reset password web page
    $app->get('/reset-password', function (Request $request, Response $response) {
        $token = $request->getQueryParams()['token'] ?? '';
        
        $html = '<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Réinitialiser votre mot de passe - KiloShare</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script>
        tailwind.config = {
            theme: {
                extend: {
                    colors: {
                        primary: "#4096FF",
                        secondary: "#0070F3",
                    }
                }
            }
        }
    </script>
    <style>
        @import url("https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap");
        body { font-family: "Inter", system-ui, -apple-system, sans-serif; }
        .gradient-text {
            background: linear-gradient(135deg, #4096FF 0%, #0070F3 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
        }
        .hero-gradient {
            background: linear-gradient(135deg, #4096FF 0%, #0070F3 100%);
        }
        .loading {
            display: inline-block;
            width: 20px;
            height: 20px;
            border: 3px solid #ffffff;
            border-radius: 50%;
            border-top-color: transparent;
            animation: spin 1s ease-in-out infinite;
            margin-right: 8px;
        }
        @keyframes spin { to { transform: rotate(360deg); } }
    </style>
</head>
<body>
    <div class="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 flex items-center justify-center p-4">
        <div class="bg-white rounded-lg shadow-xl p-8 w-full max-w-md">
            <!-- Header -->
            <div class="text-center mb-8">
                <div class="flex items-center justify-center space-x-2 mb-4">
                    <svg class="h-8 w-8 text-primary" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"/>
                    </svg>
                    <h1 class="text-2xl font-bold gradient-text">KiloShare</h1>
                </div>
                <h2 class="text-lg text-gray-600">Réinitialisation du mot de passe</h2>
            </div>
            
            <!-- Content Container -->
            <div id="contentContainer">
                <!-- Loading State -->
                <div id="loadingState" class="text-center">
                    <div class="bg-blue-100 p-4 rounded-full w-20 h-20 flex items-center justify-center mx-auto mb-6">
                        <div class="loading"></div>
                    </div>
                    <h2 class="text-2xl font-bold text-gray-900 mb-4">Validation du lien...</h2>
                    <p class="text-gray-600">Nous vérifions votre lien de réinitialisation, veuillez patienter.</p>
                </div>
                
                <!-- Reset Form State -->
                <div id="resetFormState" class="text-center" style="display: none;">
                    <div class="bg-green-100 p-4 rounded-full w-20 h-20 flex items-center justify-center mx-auto mb-6">
                        <svg class="h-10 w-10 text-green-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"/>
                        </svg>
                    </div>
                    <h2 class="text-2xl font-bold text-gray-900 mb-4">Nouveau mot de passe</h2>
                    <p class="text-gray-600 mb-6">Choisissez un nouveau mot de passe sécurisé pour votre compte.</p>
                    
                    <form id="resetForm" class="space-y-4">
                        <div class="text-left">
                            <label for="password" class="block text-sm font-medium text-gray-700 mb-2">Nouveau mot de passe</label>
                            <input type="password" id="password" name="password" required minlength="6" 
                                   placeholder="Au moins 6 caractères" 
                                   class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary focus:border-transparent transition-colors">
                        </div>
                        
                        <div class="text-left">
                            <label for="confirmPassword" class="block text-sm font-medium text-gray-700 mb-2">Confirmer le mot de passe</label>
                            <input type="password" id="confirmPassword" name="confirmPassword" required 
                                   placeholder="Répéter le mot de passe" 
                                   class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary focus:border-transparent transition-colors">
                        </div>
                        
                        <button type="submit" id="submitBtn" 
                                class="hero-gradient text-white px-6 py-3 rounded-lg font-semibold hover:shadow-lg transform hover:scale-105 transition-all duration-200 flex items-center justify-center space-x-2 w-full">
                            <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"/>
                            </svg>
                            <span>Réinitialiser le mot de passe</span>
                        </button>
                    </form>
                </div>
                
                <!-- Success State -->
                <div id="successState" class="text-center" style="display: none;">
                    <div class="bg-green-100 p-4 rounded-full w-20 h-20 flex items-center justify-center mx-auto mb-6">
                        <svg class="h-10 w-10 text-green-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
                        </svg>
                    </div>
                    <h2 class="text-2xl font-bold text-gray-900 mb-4">Mot de passe réinitialisé !</h2>
                    <p class="text-gray-600 mb-6">Félicitations ! Votre mot de passe a été mis à jour avec succès. Vous pouvez maintenant vous connecter avec votre nouveau mot de passe.</p>
                    
                    <div class="space-y-4">
                        <button onclick="openApp()" class="hero-gradient text-white px-6 py-3 rounded-lg font-semibold hover:shadow-lg transform hover:scale-105 transition-all duration-200 flex items-center justify-center space-x-2 w-full">
                            <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 18h.01M8 21h8a2 2 0 002-2V5a2 2 0 00-2-2H8a2 2 0 00-2 2v14a2 2 0 002 2z"/>
                            </svg>
                            <span>Ouvrir l\'application mobile</span>
                        </button>
                        
                        <p class="text-sm text-gray-500">ou</p>
                        
                        <a href="/" class="inline-flex items-center space-x-2 text-primary hover:text-secondary transition-colors">
                            <span>Retour à l\'accueil</span>
                            <svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
                            </svg>
                        </a>
                    </div>
                </div>
                
                <!-- Error State -->
                <div id="errorState" class="text-center" style="display: none;">
                    <div class="bg-red-100 p-4 rounded-full w-20 h-20 flex items-center justify-center mx-auto mb-6">
                        <svg class="h-10 w-10 text-red-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.082 16.5c-.77.833.192 2.5 1.732 2.5z"/>
                        </svg>
                    </div>
                    <h2 class="text-2xl font-bold text-gray-900 mb-4">Erreur de réinitialisation</h2>
                    <p id="errorMessage" class="text-gray-600 mb-6">Une erreur est survenue lors de la réinitialisation de votre mot de passe.</p>
                    
                    <div class="space-y-4">
                        <button onclick="location.reload()" class="bg-primary text-white px-6 py-3 rounded-lg font-semibold hover:bg-secondary transition-colors flex items-center justify-center space-x-2 w-full">
                            <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
                            </svg>
                            <span>Réessayer</span>
                        </button>
                        
                        <p class="text-sm text-gray-500">ou</p>
                        
                        <a href="/" class="inline-flex items-center space-x-2 text-primary hover:text-secondary transition-colors">
                            <span>Retour à l\'accueil</span>
                            <svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
                            </svg>
                        </a>
                    </div>
                </div>
            </div>
            
            <!-- Footer -->
            <div class="mt-8 pt-6 border-t border-gray-200">
                <p class="text-xs text-gray-500 text-center">
                    Besoin d\'aide ? 
                    <a href="mailto:support@kiloshare.com" class="text-primary hover:underline">
                        Contactez notre support
                    </a>
                </p>
            </div>
        </div>
    </div>
    
    <script>
        const API_BASE_URL = window.location.origin + "/api/v1";
        const token = "' . htmlspecialchars($token) . '";
        
        function showState(stateName) {
            const states = ["loadingState", "resetFormState", "successState", "errorState"];
            states.forEach(state => {
                document.getElementById(state).style.display = state === stateName ? "block" : "none";
            });
        }
        
        function init() {
            if (!token) {
                document.getElementById("errorMessage").textContent = "Ce lien de réinitialisation n\'est pas valide. Veuillez utiliser le lien complet reçu dans votre email.";
                showState("errorState");
                return;
            }
            
            // Simulate token validation (in reality, you might want to validate on server)
            setTimeout(() => {
                showState("resetFormState");
            }, 1000);
        }
        
        document.getElementById("resetForm").addEventListener("submit", async (e) => {
            e.preventDefault();
            
            const password = document.getElementById("password").value;
            const confirmPassword = document.getElementById("confirmPassword").value;
            const submitBtn = document.getElementById("submitBtn");
            
            if (password !== confirmPassword) {
                alert("Les mots de passe ne correspondent pas.");
                return;
            }
            
            if (password.length < 6) {
                alert("Le mot de passe doit contenir au moins 6 caractères.");
                return;
            }
            
            submitBtn.disabled = true;
            submitBtn.innerHTML = `<span class="loading"></span>Réinitialisation en cours...`;
            
            try {
                const response = await fetch(`${API_BASE_URL}/auth/reset-password`, {
                    method: "POST",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({ token: token, password: password })
                });
                
                const data = await response.json();
                
                if (data.success) {
                    showState("successState");
                } else {
                    document.getElementById("errorMessage").textContent = data.message || "Une erreur est survenue lors de la réinitialisation.";
                    showState("errorState");
                }
            } catch (error) {
                document.getElementById("errorMessage").textContent = "Erreur de connexion. Impossible de contacter le serveur.";
                showState("errorState");
            } finally {
                submitBtn.disabled = false;
                submitBtn.innerHTML = `<svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"/>
                </svg>
                <span>Réinitialiser le mot de passe</span>`;
            }
        });
        
        function openApp() {
            const appScheme = "kiloshare://login";
            
            const iframe = document.createElement("iframe");
            iframe.style.display = "none";
            iframe.src = appScheme;
            document.body.appendChild(iframe);
            
            setTimeout(() => {
                alert("Si l\'app ne s\'ouvre pas automatiquement, lancez KiloShare manuellement et connectez-vous avec votre nouveau mot de passe.");
                document.body.removeChild(iframe);
            }, 2000);
        }
        
        init();
    </script>
</body>
</html>';
        
        $response->getBody()->write($html);
        return $response->withHeader('Content-Type', 'text/html');
    });

    // API routes group
    $app->group('/api', function (RouteCollectorProxy $group) {
        
        // Auth routes group
        $group->group('/auth', function (RouteCollectorProxy $authGroup) {
            $authGroup->post('/register', [AuthController::class, 'register']);
            $authGroup->post('/login', [AuthController::class, 'login']);
            $authGroup->post('/refresh', [AuthController::class, 'refresh']);
            $authGroup->post('/forgot-password', [AuthController::class, 'forgotPassword']);
            $authGroup->post('/reset-password', [AuthController::class, 'resetPassword']);
            $authGroup->post('/verify-email', [AuthController::class, 'verifyEmail']);
            $authGroup->post('/resend-verification', [AuthController::class, 'resendEmailVerification']);
            
            // Protected auth routes
            $authGroup->post('/logout', [AuthController::class, 'logout'])
                ->add(AuthMiddleware::class);
            $authGroup->get('/me', [AuthController::class, 'me'])
                ->add(AuthMiddleware::class);
            $authGroup->put('/profile', [AuthController::class, 'updateProfile'])
                ->add(AuthMiddleware::class);
            $authGroup->post('/verify-phone', [AuthController::class, 'verifyPhone'])
                ->add(AuthMiddleware::class);
            $authGroup->post('/change-password', [AuthController::class, 'changePassword'])
                ->add(AuthMiddleware::class);
                
            // Phone Authentication Routes
            $authGroup->post('/phone/send-code', [PhoneAuthController::class, 'sendVerificationCode']);
            $authGroup->post('/phone/verify-login', [PhoneAuthController::class, 'verifyCodeAndLogin']);
            
            // Social Authentication Routes
            $authGroup->get('/social/providers', [SocialAuthController::class, 'getProviders']);
            $authGroup->post('/google', [SocialAuthController::class, 'googleAuth']);
            $authGroup->post('/apple', [SocialAuthController::class, 'appleAuth']);
            $authGroup->post('/firebase', [SocialAuthController::class, 'firebaseAuth']);
            
            // Protected social routes
            $authGroup->post('/social/link', [SocialAuthController::class, 'linkSocialAccount'])
                ->add(AuthMiddleware::class);
            $authGroup->delete('/social/unlink/{provider}', [SocialAuthController::class, 'unlinkSocialAccount'])
                ->add(AuthMiddleware::class);
        });

        // V1 API routes (for backward compatibility)
        $group->group('/v1', function (RouteCollectorProxy $v1Group) {
            
            // Auth routes
            $v1Group->group('/auth', function (RouteCollectorProxy $authGroup) {
                $authGroup->post('/register', [AuthController::class, 'register']);
                $authGroup->post('/login', [AuthController::class, 'login']);
                $authGroup->post('/refresh', [AuthController::class, 'refresh']);
                $authGroup->post('/forgot-password', [AuthController::class, 'forgotPassword']);
                $authGroup->post('/reset-password', [AuthController::class, 'resetPassword']);
                $authGroup->post('/verify-email', [AuthController::class, 'verifyEmail']);
                $authGroup->post('/resend-verification', [AuthController::class, 'resendEmailVerification']);
                
                // Protected auth routes
                $authGroup->post('/logout', [AuthController::class, 'logout'])
                    ->add(AuthMiddleware::class);
                $authGroup->get('/me', [AuthController::class, 'me'])
                    ->add(AuthMiddleware::class);
                $authGroup->put('/profile', [AuthController::class, 'updateProfile'])
                    ->add(AuthMiddleware::class);
                $authGroup->post('/verify-phone', [AuthController::class, 'verifyPhone'])
                    ->add(AuthMiddleware::class);
                $authGroup->post('/change-password', [AuthController::class, 'changePassword'])
                    ->add(AuthMiddleware::class);
                    
                // Phone Authentication Routes
                $authGroup->post('/phone/send-code', [PhoneAuthController::class, 'sendVerificationCode']);
                $authGroup->post('/phone/verify-login', [PhoneAuthController::class, 'verifyCodeAndLogin']);
                
                // Social Authentication Routes
                $authGroup->get('/social/providers', [SocialAuthController::class, 'getProviders']);
                $authGroup->post('/google', [SocialAuthController::class, 'googleAuth']);
                $authGroup->post('/apple', [SocialAuthController::class, 'appleAuth']);
                $authGroup->post('/firebase', [SocialAuthController::class, 'firebaseAuth']);
                
                // Protected social routes
                $authGroup->post('/social/link', [SocialAuthController::class, 'linkSocialAccount'])
                    ->add(AuthMiddleware::class);
                $authGroup->delete('/social/unlink/{provider}', [SocialAuthController::class, 'unlinkSocialAccount'])
                    ->add(AuthMiddleware::class);
            });
            
            // Profile routes
            $v1Group->group('/profile', function (RouteCollectorProxy $profileGroup) {
                // Profile management
                $profileGroup->get('', [ProfileController::class, 'getProfile'])
                    ->add(AuthMiddleware::class);
                $profileGroup->post('', [ProfileController::class, 'createProfile'])
                    ->add(AuthMiddleware::class);
                $profileGroup->put('', [ProfileController::class, 'updateProfile'])
                    ->add(AuthMiddleware::class);
                
                // Avatar upload
                $profileGroup->post('/avatar', [ProfileController::class, 'uploadAvatar'])
                    ->add(AuthMiddleware::class);
                
                // Document verification
                $profileGroup->post('/documents', [ProfileController::class, 'uploadDocument'])
                    ->add(AuthMiddleware::class);
                $profileGroup->get('/documents', [ProfileController::class, 'getUserDocuments'])
                    ->add(AuthMiddleware::class);
                $profileGroup->delete('/documents/{documentId}', [ProfileController::class, 'deleteDocument'])
                    ->add(AuthMiddleware::class);
                
                // Trust badges
                $profileGroup->get('/badges', [ProfileController::class, 'getUserBadges'])
                    ->add(AuthMiddleware::class);
                
                // Verification status
                $profileGroup->get('/verification-status', [ProfileController::class, 'getVerificationStatus'])
                    ->add(AuthMiddleware::class);
            });
            
            // Trip routes
            $v1Group->group('/trips', function (RouteCollectorProxy $tripGroup) {
                // Public routes (specific routes first)
                $tripGroup->get('/search', [TripController::class, 'search']);
                $tripGroup->get('/price-suggestion', [TripController::class, 'getPriceSuggestion']);
                $tripGroup->get('/price-breakdown', [TripController::class, 'getPriceBreakdown']);
                
                // Protected routes (specific routes first)
                $tripGroup->post('/create', [TripController::class, 'create'])
                    ->add(AuthMiddleware::class);
                $tripGroup->get('/list', [TripController::class, 'list'])
                    ->add(AuthMiddleware::class);
                    
                // Generic routes with parameters (must come last)
                $tripGroup->get('/{id}', [TripController::class, 'get']);
                $tripGroup->put('/{id}/update', [TripController::class, 'update'])
                    ->add(AuthMiddleware::class);
                $tripGroup->delete('/{id}/delete', [TripController::class, 'delete'])
                    ->add(AuthMiddleware::class);
                $tripGroup->post('/{id}/validate-ticket', [TripController::class, 'validateTicket'])
                    ->add(AuthMiddleware::class);
            });
            
            // Admin routes (admin only access)
            $v1Group->group('/admin', function (RouteCollectorProxy $adminGroup) {
                // Auth routes for admin
                $adminGroup->post('/auth/login', [AuthController::class, 'adminLogin']);
                
                // Trip management (admin only)
                $adminGroup->get('/trips/pending', [TripController::class, 'getPendingTrips'])
                    ->add(AdminAuthMiddleware::class);
                $adminGroup->post('/trips/{id}/approve', [TripController::class, 'approveTrip'])
                    ->add(AdminAuthMiddleware::class);
                $adminGroup->post('/trips/{id}/reject', [TripController::class, 'rejectTrip'])
                    ->add(AdminAuthMiddleware::class);
                    
                // User management (admin only)
                $adminGroup->get('/users', [AuthController::class, 'getAllUsers'])
                    ->add(AdminAuthMiddleware::class);
                $adminGroup->put('/users/{id}/role', [AuthController::class, 'updateUserRole'])
                    ->add(AdminAuthMiddleware::class);
            });
            
            // Test routes (development only)
            $v1Group->group('/test', function (RouteCollectorProxy $testGroup) {
                $testGroup->get('/email/config', [TestController::class, 'getEmailConfig']);
                $testGroup->post('/email/welcome', [TestController::class, 'testWelcomeEmail']);
                $testGroup->post('/email/verification', [TestController::class, 'testVerificationEmail']);
                $testGroup->post('/email/reset-password', [TestController::class, 'testPasswordResetEmail']);
            });
        });
    });

    // Catch-all route for undefined endpoints
    $app->map(['GET', 'POST', 'PUT', 'DELETE', 'PATCH'], '/{routes:.+}', 
        function (Request $request, Response $response) {
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Endpoint not found',
                'error_code' => 'NOT_FOUND'
            ]));
            return $response
                ->withStatus(404)
                ->withHeader('Content-Type', 'application/json');
        }
    );
};