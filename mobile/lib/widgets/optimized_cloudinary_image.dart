import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';

/// Widget optimisé pour l'affichage d'images Cloudinary avec cache
/// 
/// Fournit différentes qualités d'affichage selon le contexte,
/// gestion du cache local et mode plein écran pour KiloShare.
/// 
/// Features:
/// - Cache local automatique
/// - Transformations Cloudinary à la volée
/// - Mode thumbnail/medium/large
/// - Placeholder et gestion d'erreurs
/// - Zoom et mode plein écran
/// - Support images sécurisées
class OptimizedCloudinaryImage extends StatelessWidget {
  final String imageUrl;
  final String imageType;
  final ImageDisplayMode displayMode;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final bool enableZoom;
  final bool showFullscreenButton;
  final BorderRadius? borderRadius;
  final String? placeholder;
  final String? errorWidget;
  final Function()? onTap;
  final String? heroTag;

  const OptimizedCloudinaryImage({
    Key? key,
    required this.imageUrl,
    required this.imageType,
    this.displayMode = ImageDisplayMode.medium,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.enableZoom = false,
    this.showFullscreenButton = false,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.onTap,
    this.heroTag,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final optimizedUrl = _getOptimizedUrl();
    
    Widget imageWidget = CachedNetworkImage(
      imageUrl: optimizedUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => _buildPlaceholder(),
      errorWidget: (context, url, error) => _buildErrorWidget(),
      cacheKey: _getCacheKey(),
      fadeInDuration: const Duration(milliseconds: 200),
      fadeOutDuration: const Duration(milliseconds: 100),
      memCacheWidth: _getMemoryCacheWidth(),
      memCacheHeight: _getMemoryCacheHeight(),
    );

    // Appliquer le border radius
    if (borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    // Stack pour les boutons overlay
    if (showFullscreenButton || enableZoom) {
      imageWidget = Stack(
        children: [
          imageWidget,
          if (showFullscreenButton)
            Positioned(
              top: 8,
              right: 8,
              child: _buildFullscreenButton(context),
            ),
        ],
      );
    }

    // Hero animation si tag fourni
    if (heroTag != null) {
      imageWidget = Hero(
        tag: heroTag!,
        child: imageWidget,
      );
    }

    // Gestion du tap
    if (onTap != null || enableZoom) {
      imageWidget = GestureDetector(
        onTap: () {
          if (onTap != null) {
            onTap!();
          } else if (enableZoom) {
            _showFullscreenImage(context);
          }
        },
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  /// Obtenir l'URL optimisée selon le mode d'affichage
  String _getOptimizedUrl() {
    // Si l'URL contient déjà des transformations Cloudinary, l'utiliser telle quelle
    if (imageUrl.contains('c_fill') || imageUrl.contains('q_')) {
      return imageUrl;
    }

    // Ajouter les transformations Cloudinary selon le mode et le type d'image
    final transformations = _getTransformations();
    
    // Insérer les transformations dans l'URL Cloudinary
    if (imageUrl.contains('/image/upload/')) {
      return imageUrl.replaceFirst('/image/upload/', '/image/upload/$transformations/');
    }
    
    // URL non-Cloudinary, retourner telle quelle
    return imageUrl;
  }

  /// Obtenir les transformations Cloudinary selon le mode
  String _getTransformations() {
    final Map<String, Map<ImageDisplayMode, String>> transformations = {
      'avatar': {
        ImageDisplayMode.mini: 'c_fill,w_50,h_50,q_70',
        ImageDisplayMode.thumbnail: 'c_fill,w_150,h_150,q_75',
        ImageDisplayMode.medium: 'c_fill,w_400,h_400,q_80',
        ImageDisplayMode.large: 'c_fill,w_800,h_800,q_85',
      },
      'kyc_document': {
        ImageDisplayMode.thumbnail: 'c_fill,w_300,h_200,q_50',
        ImageDisplayMode.medium: 'c_limit,w_800,q_60',
        ImageDisplayMode.large: 'c_limit,w_1200,q_70',
      },
      'trip_photo': {
        ImageDisplayMode.thumbnail: 'c_fill,w_200,h_150,q_40',
        ImageDisplayMode.medium: 'c_fill,w_400,h_300,q_45',
        ImageDisplayMode.large: 'c_fill,w_800,h_600,q_50',
      },
      'package_photo': {
        ImageDisplayMode.thumbnail: 'c_fill,w_200,h_200,q_45',
        ImageDisplayMode.medium: 'c_limit,w_400,q_50',
        ImageDisplayMode.large: 'c_limit,w_600,q_55',
      },
      'delivery_proof': {
        ImageDisplayMode.thumbnail: 'c_fill,w_300,h_300,q_70',
        ImageDisplayMode.medium: 'c_limit,w_600,q_80',
        ImageDisplayMode.large: 'c_limit,w_1000,q_85',
      },
    };

    // Format automatique pour WebP quand supporté
    final baseTransformation = transformations[imageType]?[displayMode] ?? 
                               transformations['trip_photo']![displayMode]!;
    
    return '$baseTransformation,f_auto';
  }

  /// Obtenir la clé de cache unique
  String _getCacheKey() {
    return '${imageUrl}_${imageType}_${displayMode.name}';
  }

  /// Obtenir la largeur pour le cache mémoire
  int? _getMemoryCacheWidth() {
    switch (displayMode) {
      case ImageDisplayMode.mini:
        return 50;
      case ImageDisplayMode.thumbnail:
        return imageType == 'avatar' ? 150 : 200;
      case ImageDisplayMode.medium:
        return imageType == 'avatar' ? 400 : 400;
      case ImageDisplayMode.large:
        return imageType == 'avatar' ? 800 : 800;
    }
  }

  /// Obtenir la hauteur pour le cache mémoire
  int? _getMemoryCacheHeight() {
    switch (displayMode) {
      case ImageDisplayMode.mini:
        return 50;
      case ImageDisplayMode.thumbnail:
        return imageType == 'avatar' ? 150 : 150;
      case ImageDisplayMode.medium:
        return imageType == 'avatar' ? 400 : 300;
      case ImageDisplayMode.large:
        return imageType == 'avatar' ? 800 : 600;
    }
  }

  /// Construire le placeholder
  Widget _buildPlaceholder() {
    if (placeholder != null) {
      return Image.asset(
        placeholder!,
        width: width,
        height: height,
        fit: fit,
      );
    }

    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
        ),
      ),
    );
  }

  /// Construire le widget d'erreur
  Widget _buildErrorWidget() {
    if (errorWidget != null) {
      return Image.asset(
        errorWidget!,
        width: width,
        height: height,
        fit: fit,
      );
    }

    return Container(
      width: width,
      height: height,
      color: Colors.grey[100],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getErrorIcon(),
            color: Colors.grey[400],
            size: (height != null && height! < 100) ? 24 : 48,
          ),
          if (height == null || height! >= 100) ...[
            const SizedBox(height: 8),
            Text(
              'Image non disponible',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  /// Obtenir l'icône d'erreur selon le type d'image
  IconData _getErrorIcon() {
    switch (imageType) {
      case 'avatar':
        return Icons.person;
      case 'kyc_document':
        return Icons.description;
      case 'trip_photo':
        return Icons.landscape;
      case 'package_photo':
        return Icons.inventory;
      case 'delivery_proof':
        return Icons.receipt;
      default:
        return Icons.image;
    }
  }

  /// Construire le bouton plein écran
  Widget _buildFullscreenButton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: IconButton(
        icon: const Icon(
          Icons.fullscreen,
          color: Colors.white,
          size: 20,
        ),
        onPressed: () => _showFullscreenImage(context),
        constraints: const BoxConstraints(
          minWidth: 32,
          minHeight: 32,
        ),
        padding: EdgeInsets.zero,
      ),
    );
  }

  /// Afficher l'image en plein écran
  void _showFullscreenImage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullscreenImageViewer(
          imageUrl: _getOptimizedUrl(),
          imageType: imageType,
          heroTag: heroTag,
        ),
      ),
    );
  }
}

