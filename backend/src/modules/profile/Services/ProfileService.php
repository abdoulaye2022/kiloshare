<?php

namespace App\Modules\Profile\Services;

use PDO;
use Exception;
use DateTime;

class ProfileService
{
    private PDO $pdo;

    public function __construct(PDO $pdo)
    {
        $this->pdo = $pdo;
    }

    public function getUserProfile(int $userId): ?array
    {
        $query = "
            SELECT 
                up.*,
                u.email,
                u.username,
                u.created_at as user_created_at,
                COUNT(tb.id) as badge_count
            FROM user_profiles up
            LEFT JOIN users u ON up.user_id = u.id
            LEFT JOIN trust_badges tb ON up.user_id = tb.user_id AND tb.is_active = 1
            WHERE up.user_id = :user_id
            GROUP BY up.id
        ";
        
        $stmt = $this->pdo->prepare($query);
        $stmt->bindParam(':user_id', $userId, PDO::PARAM_INT);
        $stmt->execute();
        
        $profile = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if ($profile) {
            // Récupérer les badges actifs
            $profile['badges'] = $this->getUserBadges($userId);
            
            // Récupérer le statut de vérification
            $profile['verification_status'] = $this->getVerificationStatus($userId);
        }
        
        return $profile ?: null;
    }

    public function createUserProfile(int $userId, array $data): array
    {
        // Vérifier si le profil existe déjà
        $existingProfile = $this->getUserProfile($userId);
        if ($existingProfile) {
            throw new Exception('Un profil existe déjà pour cet utilisateur');
        }

        $allowedFields = [
            'first_name', 'last_name', 'date_of_birth', 'gender', 'phone',
            'address', 'city', 'country', 'postal_code', 'bio',
            'profession', 'company', 'website'
        ];

        $fields = [];
        $values = [];
        $params = ['user_id' => $userId];

        foreach ($allowedFields as $field) {
            if (isset($data[$field])) {
                $fields[] = $field;
                $values[] = ":$field";
                $params[$field] = $data[$field];
            }
        }

        if (empty($fields)) {
            throw new Exception('Aucune donnée de profil fournie');
        }

        $fieldsStr = implode(', ', $fields);
        $valuesStr = implode(', ', $values);

        $query = "
            INSERT INTO user_profiles (user_id, $fieldsStr, created_at, updated_at)
            VALUES (:user_id, $valuesStr, NOW(), NOW())
        ";

        $stmt = $this->pdo->prepare($query);
        
        foreach ($params as $key => $value) {
            $stmt->bindValue(":$key", $value);
        }

        if (!$stmt->execute()) {
            throw new Exception('Erreur lors de la création du profil');
        }

        // Log de l'action
        $this->logVerificationAction($userId, 'profile_created', 'profile', $this->pdo->lastInsertId(), null, $data);

        return $this->getUserProfile($userId);
    }

    public function updateUserProfile(int $userId, array $data): array
    {
        $allowedFields = [
            'first_name', 'last_name', 'date_of_birth', 'gender', 'phone',
            'address', 'city', 'country', 'postal_code', 'bio',
            'profession', 'company', 'website'
        ];

        $updates = [];
        $params = ['user_id' => $userId];

        foreach ($allowedFields as $field) {
            if (isset($data[$field])) {
                $updates[] = "$field = :$field";
                $params[$field] = $data[$field];
            }
        }

        if (empty($updates)) {
            throw new Exception('Aucune donnée à mettre à jour');
        }

        $updatesStr = implode(', ', $updates);

        $query = "
            UPDATE user_profiles 
            SET $updatesStr, updated_at = NOW()
            WHERE user_id = :user_id
        ";

        $stmt = $this->pdo->prepare($query);
        
        foreach ($params as $key => $value) {
            $stmt->bindValue(":$key", $value);
        }

        if (!$stmt->execute()) {
            throw new Exception('Erreur lors de la mise à jour du profil');
        }

        if ($stmt->rowCount() === 0) {
            throw new Exception('Profil non trouvé');
        }

        // Log de l'action
        $this->logVerificationAction($userId, 'profile_updated', 'profile', $userId, null, $data);

        return $this->getUserProfile($userId);
    }

    public function updateAvatarUrl(int $userId, string $avatarUrl): bool
    {
        $query = "
            UPDATE user_profiles 
            SET avatar_url = :avatar_url, updated_at = NOW()
            WHERE user_id = :user_id
        ";

        $stmt = $this->pdo->prepare($query);
        $stmt->bindParam(':avatar_url', $avatarUrl);
        $stmt->bindParam(':user_id', $userId, PDO::PARAM_INT);

        return $stmt->execute();
    }

