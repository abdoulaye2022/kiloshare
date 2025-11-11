class BookingModel {
  final int id;
  final String tripId;
  final String senderId;
  final String receiverId;
  final String packageDescription;
  final double weightKg;
  final String? dimensionsCm;
  final double totalPrice;
  final String? pickupAddress;
  final String? deliveryAddress;
  final String? specialInstructions;
  final BookingStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Informations des utilisateurs (jointures)
  final String? senderName;
  final String? senderEmail;
  final String? receiverName;
  final String? receiverEmail;
  
  // Informations du voyage
  final String? tripTitle;
  final String? tripDepartureCity;
  final String? tripArrivalCity;
  final DateTime? tripDepartureDate;

  // Archivage spécifique par utilisateur
  final bool archivedBySender;
  final bool archivedByReceiver;

  BookingModel({
    required this.id,
    required this.tripId,
    required this.senderId,
    required this.receiverId,
    required this.packageDescription,
    required this.weightKg,
    this.dimensionsCm,
    required this.totalPrice,
    this.pickupAddress,
    this.deliveryAddress,
    this.specialInstructions,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.senderName,
    this.senderEmail,
    this.receiverName,
    this.receiverEmail,
    this.tripTitle,
    this.tripDepartureCity,
    this.tripArrivalCity,
    this.tripDepartureDate,
    this.archivedBySender = false,
    this.archivedByReceiver = false,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    final trip = json['trip'] as Map<String, dynamic>?;
    final sender = json['sender'] as Map<String, dynamic>?;
    final receiver = json['receiver'] as Map<String, dynamic>?;
    
    return BookingModel(
      id: json['id'] as int,
      tripId: (trip?['id'] ?? json['trip_id'] ?? 0).toString(),
      senderId: json['sender_id']?.toString() ?? '0',
      receiverId: json['receiver_id']?.toString() ?? '0',
      packageDescription: json['package_description'] as String,
      weightKg: double.parse(json['weight_kg'].toString()),
      dimensionsCm: json['dimensions_cm'] as String?,
      totalPrice: json['total_price'] != null ? double.parse(json['total_price'].toString()) : 0.0,
      pickupAddress: json['pickup_address'] as String?,
      deliveryAddress: json['delivery_address'] as String?,
      specialInstructions: json['special_instructions'] as String?,
      status: BookingStatus.fromString(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : DateTime.parse(json['created_at'] as String),
      senderName: sender != null ? '${sender['first_name'] ?? ''} ${sender['last_name'] ?? ''}'.trim() : null,
      senderEmail: sender?['email'] as String?,
      receiverName: receiver != null ? '${receiver['first_name'] ?? ''} ${receiver['last_name'] ?? ''}'.trim() : null,
      receiverEmail: receiver?['email'] as String?,
      tripTitle: trip?['title'] as String?,
      tripDepartureCity: trip?['departure_city'] as String?,
      tripArrivalCity: trip?['arrival_city'] as String?,
      tripDepartureDate: trip?['departure_date'] != null ? DateTime.parse(trip!['departure_date'] as String) : null,
      archivedBySender: json['archived_by_sender'] == true || json['archived_by_sender'] == 1,
      archivedByReceiver: json['archived_by_receiver'] == true || json['archived_by_receiver'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trip_id': tripId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'package_description': packageDescription,
      'weight_kg': weightKg,
      'dimensions_cm': dimensionsCm,
      'total_price': totalPrice,
      'pickup_address': pickupAddress,
      'delivery_address': deliveryAddress,
      'special_instructions': specialInstructions,
      'status': status.value,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  BookingModel copyWith({
    int? id,
    String? tripId,
    String? senderId,
    String? receiverId,
    String? packageDescription,
    double? weightKg,
    String? dimensionsCm,
    double? totalPrice,
    String? pickupAddress,
    String? deliveryAddress,
    String? specialInstructions,
    BookingStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? senderName,
    String? senderEmail,
    String? receiverName,
    String? receiverEmail,
    String? tripTitle,
    String? tripDepartureCity,
    String? tripArrivalCity,
    DateTime? tripDepartureDate,
    bool? archivedBySender,
    bool? archivedByReceiver,
  }) {
    return BookingModel(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      packageDescription: packageDescription ?? this.packageDescription,
      weightKg: weightKg ?? this.weightKg,
      dimensionsCm: dimensionsCm ?? this.dimensionsCm,
      totalPrice: totalPrice ?? this.totalPrice,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      senderName: senderName ?? this.senderName,
      senderEmail: senderEmail ?? this.senderEmail,
      receiverName: receiverName ?? this.receiverName,
      receiverEmail: receiverEmail ?? this.receiverEmail,
      tripTitle: tripTitle ?? this.tripTitle,
      tripDepartureCity: tripDepartureCity ?? this.tripDepartureCity,
      tripArrivalCity: tripArrivalCity ?? this.tripArrivalCity,
      tripDepartureDate: tripDepartureDate ?? this.tripDepartureDate,
      archivedBySender: archivedBySender ?? this.archivedBySender,
      archivedByReceiver: archivedByReceiver ?? this.archivedByReceiver,
    );
  }

  // Getter helpers
  double get effectivePrice => totalPrice;
  bool get isPending => status == BookingStatus.pending;
  bool get isAccepted => status == BookingStatus.accepted;
  bool get isRejected => status == BookingStatus.rejected;
  bool get isPaymentPending => status == BookingStatus.paymentPending;
  bool get isPaid => status == BookingStatus.paid;
  bool get isCompleted => status == BookingStatus.completed;
  bool get isCancelled => status == BookingStatus.cancelled;

  // Nouveaux helpers pour le système de capture différée
  bool get isPaymentAuthorized => status == BookingStatus.paymentAuthorized;
  bool get isPaymentConfirmed => status == BookingStatus.paymentConfirmed;
  bool get needsPaymentConfirmation => status == BookingStatus.paymentAuthorized;
  bool get canConfirmPayment => status == BookingStatus.paymentAuthorized;
  @Deprecated('Manual payment capture has been disabled. Payment is now captured automatically upon delivery code validation')
  bool get canCapturePayment => false; // Always false - manual capture disabled
  // Peut annuler tant que le paiement n'est pas capturé (pas encore transféré au transporteur)
  // IMPORTANT: Même si accepté, le paiement est encore bloqué jusqu'à la livraison
  bool get canCancelBeforePayment =>
      status == BookingStatus.pending ||
      status == BookingStatus.accepted ||  // OK car paiement pas encore capturé
      status == BookingStatus.paymentAuthorized ||
      status == BookingStatus.paymentConfirmed;

  String get statusDisplayText {
    switch (status) {
      case BookingStatus.pending:
        return 'En attente';
      case BookingStatus.accepted:
        return 'Acceptée';
      case BookingStatus.rejected:
        return 'Rejetée';
      case BookingStatus.paymentPending:
        return 'Paiement requis';
      case BookingStatus.paymentAuthorized:
        return 'Paiement autorisé';
      case BookingStatus.paymentConfirmed:
        return 'Paiement confirmé';
      case BookingStatus.paid:
        return 'Payée';
      case BookingStatus.inTransit:
        return 'En transit';
      case BookingStatus.delivered:
        return 'Livrée';
      case BookingStatus.completed:
        return 'Terminée';
      case BookingStatus.cancelled:
        return 'Annulée';
    }
  }

  String get routeDescription {
    if (tripDepartureCity != null && tripArrivalCity != null) {
      return '$tripDepartureCity → $tripArrivalCity';
    }
    return 'Trajet non spécifié';
  }
}

enum BookingStatus {
  pending('pending'),
  accepted('accepted'),
  rejected('rejected'),
  paymentPending('payment_pending'),
  paymentAuthorized('payment_authorized'),
  paymentConfirmed('payment_confirmed'),
  paid('paid'),
  inTransit('in_transit'),
  delivered('delivered'),
  completed('completed'),
  cancelled('cancelled');

  const BookingStatus(this.value);
  final String value;

  static BookingStatus fromString(String value) {
    return BookingStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => BookingStatus.pending,
    );
  }

  @override
  String toString() => value;
}

// Modèle pour les négociations de prix
class BookingNegotiation {
  final int id;
  final int bookingId;
  final String proposedBy;
  final double amount;
  final String? message;
  final DateTime createdAt;

  BookingNegotiation({
    required this.id,
    required this.bookingId,
    required this.proposedBy,
    required this.amount,
    this.message,
    required this.createdAt,
  });

  factory BookingNegotiation.fromJson(Map<String, dynamic> json) {
    return BookingNegotiation(
      id: json['id'] as int,
      bookingId: json['booking_id'] as int,
      proposedBy: json['proposed_by'].toString(),
      amount: double.parse(json['amount'].toString()),
      message: json['message'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'booking_id': bookingId,
      'proposed_by': proposedBy,
      'amount': amount,
      'message': message,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

// Modèle pour les photos de colis
class BookingPackagePhoto {
  final int id;
  final int bookingId;
  final String uploadedBy;
  final String photoUrl;
  final String photoType;
  final String? cloudinaryId;
  final DateTime createdAt;

  BookingPackagePhoto({
    required this.id,
    required this.bookingId,
    required this.uploadedBy,
    required this.photoUrl,
    required this.photoType,
    this.cloudinaryId,
    required this.createdAt,
  });

  factory BookingPackagePhoto.fromJson(Map<String, dynamic> json) {
    return BookingPackagePhoto(
      id: json['id'] as int,
      bookingId: json['booking_id'] as int,
      uploadedBy: json['uploaded_by'].toString(),
      photoUrl: json['photo_url'] as String,
      photoType: json['photo_type'] as String,
      cloudinaryId: json['cloudinary_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'booking_id': bookingId,
      'uploaded_by': uploadedBy,
      'photo_url': photoUrl,
      'photo_type': photoType,
      'cloudinary_id': cloudinaryId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}