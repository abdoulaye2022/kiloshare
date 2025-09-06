-- =====================================================
-- INSERTION DES TEMPLATES DE NOTIFICATION PAR DÉFAUT
-- =====================================================

-- Templates pour les annonces
INSERT IGNORE INTO notification_templates (type, channel, language, title, message, variables) VALUES
('trip_submitted', 'push', 'fr', 'Annonce soumise', 'Votre annonce est en cours de validation', '["trip_title", "departure_city", "arrival_city"]'),
('trip_approved', 'push', 'fr', 'Annonce approuvée', 'Votre annonce {{trip_title}} est maintenant visible', '["trip_title", "trip_url"]'),
('trip_rejected', 'push', 'fr', 'Annonce rejetée', 'Votre annonce a été rejetée : {{reason}}', '["trip_title", "reason"]'),
('trip_expires_soon', 'push', 'fr', 'Voyage expire demain', 'Votre voyage du {{departure_date}} expire demain', '["trip_title", "departure_date"]');

-- Templates pour les négociations
INSERT IGNORE INTO notification_templates (type, channel, language, title, message, variables) VALUES
('new_booking_request', 'push', 'fr', 'Nouvelle demande', '{{sender_name}} veut envoyer {{weight}}kg pour {{price}}€', '["sender_name", "weight", "price", "package_description"]'),
('booking_accepted', 'push', 'fr', 'Demande acceptée', 'Votre demande a été acceptée - Procédez au paiement', '["trip_title", "total_amount"]'),
('booking_rejected', 'push', 'fr', 'Demande refusée', '{{traveler_name}} a décliné votre demande', '["traveler_name", "trip_title"]'),
('negotiation_message', 'push', 'fr', 'Nouveau message', 'Nouveau message de {{sender_name}}', '["sender_name", "message_preview"]');

-- Templates pour les paiements
INSERT IGNORE INTO notification_templates (type, channel, language, title, message, variables) VALUES
('payment_received', 'push', 'fr', 'Paiement reçu', 'Paiement de {{amount}}€ reçu - En attente de confirmation', '["amount", "sender_name"]'),
('payment_confirmed', 'push', 'fr', 'Paiement confirmé', 'Paiement confirmé - Code pickup: {{pickup_code}}', '["amount", "pickup_code"]'),
('payment_released', 'push', 'fr', 'Paiement versé', '{{amount}}€ versé sur votre compte', '["amount", "commission_amount"]');

-- Templates pour le jour J
INSERT IGNORE INTO notification_templates (type, channel, language, title, message, variables) VALUES
('departure_reminder', 'push', 'fr', 'C\'est aujourd\'hui !', 'Départ à {{departure_time}} - {{departure_address}}', '["departure_time", "departure_address", "contact_info"]'),
('pickup_reminder', 'push', 'fr', 'RDV dans 2h', 'RDV avec {{contact_name}} à {{pickup_address}}', '["contact_name", "pickup_address", "contact_phone"]'),
('package_picked_up', 'push', 'fr', 'Colis récupéré', '{{traveler_name}} a récupéré votre colis', '["traveler_name", "pickup_time"]');

-- Templates pour le voyage
INSERT IGNORE INTO notification_templates (type, channel, language, title, message, variables) VALUES
('trip_started', 'push', 'fr', 'Voyage démarré', 'Votre colis est en route vers {{destination}}', '["destination", "estimated_arrival"]'),
('trip_location_update', 'push', 'fr', 'Mise à jour position', 'Votre colis est à {{current_location}}', '["current_location", "estimated_arrival"]'),
('delivery_imminent', 'push', 'fr', 'Livraison imminente', 'Livraison prévue dans ~2h', '["estimated_delivery_time", "delivery_address"]');

-- Templates pour la livraison
INSERT IGNORE INTO notification_templates (type, channel, language, title, message, variables) VALUES
('package_delivered', 'push', 'fr', 'Colis livré', 'Colis livré avec succès !', '["delivery_time", "recipient_name"]'),
('review_request', 'push', 'fr', 'Évaluation', 'Comment s\'est passée la livraison ?', '["partner_name", "trip_title"]');

-- Templates pour les annulations
INSERT IGNORE INTO notification_templates (type, channel, language, title, message, variables) VALUES
('trip_cancelled', 'push', 'fr', 'Voyage annulé', 'Voyage annulé - Remboursement en cours', '["trip_title", "refund_amount"]'),
('booking_cancelled_early', 'push', 'fr', 'Réservation annulée', '{{sender_name}} a annulé sa réservation', '["sender_name", "trip_title"]'),
('booking_cancelled_late', 'push', 'fr', 'Annulation tardive', '{{sender_name}} annule - Compensation: {{amount}}€', '["sender_name", "amount"]');

-- Templates pour la sécurité
INSERT IGNORE INTO notification_templates (type, channel, language, title, message, variables) VALUES
('suspicious_login', 'push', 'fr', 'Connexion suspecte', 'Nouvelle connexion depuis {{location}}', '["location", "device", "ip_address"]'),
('account_suspended', 'push', 'fr', 'Compte suspendu', 'Compte suspendu : {{reason}}', '["reason", "appeal_url"]'),
('security_alert', 'push', 'fr', 'Alerte sécurité', 'Action requise pour sécuriser votre compte', '["action_required", "secure_url"]');