    public function uploadVerificationDocument(
        int $userId,
        string $documentType,
        ?string $documentNumber,
        string $filePath,
        string $fileName,
        int $fileSize,
        string $mimeType,
        ?string $expiryDate
    ): array {
        $query = "
            INSERT INTO verification_documents (
                user_id, document_type, document_number, file_path, file_name,
                file_size, mime_type, expiry_date, uploaded_at, created_at, updated_at
            ) VALUES (
                :user_id, :document_type, :document_number, :file_path, :file_name,
                :file_size, :mime_type, :expiry_date, NOW(), NOW(), NOW()
            )
        ";

        $stmt = $this->pdo->prepare($query);
        $stmt->bindParam(':user_id', $userId, PDO::PARAM_INT);
        $stmt->bindParam(':document_type', $documentType);
        $stmt->bindParam(':document_number', $documentNumber);
        $stmt->bindParam(':file_path', $filePath);
        $stmt->bindParam(':file_name', $fileName);
        $stmt->bindParam(':file_size', $fileSize, PDO::PARAM_INT);
        $stmt->bindParam(':mime_type', $mimeType);
        $stmt->bindParam(':expiry_date', $expiryDate);

        if (!$stmt->execute()) {
            throw new Exception('Erreur lors de l\'enregistrement du document');
        }

        $documentId = $this->pdo->lastInsertId();

        // Log de l'action
        $this->logVerificationAction($userId, 'document_uploaded', 'document', $documentId, null, [
            'document_type' => $documentType,
            'file_name' => $fileName
        ]);

        // Retourner les informations du document
        return $this->getDocumentById($documentId);
    }

    public function getUserDocuments(int $userId): array
    {
        $query = "
            SELECT *
            FROM verification_documents
            WHERE user_id = :user_id
            ORDER BY uploaded_at DESC
        ";

        $stmt = $this->pdo->prepare($query);
        $stmt->bindParam(':user_id', $userId, PDO::PARAM_INT);
        $stmt->execute();

        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    public function getUserBadges(int $userId): array
    {
        $query = "
            SELECT *
            FROM trust_badges
            WHERE user_id = :user_id AND is_active = 1
            ORDER BY priority_order ASC, earned_at DESC
        ";

        $stmt = $this->pdo->prepare($query);
        $stmt->bindParam(':user_id', $userId, PDO::PARAM_INT);
        $stmt->execute();

        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    public function getVerificationStatus(int $userId): array
    {
        // Récupérer les informations du profil
        $profileQuery = "
            SELECT verification_level, is_verified, trust_score
            FROM user_profiles
            WHERE user_id = :user_id
        ";
        
        $stmt = $this->pdo->prepare($profileQuery);
        $stmt->bindParam(':user_id', $userId, PDO::PARAM_INT);
        $stmt->execute();
        
        $profileStatus = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$profileStatus) {
            return [
                'verification_level' => 'none',
                'is_verified' => false,
                'trust_score' => 0.00,
                'documents_count' => 0,
                'approved_documents' => 0,
                'pending_documents' => 0,
                'badges_count' => 0
            ];
        }

        // Compter les documents
        $documentsQuery = "
            SELECT 
                COUNT(*) as total_documents,
                SUM(CASE WHEN status = 'approved' THEN 1 ELSE 0 END) as approved_documents,
                SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) as pending_documents
            FROM verification_documents
            WHERE user_id = :user_id
        ";
        
        $stmt = $this->pdo->prepare($documentsQuery);
        $stmt->bindParam(':user_id', $userId, PDO::PARAM_INT);
        $stmt->execute();
        
        $documentsStats = $stmt->fetch(PDO::FETCH_ASSOC);

        // Compter les badges actifs
        $badgesQuery = "
            SELECT COUNT(*) as badges_count
            FROM trust_badges
            WHERE user_id = :user_id AND is_active = 1
        ";
        
        $stmt = $this->pdo->prepare($badgesQuery);
        $stmt->bindParam(':user_id', $userId, PDO::PARAM_INT);
        $stmt->execute();
        
        $badgesStats = $stmt->fetch(PDO::FETCH_ASSOC);

        return [
            'verification_level' => $profileStatus['verification_level'],
            'is_verified' => (bool) $profileStatus['is_verified'],
            'trust_score' => (float) $profileStatus['trust_score'],
            'documents_count' => (int) ($documentsStats['total_documents'] ?? 0),
            'approved_documents' => (int) ($documentsStats['approved_documents'] ?? 0),
            'pending_documents' => (int) ($documentsStats['pending_documents'] ?? 0),
            'badges_count' => (int) ($badgesStats['badges_count'] ?? 0)
        ];
    }

