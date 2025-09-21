class DeliveryCodeModel {
  final int id;
  final int bookingId;
  final String? code; // null pour le destinataire, visible pour l'expéditeur
  final String status;
  final int attemptsCount;
  final int maxAttempts;
  final DateTime generatedAt;
  final DateTime? expiresAt;
  final DateTime? usedAt;
  final int? remainingAttempts;
  final bool? isValid;
  final bool? isExpired;

  const DeliveryCodeModel({
    required this.id,
    required this.bookingId,
    this.code,
    required this.status,
    required this.attemptsCount,
    required this.maxAttempts,
    required this.generatedAt,
    this.expiresAt,
    this.usedAt,
    this.remainingAttempts,
    this.isValid,
    this.isExpired,
  });

  factory DeliveryCodeModel.fromJson(Map<String, dynamic> json) {
    return DeliveryCodeModel(
      id: json['id'] as int,
      bookingId: json['booking_id'] as int,
      code: json['code'] as String?,
      status: json['status'] as String,
      attemptsCount: json['attempts_count'] as int,
      maxAttempts: json['max_attempts'] as int,
      generatedAt: DateTime.parse(json['generated_at'] as String),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      usedAt: json['used_at'] != null
          ? DateTime.parse(json['used_at'] as String)
          : null,
      remainingAttempts: json['remaining_attempts'] as int?,
      isValid: json['is_valid'] as bool?,
      isExpired: json['is_expired'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'booking_id': bookingId,
      'code': code,
      'status': status,
      'attempts_count': attemptsCount,
      'max_attempts': maxAttempts,
      'generated_at': generatedAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'used_at': usedAt?.toIso8601String(),
      'remaining_attempts': remainingAttempts,
      'is_valid': isValid,
      'is_expired': isExpired,
    };
  }

  // Statuts possibles
  static const String statusActive = 'active';
  static const String statusUsed = 'used';
  static const String statusExpired = 'expired';
  static const String statusRegenerated = 'regenerated';

  // Méthodes utilitaires
  bool get isActive => status == statusActive;
  bool get hasExpired => isExpired ?? false;
  bool get hasBeenUsed => status == statusUsed;
  bool get canBeUsed => isActive && (isValid ?? false) && !hasExpired;

  int get attemptsRemaining => remainingAttempts ?? (maxAttempts - attemptsCount);
  bool get hasRemainingAttempts => attemptsRemaining > 0;

  String get statusLabel {
    switch (status) {
      case statusActive:
        return 'Actif';
      case statusUsed:
        return 'Utilisé';
      case statusExpired:
        return 'Expiré';
      case statusRegenerated:
        return 'Régénéré';
      default:
        return status;
    }
  }

  String get formattedExpiryDate {
    if (expiresAt == null) return 'Aucune expiration';

    final now = DateTime.now();
    final difference = expiresAt!.difference(now);

    if (difference.isNegative) {
      return 'Expiré';
    }

    if (difference.inDays > 0) {
      return 'Expire dans ${difference.inDays} jour(s)';
    } else if (difference.inHours > 0) {
      return 'Expire dans ${difference.inHours} heure(s)';
    } else {
      return 'Expire dans ${difference.inMinutes} minute(s)';
    }
  }

  String get formattedCode {
    if (code == null) return '------';
    return code!.split('').join(' ');
  }

  DeliveryCodeModel copyWith({
    int? id,
    int? bookingId,
    String? code,
    String? status,
    int? attemptsCount,
    int? maxAttempts,
    DateTime? generatedAt,
    DateTime? expiresAt,
    DateTime? usedAt,
    int? remainingAttempts,
    bool? isValid,
    bool? isExpired,
  }) {
    return DeliveryCodeModel(
      id: id ?? this.id,
      bookingId: bookingId ?? this.bookingId,
      code: code ?? this.code,
      status: status ?? this.status,
      attemptsCount: attemptsCount ?? this.attemptsCount,
      maxAttempts: maxAttempts ?? this.maxAttempts,
      generatedAt: generatedAt ?? this.generatedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      usedAt: usedAt ?? this.usedAt,
      remainingAttempts: remainingAttempts ?? this.remainingAttempts,
      isValid: isValid ?? this.isValid,
      isExpired: isExpired ?? this.isExpired,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeliveryCodeModel &&
        other.id == id &&
        other.bookingId == bookingId &&
        other.code == code &&
        other.status == status;
  }

  @override
  int get hashCode {
    return Object.hash(id, bookingId, code, status);
  }

  @override
  String toString() {
    return 'DeliveryCodeModel(id: $id, bookingId: $bookingId, status: $status, code: ${code != null ? "***" : "null"})';
  }
}