<?php

namespace App\Modules\Trips\Models;

use DateTime;
use InvalidArgumentException;

class Trip
{
    // Core properties
    private $id;
    private $uuid;
    private $userId;
    
    // Departure info
    private $departureCity;
    private $departureCountry;
    private $departureAirportCode;
    private $departureDate;
    
    // Arrival info
    private $arrivalCity;
    private $arrivalCountry;
    private $arrivalAirportCode;
    private $arrivalDate;
    
    // Capacity and pricing
    private $availableWeightKg;
    private $pricePerKg;
    private $currency;
    
    // Flight info
    private $flightNumber;
    private $airline;
    private $ticketVerified;
    private $ticketVerificationDate;
    
    // Status and metadata
    private $status;
    private $viewCount;
    private $bookingCount;
    
    // Description
    private $description;
    private $specialNotes;
    
    // Timestamps
    private $createdAt;
    private $updatedAt;
    
    // NEW: Status tracking dates
    private $publishedAt;
    private $pausedAt;
    private $cancelledAt;
    private $archivedAt;
    private $expiredAt;
    private $rejectedAt;
    private $completedAt;
    private $deletedAt;
    
    // NEW: Reasons and notes
    private $rejectionReason;
    private $rejectionDetails;
    private $cancellationReason;
    private $cancellationDetails;
    private $pauseReason;
    
    // NEW: Moderation
    private $isApproved;
    private $autoApproved;
    private $moderatedBy;
    private $moderationNotes;
    private $trustScoreAtCreation;
    private $requiresManualReview;
    private $reviewPriority;
    
    // NEW: Metrics
    private $shareCount;
    private $favoriteCount;
    private $reportCount;
    private $duplicateCount;
    private $editCount;
    private $totalBookedWeight;
    private $remainingWeight;
    
    // NEW: Flags and options
    private $isUrgent;
    private $isFeatured;
    private $isVerified;
    private $autoExpire;
    private $allowPartialBooking;
    private $instantBooking;
    
    // NEW: Visibility
    private $visibility;
    private $minUserRating;
    private $minUserTrips;
    private $blockedUsers;
    
    // NEW: SEO and sharing
    private $slug;
    private $metaTitle;
    private $metaDescription;
    private $shareToken;
    
    // NEW: Versioning
    private $version;
    private $lastMajorEdit;
    private $originalTripId;
    
    // NEW: Restrictions
    private $restrictedCategories;
    private $restrictedItems;
    private $restrictionNotes;
    
    // NEW: Images
    private $hasImages = false;
    private $imageCount = 0;
    private $images = [];

    // Constructor
    public function __construct(array $data = [])
    {
        if (!empty($data)) {
            $this->fromArray($data);
        }
    }

