import 'package:flutter/material.dart';
import '../modules/profile/models/user_profile.dart';

/// Widget de debug pour afficher les informations du profil utilisateur
class ProfileDebugWidget extends StatelessWidget {
  final UserProfile? profile;
  
  const ProfileDebugWidget({super.key, this.profile});

  @override
  Widget build(BuildContext context) {
    if (profile == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: Text(
            '🚫 DEBUG: Profile is null',
            style: TextStyle(color: Colors.red, fontSize: 12),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🛠️ PROFILE DEBUG INFO',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const Divider(),
            _buildDebugRow('ID', profile!.id.toString()),
            _buildDebugRow('First Name', profile!.firstName ?? 'null'),
            _buildDebugRow('Last Name', profile!.lastName ?? 'null'),
            _buildDebugRow('Display Name', profile!.displayName),
            const Divider(),
            _buildDebugRow('Avatar URL', profile!.avatarUrl ?? 'null', isLong: true),
            if (profile!.avatarUrl != null) ...[
              const SizedBox(height: 8),
              Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: profile!.avatarUrl!.isNotEmpty 
                    ? Image.network(
                        profile!.avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.red[100],
                            child: const Icon(Icons.error, size: 20),
                          );
                        },
                      )
                    : const Icon(Icons.person, size: 20),
              ),
            ],
            const Divider(),
            _buildDebugRow('Profile Type', profile.runtimeType.toString()),
            _buildDebugRow('Is Verified', profile!.isVerified.toString()),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugRow(String label, String value, {bool isLong = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.blue,
              ),
            ),
          ),
          Expanded(
            child: Text(
              isLong && value.length > 50 
                  ? '${value.substring(0, 50)}...' 
                  : value,
              style: TextStyle(
                fontSize: 12,
                color: value == 'null' ? Colors.red : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}