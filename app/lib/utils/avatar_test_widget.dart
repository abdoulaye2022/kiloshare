import 'package:flutter/material.dart';
import '../modules/profile/widgets/avatar_picker_widget.dart';
import '../modules/profile/screens/avatar_edit_screen.dart';

/// Widget de test pour l'upload d'avatar
/// À utiliser pendant le développement pour tester la fonctionnalité
class AvatarTestWidget extends StatefulWidget {
  const AvatarTestWidget({super.key});

  @override
  State<AvatarTestWidget> createState() => _AvatarTestWidgetState();
}

class _AvatarTestWidgetState extends State<AvatarTestWidget> {
  String? _currentAvatarUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '🧪 Test Upload Avatar',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          // Widget avatar picker
          AvatarPickerWidget(
            currentAvatarUrl: _currentAvatarUrl,
            size: 100,
            isEditable: true,
            onAvatarChanged: (newAvatarUrl) {
              setState(() {
                _currentAvatarUrl = newAvatarUrl;
              });
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Avatar mis à jour: ${newAvatarUrl.length > 50 ? "${newAvatarUrl.substring(0, 50)}..." : newAvatarUrl}'),
                  backgroundColor: Colors.green,
                ),
              );
            },
          ),
          
          const SizedBox(height: 16),
          
          // Bouton pour ouvrir l'écran d'édition
          ElevatedButton(
            onPressed: () async {
              final result = await Navigator.of(context).push<String>(
                MaterialPageRoute(
                  builder: (context) => AvatarEditScreen(
                    userProfile: null, // Test sans profil existant
                  ),
                ),
              );
              
              if (result != null && result.isNotEmpty) {
                setState(() {
                  _currentAvatarUrl = result;
                });
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Avatar édité avec succès'),
                      backgroundColor: Colors.blue,
                    ),
                  );
                }
              }
            },
            child: const Text('Ouvrir éditeur d\'avatar'),
          ),
          
          const SizedBox(height: 8),
          
          // Informations sur l'avatar actuel
          if (_currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty) ...[
            const Text('Avatar actuel:'),
            Text(
              _currentAvatarUrl!.length > 60 
                ? '${_currentAvatarUrl!.substring(0, 60)}...'
                : _currentAvatarUrl!,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ] else
            const Text(
              'Aucun avatar sélectionné',
              style: TextStyle(color: Colors.grey),
            ),
        ],
      ),
    );
  }
}