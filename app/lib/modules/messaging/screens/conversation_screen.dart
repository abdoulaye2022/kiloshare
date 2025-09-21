import 'package:flutter/material.dart';
import 'dart:async';
import '../services/messaging_service.dart';
import '../../auth/services/auth_service.dart';
import '../../../themes/modern_theme.dart';
import 'conversations_list_screen.dart';

class ConversationScreen extends StatefulWidget {
  final String? conversationId;
  final String tripId;
  final String tripOwnerId;
  final String tripTitle;

  const ConversationScreen({
    super.key,
    this.conversationId,
    required this.tripId,
    required this.tripOwnerId,
    required this.tripTitle,
  });

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final MessagingService _messagingService = MessagingService();
  final AuthService _authService = AuthService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<Map<String, dynamic>> _messages = [];
  String? _conversationId;
  String? _currentUserId;
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    // Rafraîchir la liste des conversations quand on quitte cet écran
    ConversationsListScreen.refresh();
    super.dispose();
  }

  Future<void> _initializeUser() async {
    try {
      final user = await _authService.getCurrentUser();
      if (user != null) {
        _currentUserId = user.id.toString();
      }
    } catch (e) {
    }
    _initializeConversation();
  }

  Future<void> _initializeConversation() async {
    try {
      // Si on a déjà un conversationId, on l'utilise directement
      if (widget.conversationId != null) {
        _conversationId = widget.conversationId!;
        await _loadMessages();
        _startAutoRefresh();
        return;
      }
      
      // Sinon, on crée ou récupère la conversation
      final result = await _messagingService.getOrCreateConversation(
        tripId: widget.tripId,
        tripOwnerId: widget.tripOwnerId,
      );

      if (result['success'] == true) {
        _conversationId = result['conversation']['id'].toString();
        await _loadMessages();
        _startAutoRefresh();
      } else {
        setState(() {
          _error = result['error'] ?? 'Failed to create conversation';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMessages() async {
    if (_conversationId == null) return;

    try {
      final result = await _messagingService.getMessages(
        conversationId: _conversationId!,
      );


      if (result['success'] == true) {
        final messages = List<Map<String, dynamic>>.from(result['data']?['data']?['messages'] ?? []);
        
        setState(() {
          _messages = messages;
          _isLoading = false;
          _error = null;
        });
        _scrollToBottom();
      } else {
        setState(() {
          _error = result['error'] ?? 'Failed to load messages';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && _conversationId != null) {
        _loadMessages();
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _conversationId == null) return;

    setState(() {
      _isSending = true;
    });

    try {
      final result = await _messagingService.sendMessage(
        conversationId: _conversationId!,
        content: _messageController.text.trim(),
      );

      if (result['success'] == true) {
        _messageController.clear();
        await _loadMessages();
        // Rafraîchir la liste des conversations pour mettre à jour le dernier message
        ConversationsListScreen.refresh();
      } else {
        _showErrorSnackBar(result['error'] ?? 'Failed to send message');
      }
    } catch (e) {
      _showErrorSnackBar(e.toString());
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Conversation'),
            Text(
              widget.tripTitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        elevation: 1,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Erreur de chargement',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _initializeConversation();
              },
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty ? _buildEmptyState() : _buildMessagesList(),
        ),
        _buildMessageInput(),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Aucun message',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Envoyez le premier message pour commencer la conversation',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return _buildMessageBubble(message);
      },
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isMe = _currentUserId != null && message['sender_id'].toString() == _currentUserId;
    final content = message['content'] ?? '';
    final timestamp = message['created_at'] ?? '';
    final senderName = '${message['first_name'] ?? ''} ${message['last_name'] ?? ''}'.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ModernTheme.spacing8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            // Avatar pour les messages reçus
            Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(right: ModernTheme.spacing8, bottom: 4),
              decoration: BoxDecoration(
                color: ModernTheme.primaryBlue,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                child: Text(
                  senderName.isNotEmpty ? senderName[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.all(ModernTheme.spacing12),
              decoration: BoxDecoration(
                color: isMe ? ModernTheme.primaryBlue : ModernTheme.gray100,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(ModernTheme.radiusLarge),
                  topRight: const Radius.circular(ModernTheme.radiusLarge),
                  bottomLeft: Radius.circular(isMe ? ModernTheme.radiusLarge : ModernTheme.radiusSmall),
                  bottomRight: Radius.circular(isMe ? ModernTheme.radiusSmall : ModernTheme.radiusLarge),
                ),
                boxShadow: [
                  BoxShadow(
                    color: ModernTheme.black.withOpacity(0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isMe && senderName.isNotEmpty) ...[
                    Text(
                      senderName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: ModernTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    content,
                    style: TextStyle(
                      color: isMe ? Colors.white : ModernTheme.gray900,
                      fontSize: 16,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTimestamp(timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: isMe ? Colors.white.withOpacity(0.8) : ModernTheme.gray500,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.check,
                          size: 14,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: ModernTheme.spacing8),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Tapez votre message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: Theme.of(context).primaryColor,
            child: _isSending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _isSending ? null : _sendMessage,
                  ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return '${difference.inDays}j';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m';
      } else {
        return 'maintenant';
      }
    } catch (e) {
      return '';
    }
  }
}