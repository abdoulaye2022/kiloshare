// Modèles simplifiés pour le test de l'interface moderne

enum TrustLevel {
  newUser,      // < 30 points
  verified,     // 30-70 points  
  established   // > 70 points
}

enum UserRole {
  user,         // Utilisateur normal
  admin,        // Administrateur
  moderator     // Modérateur (si besoin plus tard)
}

class User {
  final int id;
  final String uuid;
  final String email;
  final String? phone;
  final String? firstName;
  final String? lastName;
  final bool isVerified;
  final DateTime? emailVerifiedAt;
  final DateTime? phoneVerifiedAt;
  final String? profilePicture;
  final String status;
  final DateTime? lastLoginAt;
  final UserRole role;
  final int trustScore;
  final int completedTrips;
  final int totalTrips;
  final DateTime createdAt;
  final DateTime updatedAt;

  const User({
    required this.id,
    required this.uuid,
    required this.email,
    this.phone,
    this.firstName,
    this.lastName,
    required this.isVerified,
    this.emailVerifiedAt,
    this.phoneVerifiedAt,
    this.profilePicture,
    required this.status,
    this.lastLoginAt,
    this.role = UserRole.user,
    this.trustScore = 0,
    this.completedTrips = 0,
    this.totalTrips = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  static UserRole _parseUserRole(String? role) {
    switch (role?.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'moderator':
        return UserRole.moderator;
      default:
        return UserRole.user;
    }
  }

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as int,
    uuid: json['uuid'] as String? ?? '',
    email: json['email'] as String,
    phone: json['phone'] as String? ?? json['phone_number'] as String?,
    firstName: json['first_name'] as String?,
    lastName: json['last_name'] as String?,
    isVerified: json['is_verified'] is bool 
        ? json['is_verified'] as bool 
        : json['is_verified'] != null 
            ? (json['is_verified'] as int) == 1
            : false,
    emailVerifiedAt: json['email_verified_at'] != null 
        ? DateTime.parse(json['email_verified_at'] as String) 
        : null,
    phoneVerifiedAt: json['phone_verified_at'] != null 
        ? DateTime.parse(json['phone_verified_at'] as String) 
        : null,
    profilePicture: json['profile_picture'] as String?,
    status: json['status'] as String? ?? 'active',
    lastLoginAt: json['last_login_at'] != null 
        ? DateTime.parse(json['last_login_at'] as String) 
        : null,
    role: _parseUserRole(json['role'] as String?),
    trustScore: json['trust_score'] as int? ?? 0,
    completedTrips: json['completed_trips'] as int? ?? 0,
    totalTrips: json['total_trips'] as int? ?? 0,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: json['updated_at'] != null 
        ? DateTime.parse(json['updated_at'] as String)
        : DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'uuid': uuid,
    'email': email,
    'phone': phone,
    'first_name': firstName,
    'last_name': lastName,
    'is_verified': isVerified,
    'email_verified_at': emailVerifiedAt?.toIso8601String(),
    'phone_verified_at': phoneVerifiedAt?.toIso8601String(),
    'profile_picture': profilePicture,
    'status': status,
    'last_login_at': lastLoginAt?.toIso8601String(),
    'role': role.name,
    'trust_score': trustScore,
    'completed_trips': completedTrips,
    'total_trips': totalTrips,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  String get fullName {
    final first = firstName ?? '';
    final last = lastName ?? '';
    return '$first $last'.trim().isNotEmpty ? '$first $last'.trim() : email;
  }

  String get displayName => fullName.isNotEmpty ? fullName : email;

  bool get isPhoneVerified => phoneVerifiedAt != null;
  bool get isEmailVerified => emailVerifiedAt != null;
  bool get isFullyVerified => isVerified && isPhoneVerified;

  // Role checks
  bool get isAdmin => role == UserRole.admin;
  bool get isModerator => role == UserRole.moderator;
  bool get isUser => role == UserRole.user;
  bool get canModerate => role == UserRole.admin || role == UserRole.moderator;

  // Trust score analysis
  TrustLevel get trustLevel {
    if (trustScore < 30) return TrustLevel.newUser;
    if (trustScore <= 70) return TrustLevel.verified;
    return TrustLevel.established;
  }

  // Trip approval rules
  bool needsManualApproval(String transportType) {
    switch (trustLevel) {
      case TrustLevel.newUser:
        // Premier voyage avion = révision manuelle
        if (transportType.toLowerCase() == 'plane' && totalTrips == 0) {
          return true;
        }
        // Autres transports = publication immédiate avec flag review
        return false;
      case TrustLevel.verified:
      case TrustLevel.established:
        return false;
    }
  }

  bool needsReviewFlag(String transportType) {
    if (trustLevel == TrustLevel.newUser) {
      // Tous les premiers voyages (sauf avion qui va en révision manuelle)
      return transportType.toLowerCase() != 'plane';
    }
    return false;
  }

  bool canAutoPublish(String transportType) {
    return !needsManualApproval(transportType);
  }

  User copyWith({
    int? id,
    String? uuid,
    String? email,
    String? phone,
    String? firstName,
    String? lastName,
    bool? isVerified,
    DateTime? emailVerifiedAt,
    DateTime? phoneVerifiedAt,
    String? profilePicture,
    String? status,
    DateTime? lastLoginAt,
    UserRole? role,
    int? trustScore,
    int? completedTrips,
    int? totalTrips,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      isVerified: isVerified ?? this.isVerified,
      emailVerifiedAt: emailVerifiedAt ?? this.emailVerifiedAt,
      phoneVerifiedAt: phoneVerifiedAt ?? this.phoneVerifiedAt,
      profilePicture: profilePicture ?? this.profilePicture,
      status: status ?? this.status,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      role: role ?? this.role,
      trustScore: trustScore ?? this.trustScore,
      completedTrips: completedTrips ?? this.completedTrips,
      totalTrips: totalTrips ?? this.totalTrips,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User &&
        other.id == id &&
        other.uuid == uuid &&
        other.email == email;
  }

  @override
  int get hashCode => id.hashCode ^ uuid.hashCode ^ email.hashCode;

  @override
  String toString() {
    return 'User(id: $id, uuid: $uuid, email: $email, fullName: $fullName)';
  }
}

class AuthTokens {
  final String accessToken;
  final String? refreshToken;
  final String tokenType;
  final int expiresIn;

  const AuthTokens({
    required this.accessToken,
    this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
    accessToken: json['access_token'] as String,
    refreshToken: json['refresh_token'] as String?,
    tokenType: json['token_type'] as String? ?? 'Bearer',
    expiresIn: json['expires_in'] as int,
  );

  Map<String, dynamic> toJson() => {
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'token_type': tokenType,
    'expires_in': expiresIn,
  };

  DateTime get expiryDate => DateTime.now().add(Duration(seconds: expiresIn));
  bool get isExpired => DateTime.now().isAfter(expiryDate);

  @override
  String toString() {
    return 'AuthTokens(tokenType: $tokenType, expiresIn: $expiresIn)';
  }
}

class AuthResponse {
  final User user;
  final AuthTokens tokens;

  const AuthResponse({
    required this.user,
    required this.tokens,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
    user: User.fromJson(json['user'] as Map<String, dynamic>),
    tokens: AuthTokens.fromJson(json['tokens'] as Map<String, dynamic>),
  );

  Map<String, dynamic> toJson() => {
    'user': user.toJson(),
    'tokens': tokens.toJson(),
  };

  @override
  String toString() {
    return 'AuthResponse(user: ${user.email}, hasTokens: ${tokens.accessToken.isNotEmpty})';
  }
}

class RegisterRequest {
  final String email;
  final String password;
  final String? phone;
  final String firstName;
  final String lastName;

  const RegisterRequest({
    required this.email,
    required this.password,
    this.phone,
    required this.firstName,
    required this.lastName,
  });

  factory RegisterRequest.fromJson(Map<String, dynamic> json) => RegisterRequest(
    email: json['email'] as String,
    password: json['password'] as String,
    phone: json['phone'] as String?,
    firstName: json['first_name'] as String,
    lastName: json['last_name'] as String,
  );

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'email': email,
      'password': password,
      'first_name': firstName,
      'last_name': lastName,
    };
    
    if (phone != null && phone!.isNotEmpty) {
      json['phone'] = phone;
    }
    
    return json;
  }
}

class LoginRequest {
  final String email;
  final String password;

  const LoginRequest({
    required this.email,
    required this.password,
  });

  factory LoginRequest.fromJson(Map<String, dynamic> json) => LoginRequest(
    email: json['email'] as String,
    password: json['password'] as String,
  );

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
  };
}

class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final String? errorCode;

  const ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.errorCode,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json, T Function(Object? json) fromJsonT) =>
      ApiResponse<T>(
        success: json['success'] as bool,
        message: json['message'] as String,
        data: json['data'] == null ? null : fromJsonT(json['data']),
        errorCode: json['error_code'] as String?,
      );

  Map<String, dynamic> toJson(Object Function(T value) toJsonT) => <String, dynamic>{
        'success': success,
        'message': message,
        'data': data == null ? null : toJsonT(data as T),
        'error_code': errorCode,
      };
}