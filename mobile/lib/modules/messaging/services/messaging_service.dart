import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/app_config.dart';
import '../../auth/services/auth_service.dart';

class MessagingService {
  final AuthService _authService = AuthService();

  /// Get list of conversations for the current user
  Future<Map<String, dynamic>> getConversations({int page = 1, int limit = 20}) async {
    try {
      final token = await _authService.getValidAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('Authentication required. Please log in again.');
      }

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/messages/conversations?page=$page&limit=$limit'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print('📱 [MessagingService] getConversations response: ${response.statusCode}');
      print('📱 [MessagingService] getConversations body: ${response.body}');

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Erreur lors du chargement des conversations',
        };
      }
    } catch (e) {
      print('❌ [MessagingService] Error getting conversations: $e');
      return {
        'success': false,
        'message': 'Erreur de connexion: $e',
      };
    }
  }

  /// Create or get conversation for a trip
  Future<Map<String, dynamic>> getOrCreateConversation({
    required String tripId,
    required String tripOwnerId,
  }) async {
    try {
      final token = await _authService.getValidAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('Authentication required. Please log in again.');
      }

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/conversations'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'trip_id': tripId,
          'trip_owner_id': tripOwnerId,
        }),
      );

      print('📱 [MessagingService] getOrCreateConversation response: ${response.statusCode}');
      print('📱 [MessagingService] getOrCreateConversation body: ${response.body}');

      final data = json.decode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Erreur lors de la création de la conversation',
        };
      }
    } catch (e) {
      print('❌ [MessagingService] Error creating conversation: $e');
      return {
        'success': false,
        'message': 'Erreur de connexion: $e',
      };
    }
  }

  /// Get messages for a conversation
  Future<Map<String, dynamic>> getMessages({
    required String conversationId,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final token = await _authService.getValidAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('Authentication required. Please log in again.');
      }

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/conversations/$conversationId/messages?page=$page&limit=$limit'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print('📱 [MessagingService] getMessages response: ${response.statusCode}');
      print('📱 [MessagingService] getMessages body: ${response.body}');

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Erreur lors du chargement des messages',
        };
      }
    } catch (e) {
      print('❌ [MessagingService] Error getting messages: $e');
      return {
        'success': false,
        'message': 'Erreur de connexion: $e',
      };
    }
  }

  /// Send a message to a conversation
  Future<Map<String, dynamic>> sendMessage({
    required String conversationId,
    required String content,
    String messageType = 'text',
  }) async {
    try {
      final token = await _authService.getValidAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('Authentication required. Please log in again.');
      }

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/conversations/$conversationId/messages'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'content': content,
          'message_type': messageType,
        }),
      );

      print('📱 [MessagingService] sendMessage response: ${response.statusCode}');
      print('📱 [MessagingService] sendMessage body: ${response.body}');

      final data = json.decode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Erreur lors de l\'envoi du message',
        };
      }
    } catch (e) {
      print('❌ [MessagingService] Error sending message: $e');
      return {
        'success': false,
        'message': 'Erreur de connexion: $e',
      };
    }
  }
}