import 'package:flutter/material.dart';
import '../modules/profile/widgets/avatar_picker_widget.dart';
import '../modules/profile/widgets/avatar_display_widget.dart';

/// Page de test pour les widgets d'avatar
class AvatarDisplayTestPage extends StatefulWidget {
  const AvatarDisplayTestPage({super.key});

  @override
  State<AvatarDisplayTestPage> createState() => _AvatarDisplayTestPageState();
}

class _AvatarDisplayTestPageState extends State<AvatarDisplayTestPage> {
  String? _testAvatarUrl;
  
  // URL d'exemple pour les tests
  static const String _exampleAvatarUrl = 'https://res.cloudinary.com/dvqisegwj/image/upload/c_fill,g_face,h_400,q_auto:good,w_400/kiloshare/avatars/avatars/user_1.jpg';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test des Avatars'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🧪 Test des Widgets Avatar',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            // Section AvatarPickerWidget
            _buildSection(
              title: 'AvatarPickerWidget (Éditable)',
              child: Column(
                children: [
                  AvatarPickerWidget(
                    currentAvatarUrl: _testAvatarUrl,
                    size: 120,
                    isEditable: true,
                    onAvatarChanged: (newUrl) {
                      setState(() {
                        _testAvatarUrl = newUrl;
                      });
                      _showSnackBar('Avatar mis à jour !', Colors.green);
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Cliquez pour changer l\'avatar',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Section AvatarDisplayWidget
            _buildSection(
              title: 'AvatarDisplayWidget (Lecture seule)',
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          AvatarDisplayWidget(
                            avatarUrl: _testAvatarUrl,
                            userName: 'John Doe',
                            size: 80,
                            borderColor: Colors.blue,
                            borderWidth: 2,
                          ),
                          const SizedBox(height: 8),
                          const Text('Avec avatar', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                      Column(
                        children: [
                          const AvatarDisplayWidget(
                            avatarUrl: null,
                            userName: 'Jane Smith',
                            size: 80,
                            borderColor: Colors.green,
                            borderWidth: 2,
                          ),
                          const SizedBox(height: 8),
                          const Text('Sans avatar', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                      Column(
                        children: [
                          const AvatarDisplayWidget(
                            avatarUrl: null,
                            userName: null,
                            size: 80,
                            borderColor: Colors.red,
                            borderWidth: 2,
                          ),
                          const SizedBox(height: 8),
                          const Text('Défaut', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Section Différentes tailles
            _buildSection(
              title: 'Différentes Tailles',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      AvatarDisplayWidget(
                        avatarUrl: _exampleAvatarUrl,
                        userName: 'Small',
                        size: 40,
                      ),
                      const SizedBox(height: 4),
                      const Text('40px', style: TextStyle(fontSize: 10)),
                    ],
                  ),
                  Column(
                    children: [
                      AvatarDisplayWidget(
                        avatarUrl: _exampleAvatarUrl,
                        userName: 'Medium',
                        size: 60,
                      ),
                      const SizedBox(height: 4),
                      const Text('60px', style: TextStyle(fontSize: 10)),
                    ],
                  ),
                  Column(
                    children: [
                      AvatarDisplayWidget(
                        avatarUrl: _exampleAvatarUrl,
                        userName: 'Large',
                        size: 100,
                      ),
                      const SizedBox(height: 4),
                      const Text('100px', style: TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Actions de test
            _buildSection(
              title: 'Actions de Test',
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _testAvatarUrl = _exampleAvatarUrl;
                        });
                        _showSnackBar('Avatar d\'exemple défini', Colors.blue);
                      },
                      child: const Text('Définir Avatar d\'Exemple'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _testAvatarUrl = null;
                        });
                        _showSnackBar('Avatar supprimé', Colors.orange);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                      child: const Text('Supprimer Avatar'),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Informations sur l'avatar actuel
            if (_testAvatarUrl != null) ...[
              _buildSection(
                title: 'Avatar Actuel',
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _testAvatarUrl!.length > 100 
                        ? '${_testAvatarUrl!.substring(0, 100)}...'
                        : _testAvatarUrl!,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: child,
        ),
      ],
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.fixed,
      ),
    );
  }
}