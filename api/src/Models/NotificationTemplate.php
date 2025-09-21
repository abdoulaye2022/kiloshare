<?php

declare(strict_types=1);

namespace KiloShare\Models;

use Illuminate\Database\Eloquent\Model;

class NotificationTemplate extends Model
{
    protected $table = 'notification_templates';

    protected $fillable = [
        'type',
        'channel',
        'language',
        'subject',
        'title',
        'message',
        'html_content',
        'variables',
        'is_active',
    ];

    protected $casts = [
        'variables' => 'array',
        'is_active' => 'boolean',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    // Scopes
    public function scopeActive($query)
    {
        return $query->where('is_active', true);
    }

    public function scopeByType($query, string $type)
    {
        return $query->where('type', $type);
    }

    public function scopeByChannel($query, string $channel)
    {
        return $query->where('channel', $channel);
    }

    public function scopeByLanguage($query, string $language)
    {
        return $query->where('language', $language);
    }

    // Methods
    public function render(array $variables = []): array
    {
        $result = [
            'title' => $this->renderTemplate($this->title, $variables),
            'message' => $this->renderTemplate($this->message, $variables),
        ];

        if ($this->subject) {
            $result['subject'] = $this->renderTemplate($this->subject, $variables);
        }

        if ($this->html_content) {
            $result['html_content'] = $this->renderTemplate($this->html_content, $variables);
        }

        return $result;
    }

    private function renderTemplate(string $template, array $variables): string
    {
        $rendered = $template;

        foreach ($variables as $key => $value) {
            // Support pour les variables sous forme {{variable}} et {variable}
            $patterns = [
                '{{' . $key . '}}',
                '{' . $key . '}',
                '{{' . strtoupper($key) . '}}',
                '{' . strtoupper($key) . '}',
            ];

            foreach ($patterns as $pattern) {
                $rendered = str_replace($pattern, (string)$value, $rendered);
            }
        }

        return $rendered;
    }

    public function getRequiredVariables(): array
    {
        return $this->variables ?? [];
    }

    public function validateVariables(array $variables): array
    {
        $required = $this->getRequiredVariables();
        $missing = [];

        foreach ($required as $variable) {
            if (!isset($variables[$variable])) {
                $missing[] = $variable;
            }
        }

        return $missing;
    }

    // Static methods
    public static function findTemplate(string $type, string $channel, string $language = 'fr'): ?self
    {
        // Essayer d'abord avec la langue demandée
        $template = self::active()
            ->byType($type)
            ->byChannel($channel)
            ->byLanguage($language)
            ->first();

        // Si pas trouvé, fallback vers le français
        if (!$template && $language !== 'fr') {
            $template = self::active()
                ->byType($type)
                ->byChannel($channel)
                ->byLanguage('fr')
                ->first();
        }

        return $template;
    }

    public static function renderNotification(
        string $type, 
        string $channel, 
        array $variables, 
        string $language = 'fr'
    ): ?array {
        $template = self::findTemplate($type, $channel, $language);
        
        if (!$template) {
            return null;
        }

        $missing = $template->validateVariables($variables);
        if (!empty($missing)) {
            throw new \InvalidArgumentException(
                "Missing required variables for template {$type}:{$channel}: " . implode(', ', $missing)
            );
        }

        return $template->render($variables);
    }

    public static function getAvailableTypes(): array
    {
        return self::distinct('type')->pluck('type')->toArray();
    }

    public static function getAvailableChannels(): array
    {
        return self::distinct('channel')->pluck('channel')->toArray();
    }

    public static function getAvailableLanguages(): array
    {
        return self::distinct('language')->pluck('language')->toArray();
    }

    // Constants
    public const CHANNELS = [
        'push' => 'push',
        'email' => 'email',
        'sms' => 'sms',
        'in_app' => 'in_app',
    ];

    public const LANGUAGES = [
        'fr' => 'Français',
        'en' => 'English',
    ];

    public const COMMON_VARIABLES = [
        'user_name' => 'Nom de l\'utilisateur',
        'trip_title' => 'Titre du voyage',
        'departure_date' => 'Date de départ',
        'departure_time' => 'Heure de départ',
        'departure_city' => 'Ville de départ',
        'arrival_city' => 'Ville d\'arrivée',
        'price' => 'Prix',
        'weight' => 'Poids',
        'pickup_code' => 'Code pickup',
        'delivery_code' => 'Code livraison',
        'traveler_name' => 'Nom du voyageur',
        'sender_name' => 'Nom de l\'expéditeur',
        'amount' => 'Montant',
    ];
}