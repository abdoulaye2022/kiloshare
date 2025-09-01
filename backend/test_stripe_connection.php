<?php

require_once 'vendor/autoload.php';

// Charger les variables d'environnement
$dotenv = Dotenv\Dotenv::createImmutable(__DIR__);
$dotenv->load();

// Initialiser Stripe
\Stripe\Stripe::setApiKey($_ENV['STRIPE_SECRET_KEY']);

echo "=== Test de connexion Stripe ===\n\n";

try {
    echo "1. Test connexion API Stripe...\n";
    
    // Test simple - récupérer les informations du compte
    $account = \Stripe\Account::retrieve();
    echo "✅ Connexion réussie!\n";
    echo "   Account ID: " . $account->id . "\n";
    echo "   Email: " . ($account->email ?? 'Non défini') . "\n";
    echo "   Country: " . $account->country . "\n";
    echo "   Charges enabled: " . ($account->charges_enabled ? 'Oui' : 'Non') . "\n\n";

    echo "2. Test création compte Express...\n";
    
    // Créer un compte Express test
    $testAccount = \Stripe\Account::create([
        'type' => 'express',
        'email' => 'test-transport@kiloshare.com',
        'capabilities' => [
            'card_payments' => ['requested' => true],
            'transfers' => ['requested' => true],
        ],
        'metadata' => [
            'user_id' => '999',
            'platform' => 'kiloshare',
            'test' => 'true'
        ]
    ]);
    
    echo "✅ Compte Express créé!\n";
    echo "   Account ID: " . $testAccount->id . "\n";
    echo "   Type: " . $testAccount->type . "\n";
    echo "   Email: " . $testAccount->email . "\n";
    echo "   Charges enabled: " . ($testAccount->charges_enabled ? 'Oui' : 'Non') . "\n";
    echo "   Details submitted: " . ($testAccount->details_submitted ? 'Oui' : 'Non') . "\n\n";

    echo "3. Test création lien onboarding...\n";
    
    // Créer un lien d'onboarding
    $accountLink = \Stripe\AccountLink::create([
        'account' => $testAccount->id,
        'refresh_url' => 'http://localhost:8080/api/v1/stripe/refresh',
        'return_url' => 'http://localhost:8080/api/v1/stripe/return',
        'type' => 'account_onboarding',
    ]);
    
    echo "✅ Lien d'onboarding créé!\n";
    echo "   URL: " . $accountLink->url . "\n";
    echo "   Expires at: " . date('Y-m-d H:i:s', $accountLink->expires_at) . "\n\n";

    echo "4. Nettoyage - suppression du compte test...\n";
    
    // Supprimer le compte test
    $testAccount->delete();
    echo "✅ Compte test supprimé\n\n";

    echo "🎉 TOUS LES TESTS SONT PASSÉS!\n";
    echo "Votre intégration Stripe est prête pour KiloShare.\n";

} catch (\Stripe\Exception\ApiErrorException $e) {
    echo "❌ Erreur Stripe API: " . $e->getMessage() . "\n";
    echo "   Code: " . $e->getStripeCode() . "\n";
    echo "   Type: " . $e->getError()->type . "\n";
    
    if ($e->getHttpStatus() === 401) {
        echo "\n💡 Vérifiez que votre clé API Stripe est correcte dans le fichier .env\n";
    }
} catch (Exception $e) {
    echo "❌ Erreur générale: " . $e->getMessage() . "\n";
}

echo "\n=== Fin du test ===\n";
?>