    // Create from array
    public function fromArray(array $data): self
    {
        // Core properties
        $this->id = $data['id'] ?? null;
        $this->uuid = $data['uuid'] ?? null;
        $this->userId = $data['user_id'] ?? null;
        
        // Location and dates
        $this->departureCity = $data['departure_city'] ?? null;
        $this->departureCountry = $data['departure_country'] ?? null;
        $this->departureAirportCode = $data['departure_airport_code'] ?? null;
        $this->departureDate = $data['departure_date'] ?? null;
        
        $this->arrivalCity = $data['arrival_city'] ?? null;
        $this->arrivalCountry = $data['arrival_country'] ?? null;
        $this->arrivalAirportCode = $data['arrival_airport_code'] ?? null;
        $this->arrivalDate = $data['arrival_date'] ?? null;
        
        // Capacity and pricing
        $this->availableWeightKg = $data['available_weight_kg'] ?? 23.0;
        $this->pricePerKg = $data['price_per_kg'] ?? null;
        $this->currency = $data['currency'] ?? 'CAD';
        
        // Flight info
        $this->flightNumber = $data['flight_number'] ?? null;
        $this->airline = $data['airline'] ?? null;
        $this->ticketVerified = $data['ticket_verified'] ?? false;
        $this->ticketVerificationDate = $data['ticket_verification_date'] ?? null;
        
        // Status and metadata
        $this->status = $data['status'] ?? 'draft';
        $this->viewCount = $data['view_count'] ?? 0;
        $this->bookingCount = $data['booking_count'] ?? 0;
        
        // Description
        $this->description = $data['description'] ?? null;
        $this->specialNotes = $data['special_notes'] ?? null;
        
        // Timestamps
        $this->createdAt = $data['created_at'] ?? null;
        $this->updatedAt = $data['updated_at'] ?? null;
        
        // NEW: Status tracking dates
        $this->publishedAt = $data['published_at'] ?? null;
        $this->pausedAt = $data['paused_at'] ?? null;
        $this->cancelledAt = $data['cancelled_at'] ?? null;
        $this->archivedAt = $data['archived_at'] ?? null;
        $this->expiredAt = $data['expired_at'] ?? null;
        $this->rejectedAt = $data['rejected_at'] ?? null;
        $this->completedAt = $data['completed_at'] ?? null;
        $this->deletedAt = $data['deleted_at'] ?? null;
        
        // NEW: Reasons and notes
        $this->rejectionReason = $data['rejection_reason'] ?? null;
        $this->rejectionDetails = $data['rejection_details'] ?? null;
        $this->cancellationReason = $data['cancellation_reason'] ?? null;
        $this->cancellationDetails = $data['cancellation_details'] ?? null;
        $this->pauseReason = $data['pause_reason'] ?? null;
        
        // NEW: Moderation
        $this->isApproved = $data['is_approved'] ?? false;
        $this->autoApproved = $data['auto_approved'] ?? false;
        $this->moderatedBy = $data['moderated_by'] ?? null;
        $this->moderationNotes = $data['moderation_notes'] ?? null;
        $this->trustScoreAtCreation = $data['trust_score_at_creation'] ?? null;
        $this->requiresManualReview = $data['requires_manual_review'] ?? false;
        $this->reviewPriority = $data['review_priority'] ?? 'medium';
        
        // NEW: Metrics
        $this->shareCount = $data['share_count'] ?? 0;
        $this->favoriteCount = $data['favorite_count'] ?? 0;
        $this->reportCount = $data['report_count'] ?? 0;
        $this->duplicateCount = $data['duplicate_count'] ?? 0;
        $this->editCount = $data['edit_count'] ?? 0;
        $this->totalBookedWeight = $data['total_booked_weight'] ?? 0.00;
        $this->remainingWeight = $data['remaining_weight'] ?? null;
        
        // NEW: Flags and options
        $this->isUrgent = $data['is_urgent'] ?? false;
        $this->isFeatured = $data['is_featured'] ?? false;
        $this->isVerified = $data['is_verified'] ?? false;
        $this->autoExpire = $data['auto_expire'] ?? true;
        $this->allowPartialBooking = $data['allow_partial_booking'] ?? true;
        $this->instantBooking = $data['instant_booking'] ?? false;
        
        // NEW: Visibility
        $this->visibility = $data['visibility'] ?? 'public';
        $this->minUserRating = $data['min_user_rating'] ?? 0.0;
        $this->minUserTrips = $data['min_user_trips'] ?? 0;
        $this->blockedUsers = $data['blocked_users'] ?? null;
        
        // NEW: SEO and sharing
        $this->slug = $data['slug'] ?? null;
        $this->metaTitle = $data['meta_title'] ?? null;
        $this->metaDescription = $data['meta_description'] ?? null;
        $this->shareToken = $data['share_token'] ?? null;
        
        // NEW: Versioning
        $this->version = $data['version'] ?? 1;
        $this->lastMajorEdit = $data['last_major_edit'] ?? null;
        $this->originalTripId = $data['original_trip_id'] ?? null;
        
        // NEW: Restrictions
        $this->restrictedCategories = $data['restricted_categories'] ?? null;
        $this->restrictedItems = $data['restricted_items'] ?? null;
        $this->restrictionNotes = $data['restriction_notes'] ?? null;
        
        // Images
        $this->hasImages = $data['has_images'] ?? false;
        $this->imageCount = $data['image_count'] ?? 0;
        $this->images = $data['images'] ?? [];
        
        return $this;
    }

