import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Widget d'affichage d'avatar en lecture seule
/// Utilise CachedNetworkImage pour un affichage optimisé
class AvatarDisplayWidget extends StatelessWidget {
  final String? avatarUrl;
  final String? userName;
  final double size;
  final Color? borderColor;
  final double borderWidth;
  final VoidCallback? onTap;

  const AvatarDisplayWidget({
    super.key,
    this.avatarUrl,
    this.userName,
    this.size = 80.0,
    this.borderColor,
    this.borderWidth = 2.0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: borderWidth > 0 
            ? Border.all(
                color: borderColor ?? Colors.grey[300]!,
                width: borderWidth,
              )
            : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipOval(
          child: avatarUrl != null && avatarUrl!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: avatarUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => _buildDefaultAvatar(),
                )
              : _buildDefaultAvatar(),
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: Colors.grey[200],
      child: userName != null && userName!.isNotEmpty
          ? Center(
              child: Text(
                _getInitials(userName!),
                style: TextStyle(
                  fontSize: size * 0.3,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
            )
          : Icon(
              Icons.person,
              size: size * 0.6,
              color: Colors.grey[400],
            ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '';
    
    if (parts.length == 1) {
      return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '';
    } else {
      final first = parts.first.isNotEmpty ? parts.first[0] : '';
      final last = parts.last.isNotEmpty ? parts.last[0] : '';
      return '$first$last'.toUpperCase();
    }
  }
}