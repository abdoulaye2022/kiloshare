<?php

declare(strict_types=1);

namespace KiloShare\Modules\Booking\Controllers;

use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use KiloShare\Modules\Booking\Models\Booking;
use KiloShare\Modules\Booking\Models\Transaction;
use Exception;
use PDO;

class PaymentController
{
    private PDO $db;
    private Booking $bookingModel;
    private Transaction $transactionModel;

    public function __construct(PDO $db)
    {
        $this->db = $db;
        $this->bookingModel = new Booking($db);
        $this->transactionModel = new Transaction($db);
    }

    /**
     * Créer un Payment Intent pour une réservation
     */
    public function createPaymentIntent(Request $request, Response $response, array $args): Response
    {
        try {
            $bookingId = (int)$args['booking_id'];
            $userId = $request->getAttribute('user_id');
            
            $booking = $this->bookingModel->getById($bookingId);
            
            // Vérifier que l'utilisateur est l'expéditeur
            if ($booking['sender_id'] != $userId) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'error' => 'Seul l\'expéditeur peut effectuer le paiement'
                ]));
                return $response->withStatus(403)->withHeader('Content-Type', 'application/json');
            }
            
            // Vérifier que le paiement est requis
            if ($booking['status'] !== 'payment_pending') {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'error' => 'Cette réservation n\'est pas prête pour le paiement'
                ]));
                return $response->withStatus(400)->withHeader('Content-Type', 'application/json');
            }
            
            // Calculer les montants
            $pricing = $this->bookingModel->calculateTotalWithCommission(
                (float)$booking['final_price'] ?? (float)$booking['proposed_price']
            );
            
            // Simuler la création d'un Payment Intent Stripe (pour développement)
            $paymentIntentId = 'pi_dev_' . uniqid() . '_' . $bookingId;
            $clientSecret = 'pi_dev_' . uniqid() . '_secret';
            
            // Créer la transaction
            $transactionData = [
                'booking_id' => $bookingId,
                'stripe_payment_intent_id' => $paymentIntentId,
                'amount' => $pricing['total_amount'],
                'commission' => $pricing['commission_amount'],
                'receiver_amount' => $pricing['receiver_amount'],
                'currency' => 'CAD',
                'status' => 'pending',
                'payment_method' => 'stripe'
            ];
            
            $transaction = $this->transactionModel->create($transactionData);
            
            $response->getBody()->write(json_encode([
                'success' => true,
                'payment_intent' => [
                    'id' => $paymentIntentId,
                    'client_secret' => $clientSecret,
                    'amount' => $pricing['total_amount'],
                    'currency' => 'CAD'
                ],
                'transaction' => $transaction,
                'pricing' => $pricing,
                'message' => 'Payment Intent créé avec succès (MODE DÉVELOPPEMENT)'
            ]));

            return $response->withStatus(201)->withHeader('Content-Type', 'application/json');

        } catch (Exception $e) {
            error_log("Erreur PaymentController::createPaymentIntent: " . $e->getMessage());
            
            $response->getBody()->write(json_encode([
                'success' => false,
                'error' => 'Erreur lors de la création du Payment Intent'
            ]));
            
            return $response->withStatus(500)->withHeader('Content-Type', 'application/json');
        }
    }

    /**
     * Confirmer un paiement
     */
    public function confirmPayment(Request $request, Response $response, array $args): Response
    {
        try {
            $transactionId = (int)$args['transaction_id'];
            $userId = $request->getAttribute('user_id');
            $data = json_decode($request->getBody()->getContents(), true);
            
            $transaction = $this->transactionModel->getById($transactionId);
            $booking = $this->bookingModel->getById($transaction['booking_id']);
            
            // Vérifier que l'utilisateur est l'expéditeur
            if ($booking['sender_id'] != $userId) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'error' => 'Accès non autorisé'
                ]));
                return $response->withStatus(403)->withHeader('Content-Type', 'application/json');
            }
            
            // En mode développement, simuler la confirmation
            if ($data['simulate_success'] ?? true) {
                // Mettre à jour la transaction comme réussie
                $this->transactionModel->updateStatus($transactionId, 'succeeded');
                
                // Mettre à jour le booking
                $this->bookingModel->updateStatus($transaction['booking_id'], 'paid');
                
                // Créer un compte escrow pour retenir les fonds
                $escrowId = $this->transactionModel->createEscrow(
                    $transactionId,
                    (float)$transaction['receiver_amount'],
                    'delivery_confirmation'
                );
                
                $response->getBody()->write(json_encode([
                    'success' => true,
                    'transaction' => $this->transactionModel->getById($transactionId),
                    'escrow_id' => $escrowId,
                    'message' => 'Paiement confirmé avec succès (MODE DÉVELOPPEMENT)'
                ]));

                return $response->withStatus(200)->withHeader('Content-Type', 'application/json');
            } else {
                // Simuler un échec
                $this->transactionModel->updateStatus($transactionId, 'failed');
                
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'error' => 'Paiement échoué (SIMULATION)',
                    'transaction' => $this->transactionModel->getById($transactionId)
                ]));

                return $response->withStatus(400)->withHeader('Content-Type', 'application/json');
            }

        } catch (Exception $e) {
            error_log("Erreur PaymentController::confirmPayment: " . $e->getMessage());
            
            $response->getBody()->write(json_encode([
                'success' => false,
                'error' => 'Erreur lors de la confirmation du paiement'
            ]));
            
            return $response->withStatus(500)->withHeader('Content-Type', 'application/json');
        }
    }

    /**
     * Libérer les fonds d'escrow (à la livraison)
     */
    public function releaseEscrow(Request $request, Response $response, array $args): Response
    {
        try {
            $transactionId = (int)$args['transaction_id'];
            $userId = $request->getAttribute('user_id');
            $data = json_decode($request->getBody()->getContents(), true);
            
            $transaction = $this->transactionModel->getById($transactionId);
            $booking = $this->bookingModel->getById($transaction['booking_id']);
            
            // Vérifier les autorisations (expéditeur ou récepteur selon le contexte)
            $isAuthorized = ($booking['sender_id'] == $userId || $booking['receiver_id'] == $userId);
            if (!$isAuthorized) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'error' => 'Accès non autorisé'
                ]));
                return $response->withStatus(403)->withHeader('Content-Type', 'application/json');
            }
            
            // Vérifier que les fonds peuvent être libérés
            $escrowStatus = $this->transactionModel->getEscrowStatus($transactionId);
            if (!$escrowStatus || !in_array($escrowStatus['status'], ['holding', 'partial_release'])) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'error' => 'Aucun fonds en escrow à libérer'
                ]));
                return $response->withStatus(400)->withHeader('Content-Type', 'application/json');
            }
            
            $amountToRelease = isset($data['amount']) 
                ? (float)$data['amount'] 
                : ($escrowStatus['amount_held'] - $escrowStatus['amount_released']);
            
            $this->transactionModel->releaseEscrow(
                $transactionId, 
                $amountToRelease, 
                $data['notes'] ?? 'Livraison confirmée'
            );
            
            // Si tous les fonds sont libérés, marquer la réservation comme complétée
            $updatedEscrow = $this->transactionModel->getEscrowStatus($transactionId);
            if ($updatedEscrow['status'] === 'fully_released') {
                $this->bookingModel->updateStatus($transaction['booking_id'], 'completed');
            }
            
            $response->getBody()->write(json_encode([
                'success' => true,
                'amount_released' => $amountToRelease,
                'escrow_status' => $updatedEscrow,
                'message' => 'Fonds libérés avec succès'
            ]));

            return $response->withStatus(200)->withHeader('Content-Type', 'application/json');

        } catch (Exception $e) {
            error_log("Erreur PaymentController::releaseEscrow: " . $e->getMessage());
            
            $response->getBody()->write(json_encode([
                'success' => false,
                'error' => 'Erreur lors de la libération des fonds'
            ]));
            
            return $response->withStatus(500)->withHeader('Content-Type', 'application/json');
        }
    }

    /**
     * Rembourser une transaction
     */
    public function refundPayment(Request $request, Response $response, array $args): Response
    {
        try {
            $transactionId = (int)$args['transaction_id'];
            $userId = $request->getAttribute('user_id');
            $data = json_decode($request->getBody()->getContents(), true);
            
            $transaction = $this->transactionModel->getById($transactionId);
            $booking = $this->bookingModel->getById($transaction['booking_id']);
            
            // Seuls certains rôles peuvent demander un remboursement
            $canRefund = ($booking['sender_id'] == $userId || $booking['receiver_id'] == $userId);
            if (!$canRefund) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'error' => 'Accès non autorisé pour demander un remboursement'
                ]));
                return $response->withStatus(403)->withHeader('Content-Type', 'application/json');
            }
            
            // Vérifier que la transaction peut être remboursée
            if (!in_array($transaction['status'], ['succeeded', 'processing'])) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'error' => 'Cette transaction ne peut pas être remboursée'
                ]));
                return $response->withStatus(400)->withHeader('Content-Type', 'application/json');
            }
            
            $refundAmount = isset($data['amount']) 
                ? (float)$data['amount'] 
                : (float)$transaction['amount'];
            
            $reason = $data['reason'] ?? 'Remboursement demandé';
            
            // Effectuer le remboursement (simulé pour le développement)
            $this->transactionModel->refund($transactionId, $refundAmount, $reason);
            
            // Marquer la réservation comme annulée
            $this->bookingModel->updateStatus($transaction['booking_id'], 'cancelled');
            
            $response->getBody()->write(json_encode([
                'success' => true,
                'refund_amount' => $refundAmount,
                'reason' => $reason,
                'message' => 'Remboursement traité avec succès (MODE DÉVELOPPEMENT)'
            ]));

            return $response->withStatus(200)->withHeader('Content-Type', 'application/json');

        } catch (Exception $e) {
            error_log("Erreur PaymentController::refundPayment: " . $e->getMessage());
            
            $response->getBody()->write(json_encode([
                'success' => false,
                'error' => 'Erreur lors du remboursement'
            ]));
            
            return $response->withStatus(500)->withHeader('Content-Type', 'application/json');
        }
    }

    /**
     * Obtenir l'historique des transactions d'un utilisateur
     */
    public function getUserTransactions(Request $request, Response $response): Response
    {
        try {
            $userId = $request->getAttribute('user_id');
            
            $transactions = $this->transactionModel->getUserTransactions($userId);
            
            $response->getBody()->write(json_encode([
                'success' => true,
                'transactions' => $transactions
            ]));

            return $response->withStatus(200)->withHeader('Content-Type', 'application/json');

        } catch (Exception $e) {
            error_log("Erreur PaymentController::getUserTransactions: " . $e->getMessage());
            
            $response->getBody()->write(json_encode([
                'success' => false,
                'error' => 'Erreur lors de la récupération des transactions'
            ]));
            
            return $response->withStatus(500)->withHeader('Content-Type', 'application/json');
        }
    }

    /**
     * Obtenir les détails d'une transaction
     */
    public function getTransaction(Request $request, Response $response, array $args): Response
    {
        try {
            $transactionId = (int)$args['transaction_id'];
            $userId = $request->getAttribute('user_id');
            
            $transaction = $this->transactionModel->getById($transactionId);
            $booking = $this->bookingModel->getById($transaction['booking_id']);
            
            // Vérifier l'accès
            if ($booking['sender_id'] != $userId && $booking['receiver_id'] != $userId) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'error' => 'Accès non autorisé à cette transaction'
                ]));
                return $response->withStatus(403)->withHeader('Content-Type', 'application/json');
            }
            
            // Ajouter les informations d'escrow
            $escrowStatus = $this->transactionModel->getEscrowStatus($transactionId);
            $transaction['escrow'] = $escrowStatus;
            
            $response->getBody()->write(json_encode([
                'success' => true,
                'transaction' => $transaction
            ]));

            return $response->withStatus(200)->withHeader('Content-Type', 'application/json');

        } catch (Exception $e) {
            error_log("Erreur PaymentController::getTransaction: " . $e->getMessage());
            
            $response->getBody()->write(json_encode([
                'success' => false,
                'error' => 'Erreur lors de la récupération de la transaction'
            ]));
            
            return $response->withStatus(500)->withHeader('Content-Type', 'application/json');
        }
    }
}