    // Convert to array
    public function toArray(): array
    {
        return [
            // Core
            'id' => $this->id,
            'uuid' => $this->uuid,
            'user_id' => $this->userId,
            
            // Location and dates
            'departure_city' => $this->departureCity,
            'departure_country' => $this->departureCountry,
            'departure_airport_code' => $this->departureAirportCode,
            'departure_date' => $this->departureDate,
            'arrival_city' => $this->arrivalCity,
            'arrival_country' => $this->arrivalCountry,
            'arrival_airport_code' => $this->arrivalAirportCode,
            'arrival_date' => $this->arrivalDate,
            
            // Capacity and pricing
            'available_weight_kg' => $this->availableWeightKg,
            'price_per_kg' => $this->pricePerKg,
            'currency' => $this->currency,
            
            // Flight info
            'flight_number' => $this->flightNumber,
            'airline' => $this->airline,
            'ticket_verified' => $this->ticketVerified,
            'ticket_verification_date' => $this->ticketVerificationDate,
            
            // Status and metadata
            'status' => $this->status,
            'view_count' => $this->viewCount,
            'booking_count' => $this->bookingCount,
            
            // Description
            'description' => $this->description,
            'special_notes' => $this->specialNotes,
            
            // Timestamps
            'created_at' => $this->createdAt,
            'updated_at' => $this->updatedAt,
            
            // Status tracking dates
            'published_at' => $this->publishedAt,
            'paused_at' => $this->pausedAt,
            'cancelled_at' => $this->cancelledAt,
            'archived_at' => $this->archivedAt,
            'expired_at' => $this->expiredAt,
            'rejected_at' => $this->rejectedAt,
            'completed_at' => $this->completedAt,
            'deleted_at' => $this->deletedAt,
            
            // Reasons and notes
            'rejection_reason' => $this->rejectionReason,
            'rejection_details' => $this->rejectionDetails,
            'cancellation_reason' => $this->cancellationReason,
            'cancellation_details' => $this->cancellationDetails,
            'pause_reason' => $this->pauseReason,
            
            // Moderation
            'is_approved' => $this->isApproved,
            'auto_approved' => $this->autoApproved,
            'moderated_by' => $this->moderatedBy,
            'moderation_notes' => $this->moderationNotes,
            'trust_score_at_creation' => $this->trustScoreAtCreation,
            'requires_manual_review' => $this->requiresManualReview,
            'review_priority' => $this->reviewPriority,
            
            // Metrics
            'share_count' => $this->shareCount,
            'favorite_count' => $this->favoriteCount,
            'report_count' => $this->reportCount,
            'duplicate_count' => $this->duplicateCount,
            'edit_count' => $this->editCount,
            'total_booked_weight' => $this->totalBookedWeight,
            'remaining_weight' => $this->remainingWeight,
            
            // Flags and options
            'is_urgent' => $this->isUrgent,
            'is_featured' => $this->isFeatured,
            'is_verified' => $this->isVerified,
            'auto_expire' => $this->autoExpire,
            'allow_partial_booking' => $this->allowPartialBooking,
            'instant_booking' => $this->instantBooking,
            
            // Visibility
            'visibility' => $this->visibility,
            'min_user_rating' => $this->minUserRating,
            'min_user_trips' => $this->minUserTrips,
            'blocked_users' => $this->blockedUsers,
            
            // SEO and sharing
            'slug' => $this->slug,
            'meta_title' => $this->metaTitle,
            'meta_description' => $this->metaDescription,
            'share_token' => $this->shareToken,
            
            // Versioning
            'version' => $this->version,
            'last_major_edit' => $this->lastMajorEdit,
            'original_trip_id' => $this->originalTripId,
            
            // Restrictions
            'restricted_categories' => $this->restrictedCategories,
            'restricted_items' => $this->restrictedItems,
            'restriction_notes' => $this->restrictionNotes,
            
            // Images
            'has_images' => $this->hasImages,
            'image_count' => $this->imageCount,
            'images' => $this->images,
        ];
    }

