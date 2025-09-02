class UserProfile {
  final int id;
  final int userId;
  final String? firstName;
  final String? lastName;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? phone;
  final String? address; // Legacy field
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? stateProvince;
  final String? country;
  final String? postalCode;
  final String? nationality;
  final String? avatarUrl;
  final String? bio;
  final String? profession;
  final String? company;
  final String? website;
  final String? preferredLanguage;
  final String? timezone;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? emergencyContactRelation;
  final String? profileVisibility;
  final bool? newsletterSubscribed;
  final bool? marketingEmails;
  final bool isVerified;
  final String verificationLevel;
  final double trustScore;
  final String? email;
  final String? username;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<TrustBadge> badges;
  final VerificationStatus verificationStatus;

  const UserProfile({
    required this.id,
    required this.userId,
    this.firstName,
    this.lastName,
    this.dateOfBirth,
    this.gender,
    this.phone,
    this.address,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.stateProvince,
    this.country,
    this.postalCode,
    this.nationality,
    this.avatarUrl,
    this.bio,
    this.profession,
    this.company,
    this.website,
    this.preferredLanguage,
    this.timezone,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.emergencyContactRelation,
    this.profileVisibility,
    this.newsletterSubscribed,
    this.marketingEmails,
    this.isVerified = false,
    this.verificationLevel = 'none',
    this.trustScore = 0.0,
    this.email,
    this.username,
    required this.createdAt,
    required this.updatedAt,
    this.badges = const [],
    required this.verificationStatus,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      firstName: json['first_name'],
      lastName: json['last_name'],
      dateOfBirth: json['date_of_birth'] != null 
          ? DateTime.parse(json['date_of_birth']) 
          : null,
      gender: json['gender'],
      phone: json['phone'],
      address: json['address'],
      addressLine1: json['address_line1'],
      addressLine2: json['address_line2'],
      city: json['city'],
      stateProvince: json['state_province'],
      country: json['country'],
      postalCode: json['postal_code'],
      nationality: json['nationality'],
      avatarUrl: json['profile_picture'],
      bio: json['bio'],
      profession: json['profession'],
      company: json['company'],
      website: json['website'],
      preferredLanguage: json['preferred_language'],
      timezone: json['timezone'],
      emergencyContactName: json['emergency_contact_name'],
      emergencyContactPhone: json['emergency_contact_phone'],
      emergencyContactRelation: json['emergency_contact_relation'],
      profileVisibility: json['profile_visibility'],
      newsletterSubscribed: json['newsletter_subscribed'] == 1 || json['newsletter_subscribed'] == true,
      marketingEmails: json['marketing_emails'] == 1 || json['marketing_emails'] == true,
      isVerified: json['is_verified'] == 1 || json['is_verified'] == true,
      verificationLevel: json['verification_level'] ?? 'none',
      trustScore: double.tryParse(json['trust_score'].toString()) ?? 0.0,
      email: json['email'],
      username: json['username'],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
      badges: json['badges'] != null 
          ? (json['badges'] as List).map((b) => TrustBadge.fromJson(b)).toList()
          : [],
      verificationStatus: VerificationStatus.fromJson(json['verification_status'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'first_name': firstName,
      'last_name': lastName,
      'date_of_birth': dateOfBirth?.toIso8601String().split('T')[0],
      'gender': gender,
      'phone': phone,
      'address': address,
      'address_line1': addressLine1,
      'address_line2': addressLine2,
      'city': city,
      'state_province': stateProvince,
      'country': country,
      'postal_code': postalCode,
      'nationality': nationality,
      'profile_picture': avatarUrl,
      'bio': bio,
      'profession': profession,
      'company': company,
      'website': website,
      'preferred_language': preferredLanguage,
      'timezone': timezone,
      'emergency_contact_name': emergencyContactName,
      'emergency_contact_phone': emergencyContactPhone,
      'emergency_contact_relation': emergencyContactRelation,
      'profile_visibility': profileVisibility,
      'newsletter_subscribed': newsletterSubscribed,
      'marketing_emails': marketingEmails,
      'is_verified': isVerified,
      'verification_level': verificationLevel,
      'trust_score': trustScore,
      'email': email,
      'username': username,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'badges': badges.map((b) => b.toJson()).toList(),
      'verification_status': verificationStatus.toJson(),
    };
  }

  UserProfile copyWith({
    int? id,
    int? userId,
    String? firstName,
    String? lastName,
    DateTime? dateOfBirth,
    String? gender,
    String? phone,
    String? address,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? stateProvince,
    String? country,
    String? postalCode,
    String? nationality,
    String? avatarUrl,
    String? bio,
    String? profession,
    String? company,
    String? website,
    String? preferredLanguage,
    String? timezone,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? emergencyContactRelation,
    String? profileVisibility,
    bool? newsletterSubscribed,
    bool? marketingEmails,
    bool? isVerified,
    String? verificationLevel,
    double? trustScore,
    String? email,
    String? username,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<TrustBadge>? badges,
    VerificationStatus? verificationStatus,
  }) {
    return UserProfile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      city: city ?? this.city,
      stateProvince: stateProvince ?? this.stateProvince,
      country: country ?? this.country,
      postalCode: postalCode ?? this.postalCode,
      nationality: nationality ?? this.nationality,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      profession: profession ?? this.profession,
      company: company ?? this.company,
      website: website ?? this.website,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      timezone: timezone ?? this.timezone,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
      emergencyContactRelation: emergencyContactRelation ?? this.emergencyContactRelation,
      profileVisibility: profileVisibility ?? this.profileVisibility,
      newsletterSubscribed: newsletterSubscribed ?? this.newsletterSubscribed,
      marketingEmails: marketingEmails ?? this.marketingEmails,
      isVerified: isVerified ?? this.isVerified,
      verificationLevel: verificationLevel ?? this.verificationLevel,
      trustScore: trustScore ?? this.trustScore,
      email: email ?? this.email,
      username: username ?? this.username,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      badges: badges ?? this.badges,
      verificationStatus: verificationStatus ?? this.verificationStatus,
    );
  }

  String get displayName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    }
    if (firstName != null) {
      return firstName!;
    }
    if (username != null) {
      return username!;
    }
    return 'Utilisateur';
  }

  String get initials {
    if (firstName != null && lastName != null) {
      return '${firstName![0]}${lastName![0]}'.toUpperCase();
    }
    if (firstName != null && firstName!.isNotEmpty) {
      return firstName![0].toUpperCase();
    }
    if (username != null && username!.isNotEmpty) {
      return username![0].toUpperCase();
    }
    return 'U';
  }
}

