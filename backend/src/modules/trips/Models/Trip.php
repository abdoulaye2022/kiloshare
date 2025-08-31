<?php

namespace App\Modules\Trips\Models;

class Trip
{
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
        $this->id = $data['id'] ?? null;
        $this->uuid = $data['uuid'] ?? null;
        $this->userId = $data['user_id'] ?? null;
        
        $this->departureCity = $data['departure_city'] ?? null;
        $this->departureCountry = $data['departure_country'] ?? null;
        $this->departureAirportCode = $data['departure_airport_code'] ?? null;
        $this->departureDate = $data['departure_date'] ?? null;
        
        $this->arrivalCity = $data['arrival_city'] ?? null;
        $this->arrivalCountry = $data['arrival_country'] ?? null;
        $this->arrivalAirportCode = $data['arrival_airport_code'] ?? null;
        $this->arrivalDate = $data['arrival_date'] ?? null;
        
        $this->availableWeightKg = $data['available_weight_kg'] ?? 23.0;
        $this->pricePerKg = $data['price_per_kg'] ?? null;
        $this->currency = $data['currency'] ?? 'EUR';
        
        $this->flightNumber = $data['flight_number'] ?? null;
        $this->airline = $data['airline'] ?? null;
        $this->ticketVerified = $data['ticket_verified'] ?? false;
        $this->ticketVerificationDate = $data['ticket_verification_date'] ?? null;
        
        $this->status = $data['status'] ?? 'draft';
        $this->viewCount = $data['view_count'] ?? 0;
        $this->bookingCount = $data['booking_count'] ?? 0;
        
        $this->description = $data['description'] ?? null;
        $this->specialNotes = $data['special_notes'] ?? null;
        
        $this->createdAt = $data['created_at'] ?? null;
        $this->updatedAt = $data['updated_at'] ?? null;
        