    // Convert to JSON (for API responses)
    public function toJson(): array
    {
        $data = $this->toArray();
        
        // Format dates for JSON
        $dateFields = [
            'departure_date', 'arrival_date', 'ticket_verification_date',
            'created_at', 'updated_at', 'published_at', 'paused_at',
            'cancelled_at', 'archived_at', 'expired_at', 'rejected_at',
            'completed_at', 'deleted_at', 'last_major_edit'
        ];
        
        foreach ($dateFields as $field) {
            if ($data[$field]) {
                $data[$field] = date('c', strtotime($data[$field]));
            }
        }
        
        // Convert numeric values with proper null handling
        $data['available_weight_kg'] = $data['available_weight_kg'] !== null ? (float) $data['available_weight_kg'] : 0.0;
        $data['price_per_kg'] = $data['price_per_kg'] !== null ? (float) $data['price_per_kg'] : 0.0;
        $data['total_booked_weight'] = $data['total_booked_weight'] !== null ? (float) $data['total_booked_weight'] : 0.0;
        $data['remaining_weight'] = $data['remaining_weight'] !== null ? (float) $data['remaining_weight'] : $data['available_weight_kg'];
        $data['min_user_rating'] = $data['min_user_rating'] !== null ? (float) $data['min_user_rating'] : 0.0;
        
        // Convert integers
        $intFields = [
            'view_count', 'booking_count', 'share_count', 'favorite_count',
            'report_count', 'duplicate_count', 'edit_count', 'min_user_trips',
            'version', 'trust_score_at_creation'
        ];
        
        foreach ($intFields as $field) {
            $data[$field] = $data[$field] !== null ? (int) $data[$field] : 0;
        }
        
        // Convert booleans
        $boolFields = [
            'ticket_verified', 'is_approved', 'auto_approved', 'requires_manual_review',
            'is_urgent', 'is_featured', 'is_verified', 'auto_expire',
            'allow_partial_booking', 'instant_booking'
        ];
        
        foreach ($boolFields as $field) {
            $data[$field] = $data[$field] !== null ? (bool) $data[$field] : false;
        }
        
        // Parse JSON fields
        if ($data['rejection_details']) {
            $data['rejection_details'] = json_decode($data['rejection_details'], true);
        }
        if ($data['blocked_users']) {
            $data['blocked_users'] = json_decode($data['blocked_users'], true);
        }
        
        // Parse restriction fields - ensure they are arrays or null
        if (isset($data['restricted_categories'])) {
            if (is_string($data['restricted_categories']) && $data['restricted_categories'] !== 'null' && !empty($data['restricted_categories'])) {
                $data['restricted_categories'] = json_decode($data['restricted_categories'], true);
            } elseif (is_array($data['restricted_categories'])) {
                // Already an array, keep as is
            } else {
                $data['restricted_categories'] = null;
            }
        }
        
        if (isset($data['restricted_items'])) {
            if (is_string($data['restricted_items']) && $data['restricted_items'] !== 'null' && !empty($data['restricted_items'])) {
                $data['restricted_items'] = json_decode($data['restricted_items'], true);
            } elseif (is_array($data['restricted_items'])) {
                // Already an array, keep as is
            } else {
                $data['restricted_items'] = null;
            }
        }
        
        return $data;
    }

