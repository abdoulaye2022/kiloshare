<?php

declare(strict_types=1);

namespace KiloShare\Services\Channels;

use KiloShare\Models\User;
use Exception;

class SmsNotificationChannel implements NotificationChannelInterface
{
    private string $twilioSid;
    private string $twilioToken;
    private string $twilioPhoneNumber;
    private string $apiUrl;

    public function __construct()
    {
        $this->twilioSid = $_ENV['TWILIO_SID'] ?? '';
        $this->twilioToken = $_ENV['TWILIO_TOKEN'] ?? '';
        $this->twilioPhoneNumber = $_ENV['TWILIO_PHONE'] ?? '';
        $this->apiUrl = "https://api.twilio.com/2010-04-01/Accounts/{$this->twilioSid}/Messages.json";
    }

    public function send(User $user, array $rendered, array $data = []): array
    {
        try {
            $to = $this->getRecipient($user);
            if (!$to) {
                return ['success' => false, 'error' => 'No phone number available'];
            }

            if (!$this->twilioSid || !$this->twilioToken || !$this->twilioPhoneNumber) {
                return ['success' => false, 'error' => 'Twilio credentials not configured'];
            }

            $message = $this->buildSmsMessage($rendered, $data);
            
            $postData = [
                'To' => $to,
                'From' => $this->twilioPhoneNumber,
                'Body' => $message
            ];

            $ch = curl_init();
            curl_setopt($ch, CURLOPT_URL, $this->apiUrl);
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
            curl_setopt($ch, CURLOPT_POST, true);
            curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query($postData));
            curl_setopt($ch, CURLOPT_USERPWD, $this->twilioSid . ':' . $this->twilioToken);
            curl_setopt($ch, CURLOPT_HTTPHEADER, [
                'Content-Type: application/x-www-form-urlencoded'
            ]);

            $response = curl_exec($ch);
            $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
            curl_close($ch);

            if ($httpCode === 201) {
                $responseData = json_decode($response, true);
                return [
                    'success' => true,
                    'provider' => 'twilio',
                    'provider_message_id' => $responseData['sid'] ?? null,
                ];
            } else {
                $error = json_decode($response, true);
                return [
                    'success' => false,
                    'error' => $error['message'] ?? 'SMS sending failed',
                ];
            }

        } catch (Exception $e) {
            return ['success' => false, 'error' => $e->getMessage()];
        }
    }

    private function buildSmsMessage(array $rendered, array $data): string
    {
        $message = $rendered['message'] ?? '';
        $actionUrl = $data['action_url'] ?? null;

        $smsText = "KiloShare: " . $message;
        
        if ($actionUrl) {
            $smsText .= " " . $actionUrl;
        }

        // SMS character limit
        if (strlen($smsText) > 160) {
            $smsText = substr($smsText, 0, 157) . '...';
        }

        return $smsText;
    }

    public function getRecipient(User $user): ?string
    {
        if (empty($user->phone)) {
            return null;
        }

        $phone = preg_replace('/[^+0-9]/', '', $user->phone);
        
        if (strpos($phone, '+') !== 0) {
            $phone = '+' . $phone;
        }

        return $phone;
    }

    public function isAvailable(User $user): bool
    {
        return !empty($user->phone) && 
               !empty($this->twilioSid) && 
               !empty($this->twilioToken) && 
               !empty($this->twilioPhoneNumber);
    }

    public function getName(): string
    {
        return 'sms';
    }

    public function getDisplayName(): string
    {
        return 'SMS';
    }

    public function getCost(): int
    {
        return 10;
    }
}