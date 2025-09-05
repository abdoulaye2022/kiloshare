import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../widgets/optimized_cloudinary_image.dart';
import '../services/profile_service.dart';

class AvatarPickerWidget extends StatefulWidget {
  final String? currentAvatarUrl;
  final Function(String newAvatarUrl)? onAvatarChanged;
  final double size;
  final bool isEditable;

  const AvatarPickerWidget({
    super.key,
    this.currentAvatarUrl,
    this.onAvatarChanged,
    this.size = 120.0,
    this.isEditable = true,
  });

  @override
  State<AvatarPickerWidget> createState() => _AvatarPickerWidgetState();
}

class _AvatarPickerWidgetState extends State<AvatarPickerWidget> {
  final ImagePicker _picker = ImagePicker();
  final ProfileService _profileService = ProfileService();
  
  bool _isUploading = false;
  String? _currentAvatarUrl;

  @override
  void initState() {
    super.initState();
    _currentAvatarUrl = widget.currentAvatarUrl;
    debugPrint('🎭 AvatarPickerWidget - Initial URL: $_currentAvatarUrl');
  }

  @override
  void didUpdateWidget(AvatarPickerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentAvatarUrl != widget.currentAvatarUrl) {
      _currentAvatarUrl = widget.currentAvatarUrl;
      debugPrint('🔄 AvatarPickerWidget - Updated URL: $_currentAvatarUrl');
    }
  }

  Future<void> _showImageSourceActionSheet() async {
    if (!widget.isEditable || _isUploading) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Changer la photo de profil',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            
            // Option Caméra
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.camera_alt, color: Colors.blue),
              ),
              title: const Text('Prendre une photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            
            // Option Galerie
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.photo_library, color: Colors.green),
              ),
              title: const Text('Choisir depuis la galerie'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            
            // Option Supprimer (si avatar existe)
            if (_currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.delete, color: Colors.red),
                ),
                title: const Text('Supprimer la photo'),
                onTap: () {
                  Navigator.pop(context);
                  _removeAvatar();
                },
              ),
            
            const SizedBox(height: 10),
            
            // Bouton Annuler
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image != null) {
        await _uploadAvatar(File(image.path));
      }
    } catch (e) {
      _showErrorSnackBar('Erreur lors de la sélection de l\'image: $e');
    }
  }

  Future<void> _uploadAvatar(File imageFile) async {
    setState(() {
      _isUploading = true;
    });

    try {
      // Vérifier la taille du fichier (5MB max)
      final fileSize = await imageFile.length();
      if (fileSize > 5 * 1024 * 1024) {
        throw Exception('La taille de l\'image doit être inférieure à 5MB');
      }

      final result = await _profileService.uploadAvatar(imageFile);
      
      if (result['profile_picture'] != null) {
        setState(() {
          _currentAvatarUrl = result['profile_picture'];
        });
        
        // Notifier le parent du changement
        if (widget.onAvatarChanged != null) {
          widget.onAvatarChanged!(result['profile_picture']);
        }
        
        _showSuccessSnackBar(result['message'] ?? 'Avatar mis à jour avec succès');
      } else {
        throw Exception('URL de l\'avatar non reçue');
      }
    } catch (e) {
      _showErrorSnackBar('Erreur lors de l\'upload: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _removeAvatar() async {
    setState(() {
      _isUploading = true;
    });

    try {
      // Mettre à jour le profil avec un avatar vide
      await _profileService.updateUserProfile({'profile_picture': null});
      
      setState(() {
        _currentAvatarUrl = null;
      });
      
      if (widget.onAvatarChanged != null) {
        widget.onAvatarChanged!('');
      }
      
      _showSuccessSnackBar('Photo de profil supprimée');
    } catch (e) {
      _showErrorSnackBar('Erreur lors de la suppression: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.isEditable ? _showImageSourceActionSheet : null,
      child: Stack(
        children: [
          // Avatar principal
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.grey[300]!,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: _isUploading
                  ? Container(
                      color: Colors.grey[100],
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                    )
                  : _currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty
                      ? OptimizedCloudinaryImage(
                          imageUrl: _currentAvatarUrl!,
                          imageType: 'avatar',
                          fit: BoxFit.cover,
                        )
                      : _buildDefaultAvatar(),
            ),
          ),
          
          // Badge d'édition
          if (widget.isEditable && !_isUploading)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: widget.size * 0.25,
                height: widget.size * 0.25,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: widget.size * 0.12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: Colors.grey[200],
      child: Icon(
        Icons.person,
        size: widget.size * 0.6,
        color: Colors.grey[400],
      ),
    );
  }
}