        return $this;
    }

    // Convert to array
    public function toArray(): array
    {
        return [
            'id' => $this->id,
            'uuid' => $this->uuid,
            'user_id' => $this->userId,
            'departure_city' => $this->departureCity,
            'departure_country' => $this->departureCountry,
            'departure_airport_code' => $this->departureAirportCode,
            'departure_date' => $this->departureDate,
            'arrival_city' => $this->arrivalCity,
            'arrival_country' => $this->arrivalCountry,
            'arrival_airport_code' => $this->arrivalAirportCode,
            'arrival_date' => $this->arrivalDate,
            'available_weight_kg' => $this->availableWeightKg,
            'price_per_kg' => $this->pricePerKg,
            'currency' => $this->currency,
            'flight_number' => $this->flightNumber,
            'airline' => $this->airline,
            'ticket_verified' => $this->ticketVerified,
            'ticket_verification_date' => $this->ticketVerificationDate,
            'status' => $this->status,
            'view_count' => $this->viewCount,
            'booking_count' => $this->bookingCount,
            'description' => $this->description,
            'special_notes' => $this->specialNotes,
            'created_at' => $this->createdAt,
            'updated_at' => $this->updatedAt,
        ];
    }

    // Convert to JSON (for API responses)
    public function toJson(): array
    {
        $data = $this->toArray();
        
        // Format dates for JSON
        if ($data['departure_date']) {
            $data['departure_date'] = date('c', strtotime($data['departure_date']));
        }
        if ($data['arrival_date']) {
            $data['arrival_date'] = date('c', strtotime($data['arrival_date']));
        }
        if ($data['ticket_verification_date']) {
            $data['ticket_verification_date'] = date('c', strtotime($data['ticket_verification_date']));
        }
        if ($data['created_at']) {
            $data['created_at'] = date('c', strtotime($data['created_at']));
        }
        if ($data['updated_at']) {
            $data['updated_at'] = date('c', strtotime($data['updated_at']));
        }
        
        // Convert numeric values
        $data['available_weight_kg'] = (float) $data['available_weight_kg'];
        $data['price_per_kg'] = (float) $data['price_per_kg'];
        $data['view_count'] = (int) $data['view_count'];
        $data['booking_count'] = (int) $data['booking_count'];
        $data['ticket_verified'] = (bool) $data['ticket_verified'];
        
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
        if ($this->availableWeightKg > 23) {
            $errors[] = 'Available weight cannot exceed 23kg';
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
        $validStatuses = ['draft', 'published', 'completed', 'cancelled'];
        if (!in_array($this->status, $validStatuses)) {
            $errors[] = 'Invalid status';
        }
        
        return $errors;
    }

    // Business logic methods
    public function isEditable(): bool
    {
        return in_array($this->status, ['draft', 'published']) && 
               strtotime($this->departureDate) > time();
    }
    
    public function canBePublished(): bool
    {
        return $this->status === 'draft' && 
               empty($this->validate()) && 
               strtotime($this->departureDate) > time();
    }
    
    public function getRemainingDays(): int
    {
        return max(0, floor((strtotime($this->departureDate) - time()) / 86400));
    }
    
    public function getTotalEarningsPotential(): float
    {
        return $this->availableWeightKg * $this->pricePerKg;
    }

    // Getters and Setters
    public function getId(): ?int { return $this->id; }
    public function setId(?int $id): self { $this->id = $id; return $this; }
    
    public function getUuid(): ?string { return $this->uuid; }
    public function setUuid(?string $uuid): self { $this->uuid = $uuid; return $this; }
    
    public function getUserId(): ?int { return $this->userId; }
    public function setUserId(?int $userId): self { $this->userId = $userId; return $this; }
    
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
    
    public function getAvailableWeightKg(): float { return $this->availableWeightKg; }
    public function setAvailableWeightKg(float $availableWeightKg): self { $this->availableWeightKg = $availableWeightKg; return $this; }
    
    public function getPricePerKg(): float { return $this->pricePerKg; }
    public function setPricePerKg(float $pricePerKg): self { $this->pricePerKg = $pricePerKg; return $this; }
    
    public function getCurrency(): string { return $this->currency; }
    public function setCurrency(string $currency): self { $this->currency = $currency; return $this; }
    
    public function getFlightNumber(): ?string { return $this->flightNumber; }
    public function setFlightNumber(?string $flightNumber): self { $this->flightNumber = $flightNumber; return $this; }
    
    public function getAirline(): ?string { return $this->airline; }
    public function setAirline(?string $airline): self { $this->airline = $airline; return $this; }
    
    public function isTicketVerified(): bool { return $this->ticketVerified; }
    public function setTicketVerified(bool $ticketVerified): self { $this->ticketVerified = $ticketVerified; return $this; }
    
    public function getTicketVerificationDate(): ?string { return $this->ticketVerificationDate; }
    public function setTicketVerificationDate(?string $ticketVerificationDate): self { $this->ticketVerificationDate = $ticketVerificationDate; return $this; }
    
    public function getStatus(): string { return $this->status; }
    public function setStatus(string $status): self { $this->status = $status; return $this; }
    
    public function getViewCount(): int { return $this->viewCount; }
    public function setViewCount(int $viewCount): self { $this->viewCount = $viewCount; return $this; }
    
    public function getBookingCount(): int { return $this->bookingCount; }
    public function setBookingCount(int $bookingCount): self { $this->bookingCount = $bookingCount; return $this; }
    
    public function getDescription(): ?string { return $this->description; }
    public function setDescription(?string $description): self { $this->description = $description; return $this; }
    
    public function getSpecialNotes(): ?string { return $this->specialNotes; }
    public function setSpecialNotes(?string $specialNotes): self { $this->specialNotes = $specialNotes; return $this; }
    
    public function getCreatedAt(): ?string { return $this->createdAt; }
    public function setCreatedAt(?string $createdAt): self { $this->createdAt = $createdAt; return $this; }
    
    public function getUpdatedAt(): ?string { return $this->updatedAt; }
    public function setUpdatedAt(?string $updatedAt): self { $this->updatedAt = $updatedAt; return $this; }
}