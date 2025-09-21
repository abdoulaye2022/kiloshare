import 'package:flutter/material.dart';
import '../models/user_profile.dart';

class TrustBadgeWidget extends StatelessWidget {
  final TrustBadge badge;
  final double size;
  final bool showTooltip;
  final bool showLabel;

  const TrustBadgeWidget({
    super.key,
    required this.badge,
    this.size = 24,
    this.showTooltip = true,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final widget = _buildBadgeWidget(context);

    if (showTooltip && badge.badgeDescription != null) {
      return Tooltip(
        message: badge.badgeDescription!,
        child: widget,
      );
    }

    return widget;
  }

  Widget _buildBadgeWidget(BuildContext context) {
    Color badgeColor = _getBadgeColor();
    IconData badgeIcon = _getBadgeIcon();

    if (showLabel) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: badgeColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: badgeColor.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              badgeIcon,
              size: size * 0.8,
              color: badgeColor,
            ),
            const SizedBox(width: 4),
            Text(
              badge.badgeName,
              style: TextStyle(
                fontSize: size * 0.6,
                color: badgeColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: badgeColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: badgeColor.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        badgeIcon,
        size: size * 0.6,
        color: Colors.white,
      ),
    );
  }

  Color _getBadgeColor() {
    if (badge.badgeColor != null && badge.badgeColor!.isNotEmpty) {
      try {
        return Color(int.parse(badge.badgeColor!.replaceFirst('#', '0xFF')));
      } catch (e) {
        // Fallback si la couleur n'est pas valide
      }
    }

    // Couleurs par défaut selon le type de badge
    switch (badge.badgeType) {
      case 'email_verified':
        return const Color(0xFF10B981); // Green
      case 'phone_verified':
        return const Color(0xFF3B82F6); // Blue
      case 'identity_verified':
        return const Color(0xFF8B5CF6); // Purple
      case 'address_verified':
        return const Color(0xFFEF4444); // Red
      case 'bank_verified':
        return const Color(0xFF06B6D4); // Cyan
      case 'social_media_verified':
        return const Color(0xFFF59E0B); // Amber
      case 'background_check':
        return const Color(0xFF84CC16); // Lime
      case 'premium_member':
        return const Color(0xFFF59E0B); // Amber/Gold
      case 'top_rated':
        return const Color(0xFFDC2626); // Red
      case 'quick_responder':
        return const Color(0xFF059669); // Emerald
      default:
        return const Color(0xFF6B7280); // Gray
    }
  }

  IconData _getBadgeIcon() {
    if (badge.badgeIcon != null && badge.badgeIcon!.isNotEmpty) {
      // Mappage des noms d'icônes aux IconData
      switch (badge.badgeIcon!) {
        case 'mail-check':
          return Icons.mark_email_read;
        case 'phone-check':
          return Icons.phone_enabled;
        case 'id-card':
          return Icons.credit_card;
        case 'map-pin':
          return Icons.location_on;
        case 'bank':
          return Icons.account_balance;
        case 'shield-check':
          return Icons.verified_user;
        case 'crown':
          return Icons.emoji_events;
        case 'star':
          return Icons.star;
        case 'flash':
          return Icons.flash_on;
        default:
          return Icons.verified;
      }
    }

    // Icônes par défaut selon le type de badge
    switch (badge.badgeType) {
      case 'email_verified':
        return Icons.mark_email_read;
      case 'phone_verified':
        return Icons.phone_enabled;
      case 'identity_verified':
        return Icons.credit_card;
      case 'address_verified':
        return Icons.location_on;
      case 'bank_verified':
        return Icons.account_balance;
      case 'social_media_verified':
        return Icons.share;
      case 'background_check':
        return Icons.verified_user;
      case 'premium_member':
        return Icons.emoji_events;
      case 'top_rated':
        return Icons.star;
      case 'quick_responder':
        return Icons.flash_on;
      default:
        return Icons.verified;
    }
  }
}

class TrustBadgeList extends StatelessWidget {
  final List<TrustBadge> badges;
  final double size;
  final int maxVisible;
  final bool showLabels;
  final MainAxisAlignment alignment;

  const TrustBadgeList({
    super.key,
    required this.badges,
    this.size = 24,
    this.maxVisible = 5,
    this.showLabels = false,
    this.alignment = MainAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) {
      return const SizedBox.shrink();
    }

    final visibleBadges = badges.take(maxVisible).toList();
    final remainingCount = badges.length - maxVisible;

    if (showLabels) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ...visibleBadges.map((badge) => TrustBadgeWidget(
            badge: badge,
            size: size,
            showLabel: true,
          )),
          if (remainingCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '+$remainingCount',
                style: TextStyle(
                  fontSize: size * 0.6,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: alignment,
      children: [
        ...visibleBadges.map((badge) => Padding(
          padding: const EdgeInsets.only(right: 4),
          child: TrustBadgeWidget(
            badge: badge,
            size: size,
          ),
        )),
        if (remainingCount > 0)
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '+$remainingCount',
                style: TextStyle(
                  fontSize: size * 0.4,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class TrustScoreWidget extends StatelessWidget {
  final double trustScore;
  final double size;
  final bool showLabel;

  const TrustScoreWidget({
    super.key,
    required this.trustScore,
    this.size = 32,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (trustScore * 100).clamp(0, 100);
    final color = _getScoreColor(trustScore);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: trustScore,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(color),
                strokeWidth: 3,
              ),
            ),
            Text(
              '${percentage.toInt()}',
              style: TextStyle(
                fontSize: size * 0.3,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        if (showLabel) ...[
          const SizedBox(width: 8),
          Text(
            'Score de confiance',
            style: TextStyle(
              fontSize: size * 0.4,
              color: Colors.grey[600],
            ),
          ),
        ],
      ],
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 0.8) return const Color(0xFF10B981); // Green
    if (score >= 0.6) return const Color(0xFF3B82F6); // Blue
    if (score >= 0.4) return const Color(0xFFF59E0B); // Amber
    return const Color(0xFFEF4444); // Red
  }
}