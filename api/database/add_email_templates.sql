-- =====================================================
-- AJOUT DES TEMPLATES EMAIL MANQUANTS
-- =====================================================

-- Template email pour nouvelle demande de réservation reçue
INSERT IGNORE INTO notification_templates (type, channel, language, subject, message, html_content, variables) VALUES
('booking_request_received', 'email', 'fr', 'Nouvelle demande de réservation - KiloShare',
'Bonjour,

Vous avez reçu une nouvelle demande de réservation de {{sender_name}} pour votre voyage {{trip_title}}.

Détails de la demande :
- Poids : {{weight_kg}}kg
- Prix proposé : {{proposed_price}}€
- Description : {{package_description}}

Connectez-vous à KiloShare pour accepter ou refuser cette demande.

Cordialement,
L\'équipe KiloShare',
'<h2>Nouvelle demande de réservation</h2><p>Vous avez reçu une nouvelle demande de <strong>{{sender_name}}</strong> pour votre voyage <strong>{{trip_title}}</strong>.</p><p>Poids: {{weight_kg}}kg - Prix: {{proposed_price}}€</p><a href="{{app_url}}" class="btn">Voir la demande</a>',
'["sender_name", "trip_title", "package_description", "weight_kg", "proposed_price", "booking_id"]'),

-- Template email pour paiement en attente après acceptation
('booking_accepted_payment_pending', 'email', 'fr', 'Demande acceptée - Paiement requis - KiloShare',
'Bonjour,

Excellente nouvelle ! Votre demande pour le voyage {{trip_title}} a été acceptée.

Montant à payer : {{total_amount}}€
Délai de confirmation : {{confirmation_deadline}}

Procédez maintenant au paiement pour sécuriser votre réservation.

IMPORTANT : Si vous ne confirmez pas le paiement dans les délais, votre réservation sera automatiquement annulée.

Cordialement,
L\'équipe KiloShare',
'<h2>Demande acceptée</h2><p>Votre demande pour <strong>{{trip_title}}</strong> a été acceptée !</p><p>Montant: <strong>{{total_amount}}€</strong></p><p>Délai: {{confirmation_deadline}}</p><a href="{{payment_url}}" class="btn">Procéder au paiement</a>',
'["trip_title", "total_amount", "confirmation_deadline"]'),

-- Template email pour nouveau message
('new_message', 'email', 'fr', 'Nouveau message - KiloShare',
'Bonjour,

{{sender_name}} vous a envoyé un nouveau message :

"{{message_preview}}"

Connectez-vous à KiloShare pour répondre et continuer la conversation.

Cordialement,
L\'équipe KiloShare',
'<h2>Nouveau message</h2><p><strong>{{sender_name}}</strong> vous a écrit :</p><blockquote>{{message_preview}}</blockquote><a href="{{app_url}}" class="btn">Répondre</a>',
'["sender_name", "message_preview", "conversation_id", "booking_id"]');