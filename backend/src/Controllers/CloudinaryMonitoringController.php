<?php

declare(strict_types=1);

namespace KiloShare\Controllers;

use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use KiloShare\Services\CloudinaryService;
use Psr\Log\LoggerInterface;
use Exception;

class CloudinaryMonitoringController
{
    private CloudinaryService $cloudinaryService;
    private LoggerInterface $logger;

    public function __construct(
        CloudinaryService $cloudinaryService,
        LoggerInterface $logger
    ) {
        $this->cloudinaryService = $cloudinaryService;
        $this->logger = $logger;
    }

    public function getUsageStats(Request $request, Response $response): Response
    {
        try {
            $queryParams = $request->getQueryParams();
            $timeframe = $queryParams['timeframe'] ?? 'monthly';
            $detailed = isset($queryParams['detailed']) && $queryParams['detailed'] === 'true';

            $stats = $this->cloudinaryService->getUsageStats($timeframe, $detailed);
            
            $response->getBody()->write(json_encode([
                'success' => true,
                'data' => $stats,
                'timeframe' => $timeframe,
                'generated_at' => date('Y-m-d H:i:s')
            ]));

            return $response->withHeader('Content-Type', 'application/json');

        } catch (Exception $e) {
            $this->logger->error('Error getting usage stats', [
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString()
            ]);

            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Erreur lors de la récupération des statistiques'
            ]));

            return $response->withStatus(500)->withHeader('Content-Type', 'application/json');
        }
    }

    public function getQuotaStatus(Request $request, Response $response): Response
    {
        try {
            $quotaInfo = $this->cloudinaryService->checkQuotaStatus();
            
            // Calculer les alertes
            $alerts = [];
            if ($quotaInfo['storage_percentage'] > 85) {
                $alerts[] = [
                    'type' => 'storage',
                    'level' => $quotaInfo['storage_percentage'] > 95 ? 'critical' : 'warning',
                    'message' => "Stockage à {$quotaInfo['storage_percentage']}% de la limite"
                ];
            }
            
            if ($quotaInfo['bandwidth_percentage'] > 85) {
                $alerts[] = [
                    'type' => 'bandwidth',
                    'level' => $quotaInfo['bandwidth_percentage'] > 95 ? 'critical' : 'warning',
                    'message' => "Bande passante à {$quotaInfo['bandwidth_percentage']}% de la limite"
                ];
            }

            $response->getBody()->write(json_encode([
                'success' => true,
                'data' => [
                    'quota' => $quotaInfo,
                    'alerts' => $alerts,
                    'recommendations' => $this->getRecommendations($quotaInfo)
                ]
            ]));

            return $response->withHeader('Content-Type', 'application/json');

        } catch (Exception $e) {
            $this->logger->error('Error getting quota status', [
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString()
            ]);

            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Erreur lors de la vérification des quotas'
            ]));

            return $response->withStatus(500)->withHeader('Content-Type', 'application/json');
        }
    }

    public function getImagesByType(Request $request, Response $response): Response
    {
        try {
            $queryParams = $request->getQueryParams();
            $imageType = $queryParams['type'] ?? null;
            $limit = (int)($queryParams['limit'] ?? 50);
            $offset = (int)($queryParams['offset'] ?? 0);

            $images = $this->cloudinaryService->getImagesByType($imageType, $limit, $offset);
            
            $response->getBody()->write(json_encode([
                'success' => true,
                'data' => $images,
                'pagination' => [
                    'limit' => $limit,
                    'offset' => $offset,
                    'total' => $images['total'] ?? 0
                ]
            ]));

            return $response->withHeader('Content-Type', 'application/json');

        } catch (Exception $e) {
            $this->logger->error('Error getting images by type', [
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString()
            ]);

            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Erreur lors de la récupération des images'
            ]));

            return $response->withStatus(500)->withHeader('Content-Type', 'application/json');
        }
    }

    public function triggerCleanup(Request $request, Response $response): Response
    {
        try {
            $body = json_decode((string)$request->getBody(), true);
            $cleanupType = $body['type'] ?? 'auto';
            $force = $body['force'] ?? false;

            $result = $this->cloudinaryService->performCleanup($cleanupType, $force);
            
            $this->logger->info('Manual cleanup triggered', [
                'type' => $cleanupType,
                'force' => $force,
                'result' => $result
            ]);

            $response->getBody()->write(json_encode([
                'success' => true,
                'data' => $result,
                'message' => 'Nettoyage effectué avec succès'
            ]));

            return $response->withHeader('Content-Type', 'application/json');

        } catch (Exception $e) {
            $this->logger->error('Error during cleanup', [
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString()
            ]);

            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Erreur lors du nettoyage: ' . $e->getMessage()
            ]));

            return $response->withStatus(500)->withHeader('Content-Type', 'application/json');
        }
    }

    public function getCleanupHistory(Request $request, Response $response): Response
    {
        try {
            $queryParams = $request->getQueryParams();
            $limit = (int)($queryParams['limit'] ?? 20);
            
            $history = $this->cloudinaryService->getCleanupHistory($limit);
            
            $response->getBody()->write(json_encode([
                'success' => true,
                'data' => $history
            ]));

            return $response->withHeader('Content-Type', 'application/json');

        } catch (Exception $e) {
            $this->logger->error('Error getting cleanup history', [
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString()
            ]);

            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Erreur lors de la récupération de l\'historique'
            ]));

            return $response->withStatus(500)->withHeader('Content-Type', 'application/json');
        }
    }

    public function exportUsageReport(Request $request, Response $response): Response
    {
        try {
            $queryParams = $request->getQueryParams();
            $format = $queryParams['format'] ?? 'json';
            $period = $queryParams['period'] ?? 'last_month';

            $reportData = $this->cloudinaryService->generateUsageReport($period);
            
            if ($format === 'csv') {
                return $this->exportToCsv($response, $reportData, $period);
            }

            $response->getBody()->write(json_encode([
                'success' => true,
                'data' => $reportData,
                'period' => $period,
                'export_date' => date('Y-m-d H:i:s')
            ]));

            return $response->withHeader('Content-Type', 'application/json');

        } catch (Exception $e) {
            $this->logger->error('Error exporting usage report', [
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString()
            ]);

            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Erreur lors de l\'export du rapport'
            ]));

            return $response->withStatus(500)->withHeader('Content-Type', 'application/json');
        }
    }

    private function getRecommendations(array $quotaInfo): array
    {
        $recommendations = [];

        if ($quotaInfo['storage_percentage'] > 80) {
            $recommendations[] = [
                'type' => 'storage',
                'priority' => 'high',
                'action' => 'cleanup_old_images',
                'message' => 'Effectuer un nettoyage des images anciennes'
            ];
        }

        if ($quotaInfo['bandwidth_percentage'] > 80) {
            $recommendations[] = [
                'type' => 'bandwidth',
                'priority' => 'medium',
                'action' => 'optimize_transformations',
                'message' => 'Optimiser les transformations d\'images'
            ];
        }

        if ($quotaInfo['storage_percentage'] < 50 && $quotaInfo['bandwidth_percentage'] < 50) {
            $recommendations[] = [
                'type' => 'optimization',
                'priority' => 'low',
                'action' => 'increase_quality',
                'message' => 'Possibilité d\'augmenter la qualité des compressions'
            ];
        }

        return $recommendations;
    }

    private function exportToCsv(Response $response, array $data, string $period): Response
    {
        $csv = "Date,Type Image,Uploads,Taille Totale,Bande Passante\n";
        
        foreach ($data['daily_stats'] ?? [] as $stat) {
            $csv .= sprintf(
                "%s,%s,%d,%.2f,%.2f\n",
                $stat['date'],
                $stat['image_type'],
                $stat['upload_count'],
                $stat['total_size_mb'],
                $stat['bandwidth_mb']
            );
        }

        $filename = "cloudinary_usage_report_{$period}_" . date('Y-m-d') . ".csv";
        
        $response->getBody()->write($csv);
        
        return $response
            ->withHeader('Content-Type', 'text/csv')
            ->withHeader('Content-Disposition', "attachment; filename=\"{$filename}\"");
    }
}