    // Validation
    public function validate(): array
    {
        $errors = [];
        
        // Required fields
        if (empty($this->departureCity)) {
            $errors[] = 'Departure city is required';
        }
        if (empty($this->departureCountry)) {
            $errors[] = 'Departure country is required';
        }
        if (empty($this->arrivalCity)) {
            $errors[] = 'Arrival city is required';
        }
        if (empty($this->arrivalCountry)) {
            $errors[] = 'Arrival country is required';
        }
        if (empty($this->departureDate)) {
            $errors[] = 'Departure date is required';
        }
        if (empty($this->arrivalDate)) {
            $errors[] = 'Arrival date is required';
        }
        if (empty($this->availableWeightKg) || $this->availableWeightKg <= 0) {
            $errors[] = 'Available weight must be greater than 0';
        }
        if (empty($this->pricePerKg) || $this->pricePerKg <= 0) {
            $errors[] = 'Price per kg must be greater than 0';
        }
        
        // Business rules
        if ($this->availableWeightKg > 50) {
            $errors[] = 'Available weight cannot exceed 50kg';
        }
        
        // Date validation
        if ($this->departureDate && strtotime($this->departureDate) < time()) {
            $errors[] = 'Departure date must be in the future';
        }
        
        if ($this->departureDate && $this->arrivalDate) {
            if (strtotime($this->arrivalDate) <= strtotime($this->departureDate)) {
                $errors[] = 'Arrival date must be after departure date';
            }
        }
        
        // Status validation
        $validStatuses = [
            'draft', 'pending_review', 'active', 'rejected', 'paused',
            'booked', 'in_progress', 'completed', 'cancelled', 'expired'
        ];
        if (!in_array($this->status, $validStatuses)) {
            $errors[] = 'Invalid status';
        }
        
        // Visibility validation
        if (!in_array($this->visibility, ['public', 'private', 'unlisted'])) {
            $errors[] = 'Invalid visibility setting';
        }
        
        // Transport rules validation
        $transportRuleErrors = $this->validateTransportRules();
        $errors = array_merge($errors, $transportRuleErrors);
        
        return $errors;
    }

    /**
     * Validate transport rules based on mode of transportation
     * Avion: Canada ↔ pays étranger (toujours inclure le Canada)
     * Voiture: Seulement entre villes du Canada
     */
    private function validateTransportRules(): array
    {
        $errors = [];
        
        // Déterminer le mode de transport basé sur les informations disponibles
        $isFlightTransport = !empty($this->flightNumber) || !empty($this->airline) || 
                           !empty($this->departureAirportCode) || !empty($this->arrivalAirportCode);
        
        if ($isFlightTransport) {
            // Règles pour le transport aérien: toujours inclure le Canada
            $isCanadaDeparture = $this->departureCountry === 'Canada';
            $isCanadaArrival = $this->arrivalCountry === 'Canada';
            
            // Les vols doivent inclure le Canada (départ ou arrivée)
            // Cela permet les vols domestiques canadiens ET les vols internationaux depuis/vers le Canada
            if (!$isCanadaDeparture && !$isCanadaArrival) {
                $errors[] = 'Les voyages par avion doivent toujours inclure le Canada (départ ou arrivée)';
            }
        } else {
            // Règles pour le transport terrestre (voiture): seulement au Canada
            if ($this->departureCountry !== 'Canada' || $this->arrivalCountry !== 'Canada') {
                $errors[] = 'Les voyages en voiture sont limités aux villes canadiennes uniquement';
            }
        }
        
        return $errors;
    }

    // Business logic methods
    public function isEditable(): bool
    {
        return in_array($this->status, ['draft', 'pending_review', 'active', 'paused', 'rejected']) && 
               strtotime($this->departureDate) > time() &&
               is_null($this->archivedAt) &&
               is_null($this->deletedAt);
    }
    
    public function canBePublished(): bool
    {
        return in_array($this->status, ['draft', 'rejected', 'paused', 'active']) && 
               empty($this->validate()) && 
               strtotime($this->departureDate) > time();
    }
    
    public function isPendingReview(): bool
    {
        return $this->status === 'pending_review';
    }
    
    public function isActive(): bool
    {
        return $this->status === 'active';
    }
    