-- Templates email (quelques exemples principaux)
INSERT IGNORE INTO notification_templates (type, channel, language, subject, message, html_content, variables) VALUES
('booking_accepted', 'email', 'fr', 'Demande acceptée - KiloShare', 
'Bonjour {{sender_name}},

Excellente nouvelle ! {{traveler_name}} a accepté votre demande pour le voyage {{trip_title}}.

Détails de la réservation :
- Poids : {{weight}}kg
- Prix : {{price}}€
- Date de départ : {{departure_date}}

Procédez maintenant au paiement pour confirmer votre réservation.

Cordialement,
L\'équipe KiloShare',
'<h2>Demande acceptée</h2><p>Bonjour {{sender_name}},</p><p>Excellente nouvelle ! <strong>{{traveler_name}}</strong> a accepté votre demande.</p><a href="{{payment_url}}" class="btn">Procéder au paiement</a>',
'["sender_name", "traveler_name", "trip_title", "weight", "price", "departure_date", "payment_url"]'),

('payment_confirmed', 'email', 'fr', 'Paiement confirmé - Codes de récupération - KiloShare',
'Bonjour {{sender_name}},

Votre paiement de {{amount}}€ a été confirmé !

CODES IMPORTANTS :
- Code pickup : {{pickup_code}}
- Code delivery : {{delivery_code}}

Détails du voyage :
- Départ : {{departure_date}} à {{departure_time}}
- Adresse RDV : {{pickup_address}}
- Voyageur : {{traveler_name}} - {{traveler_phone}}

Gardez ces codes précieusement !

Cordialement,
L\'équipe KiloShare',
'<h2>Paiement confirmé</h2><div class="codes"><h3>Codes importants :</h3><p><strong>Code pickup :</strong> {{pickup_code}}</p><p><strong>Code delivery :</strong> {{delivery_code}}</p></div>',
'["sender_name", "amount", "pickup_code", "delivery_code", "departure_date", "departure_time", "pickup_address", "traveler_name", "traveler_phone"]'),

('trip_cancelled', 'email', 'fr', 'Voyage annulé - Remboursement - KiloShare',
'Bonjour {{user_name}},

Nous vous informons que le voyage {{trip_title}} prévu le {{departure_date}} a été annulé.

Remboursement :
- Montant : {{refund_amount}}€
- Délai : 5-7 jours ouvrés
- Méthode : Carte bancaire utilisée

Nous nous excusons pour ce désagrément et vous invitons à consulter d\'autres voyages disponibles.

Cordialement,
L\'équipe KiloShare',
'<h2>Voyage annulé</h2><p>Remboursement de <strong>{{refund_amount}}€</strong> en cours...</p>',
'["user_name", "trip_title", "departure_date", "refund_amount"]');

-- Templates SMS (codes uniquement)
INSERT IGNORE INTO notification_templates (type, channel, language, message, variables) VALUES
('sms_pickup_code', 'sms', 'fr', 'KiloShare - Code pickup: {{pickup_code}}. RDV {{time}} à {{address}}', '["pickup_code", "time", "address"]'),
('sms_delivery_code', 'sms', 'fr', 'KiloShare - Code delivery: {{delivery_code}}. Livraison prévue {{time}}', '["delivery_code", "time"]'),
('sms_verification', 'sms', 'fr', 'KiloShare - Code de vérification: {{verification_code}}', '["verification_code"]'),
('sms_departure_reminder', 'sms', 'fr', 'KiloShare - Départ aujourd\'hui {{time}}. RDV: {{address}}. Contact: {{phone}}', '["time", "address", "phone"]');

-- Templates in-app (détaillés)
INSERT IGNORE INTO notification_templates (type, channel, language, title, message, variables) VALUES
('new_booking_request', 'in_app', 'fr', 'Nouvelle demande de réservation', 
'{{sender_name}} souhaite réserver {{weight}}kg sur votre voyage {{trip_title}} pour {{price}}€.

Description du colis : {{package_description}}

Vous pouvez accepter, refuser ou négocier le prix.',
'["sender_name", "weight", "trip_title", "price", "package_description", "booking_id"]'),

('negotiation_message', 'in_app', 'fr', 'Message de négociation',
'{{sender_name}} vous a envoyé un message concernant la réservation {{booking_reference}} :

"{{message_content}}"',
'["sender_name", "booking_reference", "message_content", "booking_id"]'),

('payment_confirmed', 'in_app', 'fr', 'Paiement confirmé',
'Le paiement de {{amount}}€ de {{sender_name}} a été confirmé.

Code pickup généré : {{pickup_code}}
Rendez-vous le {{date}} à {{time}} à {{address}}.

Le montant sera libéré après la livraison.',
'["amount", "sender_name", "pickup_code", "date", "time", "address"]');

-- Templates multilingues (quelques exemples en anglais)
INSERT IGNORE INTO notification_templates (type, channel, language, title, message, variables) VALUES
('new_booking_request', 'push', 'en', 'New request', '{{sender_name}} wants to send {{weight}}kg for {{price}}€', '["sender_name", "weight", "price", "package_description"]'),
('booking_accepted', 'push', 'en', 'Request accepted', 'Your request has been accepted - Proceed to payment', '["trip_title", "total_amount"]'),
('payment_confirmed', 'push', 'en', 'Payment confirmed', 'Payment confirmed - Pickup code: {{pickup_code}}', '["amount", "pickup_code"]'),
('package_delivered', 'push', 'en', 'Package delivered', 'Package delivered successfully!', '["delivery_time", "recipient_name"]');