import 'package:flutter/material.dart';
import '../widgets/avatar_picker_widget.dart';
import '../services/profile_service.dart';
import '../models/user_profile.dart';

class AvatarEditScreen extends StatefulWidget {
  final UserProfile? userProfile;
  
  const AvatarEditScreen({
    super.key,
    this.userProfile,
  });

  @override
  State<AvatarEditScreen> createState() => _AvatarEditScreenState();
}

class _AvatarEditScreenState extends State<AvatarEditScreen> {
  final ProfileService _profileService = ProfileService();
  String? _currentAvatarUrl;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _currentAvatarUrl = widget.userProfile?.avatarUrl;
  }

  void _onAvatarChanged(String newAvatarUrl) {
    setState(() {
      _currentAvatarUrl = newAvatarUrl;
      _hasChanges = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo de profil'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (_hasChanges) {
              _showUnsavedChangesDialog();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: () {
                Navigator.pop(context, _currentAvatarUrl);
              },
              child: const Text(
                'Terminé',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Votre photo de profil',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ajoutez une photo pour que les autres utilisateurs puissent vous reconnaître',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 40),
            
            AvatarPickerWidget(
              currentAvatarUrl: _currentAvatarUrl,
              size: 200,
              isEditable: true,
              onAvatarChanged: _onAvatarChanged,
            ),
            
            const SizedBox(height: 40),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const Text(
                    'Conseils pour une bonne photo :',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Icon(Icons.check, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text('Utilisez une photo récente de votre visage'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      Icon(Icons.check, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text('Assurez-vous que la photo est bien éclairée'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      Icon(Icons.check, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text('Évitez les lunettes de soleil ou les masques'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  if (!_hasChanges)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Continuer sans photo'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUnsavedChangesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifications non sauvegardées'),
        content: const Text(
          'Vous avez modifié votre photo de profil. Voulez-vous sauvegarder les modifications ?'
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Fermer le dialog
              Navigator.pop(context); // Fermer l'écran sans sauvegarder
            },
            child: const Text('Ignorer'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context); // Fermer le dialog
              Navigator.pop(context, _currentAvatarUrl); // Sauvegarder
            },
            child: const Text('Sauvegarder'),
          ),
        ],
      ),
    );
  }
}