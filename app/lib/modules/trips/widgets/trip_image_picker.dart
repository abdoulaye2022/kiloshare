import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/trip_image_model.dart';

class TripImagePicker extends StatefulWidget {
  final List<File> initialImages;
  final List<TripImage> existingImages;
  final ValueChanged<List<File>> onImagesChanged;
  final ValueChanged<TripImage>? onDeleteExisting;
  final bool readOnly;

  const TripImagePicker({
    super.key,
    this.initialImages = const [],
    this.existingImages = const [],
    required this.onImagesChanged,
    this.onDeleteExisting,
    this.readOnly = false,
  });

  @override
  State<TripImagePicker> createState() => _TripImagePickerState();
}

class _TripImagePickerState extends State<TripImagePicker> {
  final ImagePicker _picker = ImagePicker();
  List<File> _selectedImages = [];
  
  static const int maxImages = 2;
  static const double maxSizeMB = 3.0;

  @override
  void initState() {
    super.initState();
    _selectedImages = List.from(widget.initialImages);
  }

  @override
  Widget build(BuildContext context) {
    final totalImages = widget.existingImages.length + _selectedImages.length;
    final canAddMore = totalImages < maxImages && !widget.readOnly;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Photos de l\'annonce',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Optionnel',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Ajoutez jusqu\'à $maxImages photos (max ${maxSizeMB}MB chacune) pour rendre votre annonce plus attractive.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 16),
        
        // Images grid
        if (widget.existingImages.isNotEmpty || _selectedImages.isNotEmpty)
          _buildImagesGrid(),
        
        // Add button
        if (canAddMore) ...[
          const SizedBox(height: 16),
          _buildAddButton(),
        ],
        
        // Counter
        if (totalImages > 0 || maxImages > 0) ...[
          const SizedBox(height: 8),
          Text(
            '$totalImages / $maxImages photos',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildImagesGrid() {
    final allImages = <Widget>[];
    
    // Existing images
    for (final image in widget.existingImages) {
      allImages.add(_buildExistingImageCard(image));
    }
    
    // New selected images
    for (int i = 0; i < _selectedImages.length; i++) {
      allImages.add(_buildNewImageCard(_selectedImages[i], i));
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: allImages,
    );
  }

  Widget _buildExistingImageCard(TripImage image) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              image.url,
              width: 120,
              height: 120,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 120,
                  height: 120,
                  color: Colors.grey.shade200,
                  child: const Icon(
                    Icons.image_not_supported,
                    color: Colors.grey,
                    size: 40,
                  ),
                );
              },
            ),
          ),
          if (!widget.readOnly && widget.onDeleteExisting != null)
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => _showDeleteExistingDialog(image),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 4,
            left: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _formatFileSize(image.fileSize),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewImageCard(File image, int index) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              image,
              width: 120,
              height: 120,
              fit: BoxFit.cover,
            ),
          ),
          if (!widget.readOnly)
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => _removeImage(index),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 4,
            left: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: FutureBuilder<int>(
                future: image.length(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final sizeMB = snapshot.data! / (1024 * 1024);
                    return Text(
                      '${sizeMB.toStringAsFixed(1)}MB',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    );
                  }
                  return const Text(
                    '...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return OutlinedButton.icon(
      onPressed: _showImageSourceDialog,
      icon: const Icon(Icons.add_photo_alternate),
      label: const Text('Ajouter une photo'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Prendre une photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choisir depuis la galerie'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
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
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );
      
      if (image != null) {
        final file = File(image.path);
        
        // Validate image
        await _validateImage(file);
        
        setState(() {
          _selectedImages.add(file);
        });
        
        widget.onImagesChanged(_selectedImages);
      }
    } catch (e) {
      _showErrorSnackBar(e.toString());
    }
  }

  Future<void> _validateImage(File image) async {
    // Check file size
    final fileSize = await image.length();
    final sizeMB = fileSize / (1024 * 1024);
    
    if (sizeMB > maxSizeMB) {
      throw Exception('La taille de l\'image doit être inférieure à ${maxSizeMB}MB');
    }
    
    // Check file extension
    final fileName = image.path.toLowerCase();
    if (!fileName.endsWith('.jpg') && 
        !fileName.endsWith('.jpeg') && 
        !fileName.endsWith('.png') && 
        !fileName.endsWith('.webp')) {
      throw Exception('Seules les images JPG, PNG et WebP sont acceptées');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
    widget.onImagesChanged(_selectedImages);
  }

  void _showDeleteExistingDialog(TripImage image) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la photo'),
        content: const Text('Êtes-vous sûr de vouloir supprimer cette photo ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onDeleteExisting?.call(image);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null || bytes == 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    int i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(i == 0 ? 0 : 1)} ${suffixes[i]}';
  }
}