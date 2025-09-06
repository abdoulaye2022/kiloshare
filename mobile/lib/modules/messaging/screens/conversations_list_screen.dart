import 'package:flutter/material.dart';
import '../../../themes/modern_theme.dart';
import '../services/messaging_service.dart';
import 'conversation_screen.dart';

class ConversationsListScreen extends StatefulWidget {
  const ConversationsListScreen({super.key});

  @override
  State<ConversationsListScreen> createState() => _ConversationsListScreenState();

  /// Méthode statique pour rafraîchir la liste des conversations depuis d'autres écrans
  static void refresh() {
    _ConversationsListScreenState.refresh();
  }
}

class _ConversationsListScreenState extends State<ConversationsListScreen> with WidgetsBindingObserver {
  final MessagingService _messagingService = MessagingService();
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;
  String? _error;
  bool _hasInitialized = false;

  // Instance statique pour permettre le refresh depuis d'autres écrans
  static _ConversationsListScreenState? _currentInstance;

  @override
  void initState() {
    super.initState();
    print('📱 [ConversationsListScreen] initState - Starting to load conversations');
    _currentInstance = this;
    WidgetsBinding.instance.addObserver(this);
    _loadConversations();
    _hasInitialized = true;
  }

  @override
  void dispose() {
    _currentInstance = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Méthode statique pour rafraîchir depuis d'autres écrans
  static void refresh() {
    if (_currentInstance != null && _currentInstance!.mounted) {
      _currentInstance!._loadConversations(silent: true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Rafraîchir quand l'app revient au premier plan
    if (state == AppLifecycleState.resumed && _hasInitialized) {
      print('📱 [ConversationsListScreen] App resumed, refreshing conversations');
      _loadConversations(silent: true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Rafraîchir quand on revient sur cette page (changement d'onglet)
    if (_hasInitialized && ModalRoute.of(context)?.isCurrent == true) {
      print('📱 [ConversationsListScreen] Tab focused, refreshing conversations');
      _loadConversations(silent: true);
    }
  }

  Future<void> _loadConversations({bool silent = false}) async {
    try {
      if (!silent) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }

      final response = await _messagingService.getConversations();
      
      print('📱 [ConversationsListScreen] Response: $response');
      print('📱 [ConversationsListScreen] Success: ${response['success']}');
      print('📱 [ConversationsListScreen] Data: ${response['data']}');
      print('📱 [ConversationsListScreen] Conversations: ${response['data']?['data']?['conversations']}');
      
      if (response['success'] == true) {
        final conversations = List<Map<String, dynamic>>.from(response['data']['data']['conversations'] ?? []);
        print('📱 [ConversationsListScreen] Parsed conversations count: ${conversations.length}');
        
        setState(() {
          _conversations = conversations;
          if (!silent) _isLoading = false;
        });
      } else {
        if (!silent) {
          setState(() {
            _error = response['message'] ?? 'Erreur lors du chargement des conversations';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('📱 [ConversationsListScreen] Exception caught: $e');
      if (!silent) {
        setState(() {
          _error = 'Erreur: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.gray50,
      appBar: AppBar(
        title: const Text(
          'Messages',
          style: TextStyle(
            color: ModernTheme.gray900,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: ModernTheme.white,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    print('📱 [ConversationsListScreen] _buildBody - isLoading: $_isLoading, error: $_error, conversations count: ${_conversations.length}');
    
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: ModernTheme.primaryBlue,
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(ModernTheme.spacing24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: ModernTheme.error,
              ),
              const SizedBox(height: ModernTheme.spacing16),
              Text(
                _error!,
                style: const TextStyle(
                  color: ModernTheme.gray600,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: ModernTheme.spacing16),
              ElevatedButton(
                onPressed: _loadConversations,
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    if (_conversations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(ModernTheme.spacing24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(ModernTheme.spacing24),
                decoration: BoxDecoration(
                  color: ModernTheme.lightBlue.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(ModernTheme.radiusXLarge),
                ),
                child: const Icon(
                  Icons.message_outlined,
                  size: 64,
                  color: ModernTheme.primaryBlue,
                ),
              ),
              const SizedBox(height: ModernTheme.spacing24),
              const Text(
                'Aucune conversation',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: ModernTheme.gray900,
                ),
              ),
              const SizedBox(height: ModernTheme.spacing12),
              const Text(
                'Vous n\'avez pas encore de conversations.\nContactez des propriétaires de voyages pour commencer!',
                style: TextStyle(
                  color: ModernTheme.gray600,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadConversations,
      child: ListView.builder(
        padding: const EdgeInsets.all(ModernTheme.spacing16),
        itemCount: _conversations.length,
        itemBuilder: (context, index) {
          final conversation = _conversations[index];
          return _ConversationItem(
            conversation: conversation,
            onTap: () => _openConversation(conversation),
          );
        },
      ),
    );
  }

  void _openConversation(Map<String, dynamic> conversation) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConversationScreen(
          conversationId: conversation['id']?.toString(),
          tripId: conversation['trip_id']?.toString() ?? '',
          tripOwnerId: conversation['other_user_id']?.toString() ?? '',
          tripTitle: '${conversation['departure_city'] ?? ''} → ${conversation['arrival_city'] ?? ''}',
        ),
      ),
    );
  }
}

class _ConversationItem extends StatelessWidget {
  final Map<String, dynamic> conversation;
  final VoidCallback onTap;

  const _ConversationItem({
    required this.conversation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final otherUserName = '${conversation['other_user_first_name'] ?? ''} ${conversation['other_user_last_name'] ?? ''}'.trim();
    final tripRoute = '${conversation['departure_city'] ?? ''} → ${conversation['arrival_city'] ?? ''}';
    final lastMessage = conversation['last_message'] as String?;
    final messageCount = conversation['message_count'] as int? ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: ModernTheme.spacing12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: ModernTheme.primaryBlue,
          child: Text(
            otherUserName.isNotEmpty ? otherUserName[0].toUpperCase() : 'U',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          otherUserName.isNotEmpty ? otherUserName : 'Utilisateur inconnu',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tripRoute,
              style: TextStyle(
                color: ModernTheme.primaryBlue,
                fontSize: 12,
              ),
            ),
            if (lastMessage != null && lastMessage.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                lastMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: ModernTheme.gray600,
                ),
              ),
            ],
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (messageCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ModernTheme.primaryBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  messageCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}