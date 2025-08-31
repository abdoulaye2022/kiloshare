import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../modules/auth/blocs/auth/auth_bloc.dart';
import '../modules/auth/blocs/auth/auth_state.dart';
import '../modules/auth/services/auth_service.dart';

class DebugAuthStatus extends StatelessWidget {
  const DebugAuthStatus({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.yellow[100],
            border: Border.all(color: Colors.orange),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '🐛 DEBUG AUTH STATUS',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red[800],
                ),
              ),
              const SizedBox(height: 8),
              Text('BLoC State: ${state.runtimeType}'),
              if (state is AuthAuthenticated) ...[
                Text('User: ${state.user.firstName} ${state.user.lastName}'),
                Text('Email: ${state.user.email}'),
                Text('Token Length: ${state.accessToken.length}'),
                Text('Token Preview: ${state.accessToken.substring(0, 20)}...'),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () => _testTokenStorage(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    child: const Text('Test Storage', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _clearStorage(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    child: const Text('Clear Storage', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _testTokenStorage() async {
    final authService = AuthService.instance;
    final token = await authService.getAccessToken();
    final refreshToken = await authService.getRefreshToken();
    final user = await authService.getCurrentUser();
    
    print('=== DEBUG AUTH STORAGE ===');
    print('Access Token: ${token != null ? "${token.length} chars" : "NULL"}');
    print('Refresh Token: ${refreshToken != null ? "${refreshToken.length} chars" : "NULL"}');
    print('User Data: ${user != null ? "${user.email}" : "NULL"}');
    print('========================');
  }

  void _clearStorage() async {
    final authService = AuthService.instance;
    await authService.clearTokens();
    print('Storage cleared!');
  }
}