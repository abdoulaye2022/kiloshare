<?php

declare(strict_types=1);

namespace KiloShare\Services\Channels;

use KiloShare\Models\User;

interface NotificationChannelInterface
{
    public function send(User $user, array $rendered, array $data = []): array;
    
    public function getRecipient(User $user): ?string;
    
    public function isAvailable(User $user): bool;
    
    public function getName(): string;
    
    public function getDisplayName(): string;
    
    public function getCost(): int;
}