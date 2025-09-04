class Negotiation {
  final int id;
  final int tripId;
  final int senderId;
  final String status;
  final double? proposedWeight;
  final double proposedPrice;
  final String packageDescription;
  final String pickupAddress;
  final String deliveryAddress;
  final String? specialInstructions;
  final List<NegotiationMessage> messages;
  final double? counterOfferPrice;
  final String? counterOfferMessage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? expiresAt;
  final Trip? trip;
  final User? sender;

  Negotiation({
    required this.id,
    required this.tripId,
    required this.senderId,
    required this.status,
    this.proposedWeight,
    required this.proposedPrice,
    required this.packageDescription,
    required this.pickupAddress,
    required this.deliveryAddress,
    this.specialInstructions,
    required this.messages,
    this.counterOfferPrice,
    this.counterOfferMessage,
    required this.createdAt,
    required this.updatedAt,
    this.expiresAt,
    this.trip,
    this.sender,
  });

  factory Negotiation.fromJson(Map<String, dynamic> json) {
    return Negotiation(
      id: json['id'] as int,
      tripId: json['trip_id'] as int,
      senderId: json['sender_id'] as int,
      status: json['status'] as String,
      proposedWeight: json['proposed_weight']?.toDouble(),
      proposedPrice: (json['proposed_price'] as num).toDouble(),
      packageDescription: json['package_description'] as String,
      pickupAddress: json['pickup_address'] as String,
      deliveryAddress: json['delivery_address'] as String,
      specialInstructions: json['special_instructions'] as String?,
      messages: (json['messages'] as List<dynamic>? ?? [])
          .map((msg) => NegotiationMessage.fromJson(msg))
          .toList(),
      counterOfferPrice: json['counter_offer_price']?.toDouble(),
      counterOfferMessage: json['counter_offer_message'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      expiresAt: json['expires_at'] != null 
          ? DateTime.parse(json['expires_at'] as String) 
          : null,
      trip: json['trip'] != null ? Trip.fromJson(json['trip']) : null,
      sender: json['sender'] != null ? User.fromJson(json['sender']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trip_id': tripId,
      'sender_id': senderId,
      'status': status,
      'proposed_weight': proposedWeight,
      'proposed_price': proposedPrice,
      'package_description': packageDescription,
      'pickup_address': pickupAddress,
      'delivery_address': deliveryAddress,
      'special_instructions': specialInstructions,
      'messages': messages.map((msg) => msg.toJson()).toList(),
      'counter_offer_price': counterOfferPrice,
      'counter_offer_message': counterOfferMessage,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'trip': trip?.toJson(),
      'sender': sender?.toJson(),
    };
  }

  // Méthodes utilitaires
  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';
  bool get isCounterProposed => status == 'counter_proposed';
  
  bool get isExpired => expiresAt != null && expiresAt!.isBefore(DateTime.now());
  
  double get currentPrice => counterOfferPrice ?? proposedPrice;
  
  String get statusDisplay {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'accepted':
        return 'Acceptée';
      case 'rejected':
        return 'Rejetée';
      case 'counter_proposed':
        return 'Contre-proposition';
      default:
        return 'Inconnu';
    }
  }
}

class NegotiationMessage {
  final int senderId;
  final String message;
  final DateTime timestamp;

  NegotiationMessage({
    required this.senderId,
    required this.message,
    required this.timestamp,
  });

  factory NegotiationMessage.fromJson(Map<String, dynamic> json) {
    return NegotiationMessage(
      senderId: json['sender_id'] as int,
      message: json['message'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sender_id': senderId,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

// Classes nécessaires (si elles n'existent pas déjà)
class Trip {
  final int id;
  final String origin;
  final String destination;
  final DateTime departureDate;
  final double availableWeight;
  final double pricePerKg;
  final String status;
  final User? user;

  Trip({
    required this.id,
    required this.origin,
    required this.destination,
    required this.departureDate,
    required this.availableWeight,
    required this.pricePerKg,
    required this.status,
    this.user,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] as int,
      origin: json['origin'] as String,
      destination: json['destination'] as String,
      departureDate: DateTime.parse(json['departure_date'] as String),
      availableWeight: (json['available_weight'] as num).toDouble(),
      pricePerKg: (json['price_per_kg'] as num).toDouble(),
      status: json['status'] as String,
      user: json['user'] != null ? User.fromJson(json['user']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'origin': origin,
      'destination': destination,
      'departure_date': departureDate.toIso8601String(),
      'available_weight': availableWeight,
      'price_per_kg': pricePerKg,
      'status': status,
      'user': user?.toJson(),
    };
  }
}

class User {
  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String? profilePicture;

  User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.profilePicture,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      email: json['email'] as String,
      profilePicture: json['profile_picture'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'profile_picture': profilePicture,
    };
  }

  String get fullName => '$firstName $lastName';
}