    public function isExpired(): bool
    {
        return $this->status === 'expired' || 
               ($this->autoExpire && strtotime($this->departureDate) < time());
    }
    
    public function getRemainingDays(): int
    {
        return max(0, floor((strtotime($this->departureDate) - time()) / 86400));
    }
    
    public function getTotalEarningsPotential(): float
    {
        return $this->availableWeightKg * $this->pricePerKg;
    }
    
    public function getRemainingCapacity(): float
    {
        return max(0, $this->availableWeightKg - $this->totalBookedWeight);
    }
    
    public function getBookingPercentage(): float
    {
        if ($this->availableWeightKg <= 0) return 0;
        return ($this->totalBookedWeight / $this->availableWeightKg) * 100;
    }
    
    public function canAcceptBooking(float $weight): bool
    {
        return $this->isActive() && 
               $this->getRemainingCapacity() >= $weight &&
               (!$this->allowPartialBooking || $weight <= $this->availableWeightKg);
    }

    // Status management methods
    public function publish(): self
    {
        if ($this->canBePublished()) {
            $this->status = 'active';
            $this->publishedAt = date('Y-m-d H:i:s');
        }
        return $this;
    }
    
    public function pause(?string $reason = null): self
    {
        if ($this->isActive()) {
            $this->status = 'paused';
            $this->pausedAt = date('Y-m-d H:i:s');
            $this->pauseReason = $reason;
        }
        return $this;
    }
    
    public function resume(): self
    {
        if ($this->status === 'paused') {
            $this->status = 'active';
            $this->pausedAt = null;
            $this->pauseReason = null;
        }
        return $this;
    }
    
    public function cancel(?string $reason = null, ?string $details = null): self
    {
        if (!in_array($this->status, ['completed', 'cancelled'])) {
            $this->status = 'cancelled';
            $this->cancelledAt = date('Y-m-d H:i:s');
            $this->cancellationReason = $reason;
            $this->cancellationDetails = $details;
        }
        return $this;
    }
    
    public function reject(?string $reason = null, ?array $details = null): self
    {
        $this->status = 'rejected';
        $this->rejectedAt = date('Y-m-d H:i:s');
        $this->rejectionReason = $reason;
        $this->rejectionDetails = $details ? json_encode($details) : null;
        return $this;
    }
    
    public function complete(): self
    {
        if (in_array($this->status, ['active', 'booked', 'in_progress'])) {
            $this->status = 'completed';
            $this->completedAt = date('Y-m-d H:i:s');
        }
        return $this;
    }

    // Getters and Setters (keeping existing ones and adding new ones)
    public function getId(): ?int { return $this->id; }
    public function setId(?int $id): self { $this->id = $id; return $this; }
    
    public function getUuid(): ?string { return $this->uuid; }
    public function setUuid(?string $uuid): self { $this->uuid = $uuid; return $this; }
    
    public function getUserId(): ?int { return $this->userId; }
    public function setUserId(?int $userId): self { $this->userId = $userId; return $this; }
    
    // Location getters/setters
    public function getDepartureCity(): ?string { return $this->departureCity; }
    public function setDepartureCity(?string $departureCity): self { $this->departureCity = $departureCity; return $this; }
    
    public function getDepartureCountry(): ?string { return $this->departureCountry; }
    public function setDepartureCountry(?string $departureCountry): self { $this->departureCountry = $departureCountry; return $this; }
    
    public function getDepartureAirportCode(): ?string { return $this->departureAirportCode; }
    public function setDepartureAirportCode(?string $departureAirportCode): self { $this->departureAirportCode = $departureAirportCode; return $this; }
    
    public function getDepartureDate(): ?string { return $this->departureDate; }
    public function setDepartureDate(?string $departureDate): self { $this->departureDate = $departureDate; return $this; }
    
    public function getArrivalCity(): ?string { return $this->arrivalCity; }
    public function setArrivalCity(?string $arrivalCity): self { $this->arrivalCity = $arrivalCity; return $this; }
    