class TrustBadge {
  final int id;
  final int userId;
  final String badgeType;
  final String badgeName;
  final String? badgeDescription;
  final String? badgeIcon;
  final String? badgeColor;
  final bool isActive;
  final int priorityOrder;
  final DateTime earnedAt;
  final DateTime? expiresAt;
  final Map<String, dynamic>? verificationData;

  const TrustBadge({
    required this.id,
    required this.userId,
    required this.badgeType,
    required this.badgeName,
    this.badgeDescription,
    this.badgeIcon,
    this.badgeColor,
    this.isActive = true,
    this.priorityOrder = 0,
    required this.earnedAt,
    this.expiresAt,
    this.verificationData,
  });

  factory TrustBadge.fromJson(Map<String, dynamic> json) {
    return TrustBadge(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      badgeType: json['badge_type'] ?? '',
      badgeName: json['badge_name'] ?? '',
      badgeDescription: json['badge_description'],
      badgeIcon: json['badge_icon'],
      badgeColor: json['badge_color'],
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      priorityOrder: json['priority_order'] ?? 0,
      earnedAt: DateTime.parse(json['earned_at'] ?? DateTime.now().toIso8601String()),
      expiresAt: json['expires_at'] != null ? DateTime.parse(json['expires_at']) : null,
      verificationData: json['verification_data'] != null
          ? Map<String, dynamic>.from(json['verification_data'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'badge_type': badgeType,
      'badge_name': badgeName,
      'badge_description': badgeDescription,
      'badge_icon': badgeIcon,
      'badge_color': badgeColor,
      'is_active': isActive,
      'priority_order': priorityOrder,
      'earned_at': earnedAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'verification_data': verificationData,
    };
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }
}

class VerificationDocument {
  final int id;
  final int userId;
  final String documentType;
  final String? documentNumber;
  final String filePath;
  final String fileName;
  final int? fileSize;
  final String? mimeType;
  final String status;
  final String? verificationNotes;
  final DateTime? expiryDate;
  final DateTime uploadedAt;
  final DateTime? verifiedAt;
  final int? verifiedBy;

  const VerificationDocument({
    required this.id,
    required this.userId,
    required this.documentType,
    this.documentNumber,
    required this.filePath,
    required this.fileName,
    this.fileSize,
    this.mimeType,
    this.status = 'pending',
    this.verificationNotes,
    this.expiryDate,
    required this.uploadedAt,
    this.verifiedAt,
    this.verifiedBy,
  });

  factory VerificationDocument.fromJson(Map<String, dynamic> json) {
    return VerificationDocument(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      documentType: json['document_type'] ?? '',
      documentNumber: json['document_number'],
      filePath: json['file_path'] ?? '',
      fileName: json['file_name'] ?? '',
      fileSize: json['file_size'],
      mimeType: json['mime_type'],
      status: json['status'] ?? 'pending',
      verificationNotes: json['verification_notes'],
      expiryDate: json['expiry_date'] != null ? DateTime.parse(json['expiry_date']) : null,
      uploadedAt: DateTime.parse(json['uploaded_at'] ?? DateTime.now().toIso8601String()),
      verifiedAt: json['verified_at'] != null ? DateTime.parse(json['verified_at']) : null,
      verifiedBy: json['verified_by'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'document_type': documentType,
      'document_number': documentNumber,
      'file_path': filePath,
      'file_name': fileName,
      'file_size': fileSize,
      'mime_type': mimeType,
      'status': status,
      'verification_notes': verificationNotes,
      'expiry_date': expiryDate?.toIso8601String().split('T')[0],
      'uploaded_at': uploadedAt.toIso8601String(),
      'verified_at': verifiedAt?.toIso8601String(),
      'verified_by': verifiedBy,
    };
  }

  String get displayName {
    switch (documentType) {
      case 'identity_card':
        return 'Carte d\'identité';
      case 'passport':
        return 'Passeport';
      case 'driver_license':
        return 'Permis de conduire';
      case 'proof_of_address':
        return 'Justificatif de domicile';
      case 'bank_statement':
        return 'Relevé bancaire';
      case 'utility_bill':
        return 'Facture d\'utilité';
      case 'selfie_with_id':
        return 'Selfie avec pièce d\'identité';
      default:
        return documentType;
    }
  }

  String get statusDisplay {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'approved':
        return 'Approuvé';
      case 'rejected':
        return 'Rejeté';
      case 'expired':
        return 'Expiré';
      default:
        return status;
    }
  }

  bool get isExpired {
    if (expiryDate == null) return false;
    return DateTime.now().isAfter(expiryDate!);
  }
}

class VerificationStatus {
  final String verificationLevel;
  final bool isVerified;
  final double trustScore;
  final int documentsCount;
  final int approvedDocuments;
  final int pendingDocuments;
  final int badgesCount;

  const VerificationStatus({
    this.verificationLevel = 'none',
    this.isVerified = false,
    this.trustScore = 0.0,
    this.documentsCount = 0,
    this.approvedDocuments = 0,
    this.pendingDocuments = 0,
    this.badgesCount = 0,
  });

  factory VerificationStatus.fromJson(Map<String, dynamic> json) {
    return VerificationStatus(
      verificationLevel: json['verification_level'] ?? 'none',
      isVerified: json['is_verified'] == 1 || json['is_verified'] == true,
      trustScore: double.tryParse(json['trust_score'].toString()) ?? 0.0,
      documentsCount: json['documents_count'] ?? 0,
      approvedDocuments: json['approved_documents'] ?? 0,
      pendingDocuments: json['pending_documents'] ?? 0,
      badgesCount: json['badges_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'verification_level': verificationLevel,
      'is_verified': isVerified,
      'trust_score': trustScore,
      'documents_count': documentsCount,
      'approved_documents': approvedDocuments,
      'pending_documents': pendingDocuments,
      'badges_count': badgesCount,
    };
  }

  String get levelDisplay {
    switch (verificationLevel) {
      case 'none':
        return 'Non vérifié';
      case 'basic':
        return 'Vérification de base';
      case 'advanced':
        return 'Vérification avancée';
      case 'premium':
        return 'Vérification premium';
      default:
        return verificationLevel;
    }
  }

  double get completionPercentage {
    // Simple calculation based on verification level
    switch (verificationLevel) {
      case 'none':
        return 0.0;
      case 'basic':
        return 0.25;
      case 'advanced':
        return 0.75;
      case 'premium':
        return 1.0;
      default:
        return 0.0;
    }
  }
}