/// Modes d'affichage des images
enum ImageDisplayMode {
  mini,      // 50x50 pour avatars mini
  thumbnail, // 150x150 ou 200x150 pour listes
  medium,    // 400x300 pour détails
  large,     // 800x600 pour plein écran
}

/// Visionneur d'image plein écran
class FullscreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String imageType;
  final String? heroTag;

  const FullscreenImageViewer({
    Key? key,
    required this.imageUrl,
    required this.imageType,
    this.heroTag,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Center(
        child: heroTag != null
          ? Hero(
              tag: heroTag!,
              child: _buildPhotoView(),
            )
          : _buildPhotoView(),
      ),
    );
  }

  Widget _buildPhotoView() {
    return PhotoView(
      imageProvider: CachedNetworkImageProvider(
        imageUrl,
        cacheKey: '${imageUrl}_${imageType}_fullscreen',
      ),
      minScale: PhotoViewComputedScale.contained * 0.8,
      maxScale: PhotoViewComputedScale.covered * 2.0,
      backgroundDecoration: const BoxDecoration(
        color: Colors.black,
      ),
      loadingBuilder: (context, event) => Center(
        child: CircularProgressIndicator(
          value: event == null
              ? 0
              : event.cumulativeBytesLoaded / (event.expectedTotalBytes ?? 1),
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
      errorBuilder: (context, error, stackTrace) => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              'Impossible de charger l\'image',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget pour galerie d'images avec navigation
class CloudinaryImageGallery extends StatefulWidget {
  final List<String> imageUrls;
  final String imageType;
  final int initialIndex;
  final Function(int)? onPageChanged;
  final bool showIndicators;
  final bool enableZoom;

  const CloudinaryImageGallery({
    Key? key,
    required this.imageUrls,
    required this.imageType,
    this.initialIndex = 0,
    this.onPageChanged,
    this.showIndicators = true,
    this.enableZoom = true,
  }) : super(key: key);

  @override
  State<CloudinaryImageGallery> createState() => _CloudinaryImageGalleryState();
}

class _CloudinaryImageGalleryState extends State<CloudinaryImageGallery> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.imageUrls.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
              widget.onPageChanged?.call(index);
            },
            itemBuilder: (context, index) {
              return OptimizedCloudinaryImage(
                imageUrl: widget.imageUrls[index],
                imageType: widget.imageType,
                displayMode: ImageDisplayMode.large,
                enableZoom: widget.enableZoom,
                heroTag: 'gallery_image_$index',
              );
            },
          ),
        ),
        if (widget.showIndicators && widget.imageUrls.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: widget.imageUrls.asMap().entries.map((entry) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentIndex == entry.key
                        ? Theme.of(context).primaryColor
                        : Colors.grey[300],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

/// Widget avatar optimisé avec fallback
class CloudinaryAvatar extends StatelessWidget {
  final String? imageUrl;
  final String userName;
  final double radius;
  final Color? backgroundColor;
  final TextStyle? textStyle;
  final VoidCallback? onTap;

  const CloudinaryAvatar({
    Key? key,
    this.imageUrl,
    required this.userName,
    this.radius = 24,
    this.backgroundColor,
    this.textStyle,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget avatar;

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      if (kDebugMode) {
        print('[CloudinaryAvatar] Loading avatar: $imageUrl');
        print('[CloudinaryAvatar] Is Cloudinary URL: ${_isCloudinaryUrl(imageUrl!)}');
      }
      avatar = CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor ?? Colors.grey[200],
        child: ClipOval(
          child: _isCloudinaryUrl(imageUrl!)
              ? OptimizedCloudinaryImage(
                  imageUrl: imageUrl!,
                  imageType: 'avatar',
                  displayMode: radius <= 25 ? ImageDisplayMode.mini : ImageDisplayMode.thumbnail,
                  width: radius * 2,
                  height: radius * 2,
                  fit: BoxFit.cover,
                )
              : CachedNetworkImage(
                  imageUrl: imageUrl!,
                  width: radius * 2,
                  height: radius * 2,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[200],
                    child: Icon(
                      Icons.person,
                      size: radius * 0.8,
                      color: Colors.grey[400],
                    ),
                  ),
                ),
        ),
      );
    } else {
      // Avatar avec initiales
      final initials = _getInitials(userName);
      avatar = CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor ?? _generateColorFromName(userName),
        child: Text(
          initials,
          style: textStyle ?? TextStyle(
            color: Colors.white,
            fontSize: radius * 0.6,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: avatar,
      );
    }

    return avatar;
  }

  /// Obtenir les initiales d'un nom
  String _getInitials(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.isEmpty) return '?';
    
    if (words.length == 1) {
      return words[0].substring(0, 1).toUpperCase();
    }
    
    return (words[0].substring(0, 1) + words[1].substring(0, 1)).toUpperCase();
  }

  /// Générer une couleur basée sur le nom
  Color _generateColorFromName(String name) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
    ];
    
    final hash = name.hashCode.abs();
    return colors[hash % colors.length];
  }

  /// Vérifier si l'URL est une URL Cloudinary
  bool _isCloudinaryUrl(String url) {
    return url.contains('cloudinary.com') || 
           url.contains('res.cloudinary.com') || 
           url.contains('/image/upload/');
  }
}