    public function getArrivalCountry(): ?string { return $this->arrivalCountry; }
    public function setArrivalCountry(?string $arrivalCountry): self { $this->arrivalCountry = $arrivalCountry; return $this; }
    
    public function getArrivalAirportCode(): ?string { return $this->arrivalAirportCode; }
    public function setArrivalAirportCode(?string $arrivalAirportCode): self { $this->arrivalAirportCode = $arrivalAirportCode; return $this; }
    
    public function getArrivalDate(): ?string { return $this->arrivalDate; }
    public function setArrivalDate(?string $arrivalDate): self { $this->arrivalDate = $arrivalDate; return $this; }
    
    // Weight and pricing
    public function getAvailableWeightKg(): float { return $this->availableWeightKg; }
    public function setAvailableWeightKg(float $availableWeightKg): self { $this->availableWeightKg = $availableWeightKg; return $this; }
    
    public function getPricePerKg(): float { return $this->pricePerKg; }
    public function setPricePerKg(float $pricePerKg): self { $this->pricePerKg = $pricePerKg; return $this; }
    
    public function getCurrency(): string { return $this->currency; }
    public function setCurrency(string $currency): self { $this->currency = $currency; return $this; }
    
    // Flight info
    public function getFlightNumber(): ?string { return $this->flightNumber; }
    public function setFlightNumber(?string $flightNumber): self { $this->flightNumber = $flightNumber; return $this; }
    
    public function getAirline(): ?string { return $this->airline; }
    public function setAirline(?string $airline): self { $this->airline = $airline; return $this; }
    
    public function isTicketVerified(): bool { return $this->ticketVerified; }
    public function setTicketVerified(bool $ticketVerified): self { $this->ticketVerified = $ticketVerified; return $this; }
    
    public function getTicketVerificationDate(): ?string { return $this->ticketVerificationDate; }
    public function setTicketVerificationDate(?string $ticketVerificationDate): self { $this->ticketVerificationDate = $ticketVerificationDate; return $this; }
    
    // Status and metadata
    public function getStatus(): string { return $this->status; }
    public function setStatus(string $status): self { $this->status = $status; return $this; }
    
    public function getViewCount(): int { return $this->viewCount; }
    public function setViewCount(int $viewCount): self { $this->viewCount = $viewCount; return $this; }
    
    public function getBookingCount(): int { return $this->bookingCount; }
    public function setBookingCount(int $bookingCount): self { $this->bookingCount = $bookingCount; return $this; }
    
    // Description
    public function getDescription(): ?string { return $this->description; }
    public function setDescription(?string $description): self { $this->description = $description; return $this; }
    
    public function getSpecialNotes(): ?string { return $this->specialNotes; }
    public function setSpecialNotes(?string $specialNotes): self { $this->specialNotes = $specialNotes; return $this; }
    
    // Timestamps
    public function getCreatedAt(): ?string { return $this->createdAt; }
    public function setCreatedAt(?string $createdAt): self { $this->createdAt = $createdAt; return $this; }
    
    public function getUpdatedAt(): ?string { return $this->updatedAt; }
    public function setUpdatedAt(?string $updatedAt): self { $this->updatedAt = $updatedAt; return $this; }
    
    // NEW: Status dates getters/setters
    public function getPublishedAt(): ?string { return $this->publishedAt; }
    public function setPublishedAt(?string $publishedAt): self { $this->publishedAt = $publishedAt; return $this; }
    
    public function getPausedAt(): ?string { return $this->pausedAt; }
    public function setCancelledAt(?string $cancelledAt): self { $this->cancelledAt = $cancelledAt; return $this; }
    
    public function getCancelledAt(): ?string { return $this->cancelledAt; }
    
    public function getSlug(): ?string { return $this->slug; }
    public function setSlug(?string $slug): self { $this->slug = $slug; return $this; }
    
