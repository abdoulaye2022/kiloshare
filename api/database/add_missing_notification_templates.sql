-- =====================================================
-- AJOUT DES TEMPLATES MANQUANTS
-- =====================================================

-- Template pour nouvelle demande de réservation reçue
INSERT IGNORE INTO notification_templates (type, channel, language, title, message, variables) VALUES
('booking_request_received', 'push', 'fr', 'Nouvelle demande de réservation',
'{{sender_name}} veut envoyer {{weight_kg}}kg sur votre voyage {{trip_title}} pour {{proposed_price}}€',
'["sender_name", "trip_title", "package_description", "weight_kg", "proposed_price", "booking_id"]'),

('booking_request_received', 'in_app', 'fr', 'Nouvelle demande de réservation',
'{{sender_name}} souhaite réserver {{weight_kg}}kg sur votre voyage {{trip_title}} pour {{proposed_price}}€.

Description du colis : {{package_description}}

Vous pouvez accepter ou refuser cette demande.',
'["sender_name", "weight_kg", "trip_title", "proposed_price", "package_description", "booking_id"]'),

-- Template pour paiement en attente après acceptation
('booking_accepted_payment_pending', 'push', 'fr', 'Demande acceptée - Paiement requis',
'Votre demande pour {{trip_title}} a été acceptée ! Procédez au paiement de {{total_amount}}€. Vous avez {{confirmation_deadline}} pour confirmer.',
'["trip_title", "total_amount", "confirmation_deadline"]'),

('booking_accepted_payment_pending', 'in_app', 'fr', 'Demande acceptée - Paiement requis',
'Excellente nouvelle ! Votre demande pour {{trip_title}} a été acceptée.

Montant à payer : {{total_amount}}€
Délai de confirmation : {{confirmation_deadline}}

Procédez maintenant au paiement pour sécuriser votre réservation.',
'["trip_title", "total_amount", "confirmation_deadline"]'),

-- Template pour nouveau message
('new_message', 'push', 'fr', 'Nouveau message',
'{{sender_name}} : {{message_preview}}',
'["sender_name", "message_preview", "conversation_id", "booking_id"]'),

('new_message', 'in_app', 'fr', 'Nouveau message',
'{{sender_name}} vous a envoyé un message :

"{{message_preview}}"',
'["sender_name", "message_preview", "conversation_id", "booking_id"]');