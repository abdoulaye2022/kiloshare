import 'package:dio/dio.dart';
import '../models/user_model.dart';

class PhoneAuthService {
  final Dio _dio;

  PhoneAuthService(this._dio);

  /// Envoie un code de vérification SMS
  Future<PhoneCodeResult> sendVerificationCode(String phoneNumber) async {
    try {
      print('📞 Sending SMS verification code to: $phoneNumber');

      final response = await _dio.post(
        '/auth/phone/send-code',
        data: {
          'phone_number': phoneNumber,
        },
      );

      print('✅ SMS verification code sent successfully');
      print('📋 Response data: ${response.data}');

      if (response.data['success'] != true) {
        throw Exception(response.data['message'] ?? 'Failed to send code');
      }

      return PhoneCodeResult(
        success: true,
        message: response.data['data']['message'],
        phoneNumber: response.data['data']['phone'],
      );
    } on DioException catch (e) {
      print('❌ SMS API Error: ${e.response?.data}');

      String errorMessage = 'Erreur réseau lors de l\'envoi du SMS';
      if (e.response?.data != null && e.response!.data['message'] != null) {
        errorMessage = e.response!.data['message'];
      }

      return PhoneCodeResult(
        success: false,
        message: errorMessage,
      );
    } catch (e) {
      print('❌ SMS General Error: $e');
      return PhoneCodeResult(
        success: false,
        message: 'Erreur lors de l\'envoi du SMS',
      );
    }
  }

  /// Vérifie le code SMS et authentifie l'utilisateur
  Future<AuthResponse> verifyCodeAndLogin({
    required String phoneNumber,
    required String code,
    String? firstName,
    String? lastName,
  }) async {
    try {
      print('🔍 Verifying SMS code for: $phoneNumber');

      final requestData = {
        'phone_number': phoneNumber,
        'code': code,
      };

      // Ajouter les noms si fournis
      if (firstName != null && firstName.isNotEmpty) {
        requestData['first_name'] = firstName;
      }
      if (lastName != null && lastName.isNotEmpty) {
        requestData['last_name'] = lastName;
      }

      print('📤 Request data: $requestData');

      final response = await _dio.post(
        '/auth/phone/verify-login',
        data: requestData,
      );

      print('✅ SMS verification successful');
      print('📋 Response data: ${response.data}');

      if (response.data['success'] != true) {
        throw Exception(response.data['message'] ?? 'Code verification failed');
      }

      return AuthResponse.fromJson(response.data['data']);
    } on DioException catch (e) {
      print('❌ SMS Verification API Error: ${e.response?.data}');

      if (e.response?.data != null && e.response!.data['message'] != null) {
        throw Exception(e.response!.data['message']);
      }

      throw Exception('Erreur réseau lors de la vérification');
    } catch (e) {
      print('❌ SMS Verification Error: $e');
      rethrow;
    }
  }

  /// Valide le format d'un numéro de téléphone (France, USA, Canada)
  static bool validatePhoneNumber(String phoneNumber) {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\+\d]'), '');

    final patterns = [
      // France : +33 X XX XX XX XX ou 0X XX XX XX XX
      RegExp(r'^(\+33[1-9]\d{8}|0[1-9]\d{8})$'),
      // États-Unis/Canada : +1 XXX XXX XXXX, 1 XXX XXX XXXX ou XXX XXX XXXX (10 chiffres)
      RegExp(r'^(\+1[2-9]\d{2}\d{7}|1[2-9]\d{2}\d{7}|[2-9]\d{2}\d{7})$'),
      // Format international général (10-15 chiffres avec +)
      RegExp(r'^\+\d{10,15}$'),
    ];

    return patterns.any((pattern) => pattern.hasMatch(cleanNumber));
  }

  /// Formate un numéro de téléphone pour l'affichage
  static String formatPhoneNumber(String phoneNumber) {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    if (cleanNumber.length == 10 && cleanNumber.startsWith('0')) {
      // Format français: 06 12 34 56 78
      return '${cleanNumber.substring(0, 2)} ${cleanNumber.substring(2, 4)} '
          '${cleanNumber.substring(4, 6)} ${cleanNumber.substring(6, 8)} '
          '${cleanNumber.substring(8, 10)}';
    }

    if (cleanNumber.length == 10 && !cleanNumber.startsWith('0')) {
      // Format nord-américain: (123) 456-7890
      return '(${cleanNumber.substring(0, 3)}) ${cleanNumber.substring(3, 6)}-${cleanNumber.substring(6, 10)}';
    }

    if (cleanNumber.length == 11 && cleanNumber.startsWith('1')) {
      // Format nord-américain avec 1: 1 (123) 456-7890
      return '${cleanNumber.substring(0, 1)} (${cleanNumber.substring(1, 4)}) ${cleanNumber.substring(4, 7)}-${cleanNumber.substring(7, 11)}';
    }

    return phoneNumber; // Retourner tel quel si pas de format reconnu
  }
}

/// Résultat de l'envoi d'un code SMS
class PhoneCodeResult {
  final bool success;
  final String message;
  final String? phoneNumber;

  PhoneCodeResult({
    required this.success,
    required this.message,
    this.phoneNumber,
  });
}