    public function getVisibility(): string { return $this->visibility; }
    public function setVisibility(string $visibility): self { $this->visibility = $visibility; return $this; }
    
    public function isFeatured(): bool { return $this->isFeatured; }
    public function setFeatured(bool $isFeatured): self { $this->isFeatured = $isFeatured; return $this; }
    
    public function isVerified(): bool { return $this->isVerified; }
    public function setVerified(bool $isVerified): self { $this->isVerified = $isVerified; return $this; }
    
    public function getTotalBookedWeight(): float { return $this->totalBookedWeight; }
    public function setTotalBookedWeight(float $totalBookedWeight): self { $this->totalBookedWeight = $totalBookedWeight; return $this; }
    
    public function getIsApproved(): bool { return $this->isApproved; }
    public function setIsApproved(bool $isApproved): self { $this->isApproved = $isApproved; return $this; }
    
    public function getAutoApproved(): bool { return $this->autoApproved; }
    public function setAutoApproved(bool $autoApproved): self { $this->autoApproved = $autoApproved; return $this; }
    
    public function getRequiresManualReview(): bool { return $this->requiresManualReview; }
    public function setRequiresManualReview(bool $requiresManualReview): self { $this->requiresManualReview = $requiresManualReview; return $this; }
    
    public function getShareToken(): ?string { return $this->shareToken; }
    public function setShareToken(?string $shareToken): self { $this->shareToken = $shareToken; return $this; }
    
    public function getFavoriteCount(): int { return $this->favoriteCount; }
    public function setFavoriteCount(int $favoriteCount): self { $this->favoriteCount = $favoriteCount; return $this; }
    
    public function getShareCount(): int { return $this->shareCount; }
    public function setShareCount(int $shareCount): self { $this->shareCount = $shareCount; return $this; }
    
    public function getReportCount(): int { return $this->reportCount; }
    public function setReportCount(int $reportCount): self { $this->reportCount = $reportCount; return $this; }
    
    public function getDuplicateCount(): int { return $this->duplicateCount; }
    public function setDuplicateCount(int $duplicateCount): self { $this->duplicateCount = $duplicateCount; return $this; }
    
    public function getEditCount(): int { return $this->editCount; }
    public function setEditCount(int $editCount): self { $this->editCount = $editCount; return $this; }
    
    public function getRemainingWeight(): float { return $this->remainingWeight; }
    public function setRemainingWeight(float $remainingWeight): self { $this->remainingWeight = $remainingWeight; return $this; }
    
    public function getDeletedAt(): ?string { return $this->deletedAt; }
    public function setDeletedAt(?string $deletedAt): self { $this->deletedAt = $deletedAt; return $this; }
    
    // Restriction getters/setters
    public function getRestrictedCategories(): ?array { return $this->restrictedCategories; }
    public function setRestrictedCategories(?array $restrictedCategories): self { $this->restrictedCategories = $restrictedCategories; return $this; }
    
    public function getRestrictedItems(): ?array { return $this->restrictedItems; }
    public function setRestrictedItems(?array $restrictedItems): self { $this->restrictedItems = $restrictedItems; return $this; }
    
    public function getRestrictionNotes(): ?string { return $this->restrictionNotes; }
    public function setRestrictionNotes(?string $restrictionNotes): self { $this->restrictionNotes = $restrictionNotes; return $this; }
    
    // Images
    public function getHasImages(): bool { return $this->hasImages; }
    public function setHasImages(bool $hasImages): self { $this->hasImages = $hasImages; return $this; }
    
    public function getImageCount(): int { return $this->imageCount; }
    public function setImageCount(int $imageCount): self { $this->imageCount = $imageCount; return $this; }
    
    public function getImages(): array { return $this->images; }
    public function setImages(array $images): self { $this->images = $images; return $this; }
    
    public function addImage(array $image): self { 
        $this->images[] = $image; 
        $this->imageCount = count($this->images);
        $this->hasImages = $this->imageCount > 0;
        return $this; 
    }
}