    public function deleteUserDocument(int $userId, int $documentId): bool
    {
        $query = "
            DELETE FROM verification_documents
            WHERE id = :document_id AND user_id = :user_id
        ";

        $stmt = $this->pdo->prepare($query);
        $stmt->bindParam(':document_id', $documentId, PDO::PARAM_INT);
        $stmt->bindParam(':user_id', $userId, PDO::PARAM_INT);

        $result = $stmt->execute();

        if ($result && $stmt->rowCount() > 0) {
            // Log de l'action
            $this->logVerificationAction($userId, 'document_deleted', 'document', $documentId);
            return true;
        }

        return false;
    }

    public function awardBadge(int $userId, string $badgeType, array $badgeData = []): bool
    {
        // Vérifier si le badge existe déjà
        $existingQuery = "
            SELECT id FROM trust_badges
            WHERE user_id = :user_id AND badge_type = :badge_type
        ";
        
        $stmt = $this->pdo->prepare($existingQuery);
        $stmt->bindParam(':user_id', $userId, PDO::PARAM_INT);
        $stmt->bindParam(':badge_type', $badgeType);
        $stmt->execute();

        if ($stmt->fetch()) {
            return false; // Badge déjà attribué
        }

        // Données par défaut des badges
        $defaultBadges = [
            'email_verified' => ['name' => 'Email Vérifié', 'icon' => 'mail-check', 'color' => '#10B981'],
            'phone_verified' => ['name' => 'Téléphone Vérifié', 'icon' => 'phone-check', 'color' => '#3B82F6'],
            'identity_verified' => ['name' => 'Identité Vérifiée', 'icon' => 'id-card', 'color' => '#8B5CF6'],
            'address_verified' => ['name' => 'Adresse Vérifiée', 'icon' => 'map-pin', 'color' => '#EF4444'],
            'premium_member' => ['name' => 'Membre Premium', 'icon' => 'crown', 'color' => '#F59E0B']
        ];

        $badgeInfo = $defaultBadges[$badgeType] ?? $badgeData;

        $query = "
            INSERT INTO trust_badges (
                user_id, badge_type, badge_name, badge_description,
                badge_icon, badge_color, verification_data,
                earned_at, created_at, updated_at
            ) VALUES (
                :user_id, :badge_type, :badge_name, :badge_description,
                :badge_icon, :badge_color, :verification_data,
                NOW(), NOW(), NOW()
            )
        ";

        $stmt = $this->pdo->prepare($query);
        $stmt->bindParam(':user_id', $userId, PDO::PARAM_INT);
        $stmt->bindParam(':badge_type', $badgeType);
        $stmt->bindParam(':badge_name', $badgeInfo['name']);
        $stmt->bindParam(':badge_description', $badgeInfo['description'] ?? null);
        $stmt->bindParam(':badge_icon', $badgeInfo['icon']);
        $stmt->bindParam(':badge_color', $badgeInfo['color']);
        $stmt->bindParam(':verification_data', json_encode($badgeData));

        $result = $stmt->execute();

        if ($result) {
            $badgeId = $this->pdo->lastInsertId();
            $this->logVerificationAction($userId, 'badge_awarded', 'badge', $badgeId, null, $badgeData);
        }

        return $result;
    }

    private function getDocumentById(int $documentId): array
    {
        $query = "SELECT * FROM verification_documents WHERE id = :id";
        $stmt = $this->pdo->prepare($query);
        $stmt->bindParam(':id', $documentId, PDO::PARAM_INT);
        $stmt->execute();

        return $stmt->fetch(PDO::FETCH_ASSOC) ?: [];
    }

    private function logVerificationAction(
        int $userId,
        string $action,
        string $entityType,
        int $entityId,
        ?array $oldValue = null,
        ?array $newValue = null,
        ?int $performedBy = null
    ): void {
        $query = "
            INSERT INTO verification_logs (
                user_id, action, entity_type, entity_id,
                old_value, new_value, performed_by, created_at
            ) VALUES (
                :user_id, :action, :entity_type, :entity_id,
                :old_value, :new_value, :performed_by, NOW()
            )
        ";

        $stmt = $this->pdo->prepare($query);
        $stmt->bindParam(':user_id', $userId, PDO::PARAM_INT);
        $stmt->bindParam(':action', $action);
        $stmt->bindParam(':entity_type', $entityType);
        $stmt->bindParam(':entity_id', $entityId, PDO::PARAM_INT);
        $stmt->bindParam(':old_value', $oldValue ? json_encode($oldValue) : null);
        $stmt->bindParam(':new_value', $newValue ? json_encode($newValue) : null);
        $stmt->bindParam(':performed_by', $performedBy, PDO::PARAM_INT);

        $stmt->execute();
    }
}