import 'package:flutter/material.dart';

class StarRatingWidget extends StatelessWidget {
  final double rating;
  final int starCount;
  final double size;
  final Color activeColor;
  final Color inactiveColor;
  final bool allowHalfRating;
  final MainAxisAlignment alignment;
  final bool showText;
  final String? customText;

  const StarRatingWidget({
    super.key,
    required this.rating,
    this.starCount = 5,
    this.size = 20,
    this.activeColor = Colors.amber,
    this.inactiveColor = Colors.grey,
    this.allowHalfRating = true,
    this.alignment = MainAxisAlignment.start,
    this.showText = false,
    this.customText,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(starCount, (index) {
          return Icon(
            _getIconForIndex(index),
            size: size,
            color: _getColorForIndex(index),
          );
        }),
        if (showText || customText != null) ...[
          const SizedBox(width: 6),
          Text(
            customText ?? rating.toStringAsFixed(1),
            style: TextStyle(
              fontSize: size * 0.7,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ],
      ],
    );
  }

  IconData _getIconForIndex(int index) {
    double threshold = index + 1.0;
    double halfThreshold = index + 0.5;

    if (rating >= threshold) {
      return Icons.star;
    } else if (allowHalfRating && rating >= halfThreshold) {
      return Icons.star_half;
    } else {
      return Icons.star_border;
    }
  }

  Color _getColorForIndex(int index) {
    double threshold = index + 1.0;
    double halfThreshold = index + 0.5;

    if (rating >= threshold) {
      return activeColor;
    } else if (allowHalfRating && rating >= halfThreshold) {
      return activeColor;
    } else {
      return inactiveColor.withValues(alpha: 0.4);
    }
  }
}

class InteractiveStarRating extends StatefulWidget {
  final int initialRating;
  final Function(int rating) onRatingChanged;
  final int starCount;
  final double size;
  final Color activeColor;
  final Color inactiveColor;
  final bool enabled;

  const InteractiveStarRating({
    super.key,
    required this.onRatingChanged,
    this.initialRating = 0,
    this.starCount = 5,
    this.size = 32,
    this.activeColor = Colors.amber,
    this.inactiveColor = Colors.grey,
    this.enabled = true,
  });

  @override
  State<InteractiveStarRating> createState() => _InteractiveStarRatingState();
}

class _InteractiveStarRatingState extends State<InteractiveStarRating> {
  late int _currentRating;

  @override
  void initState() {
    super.initState();
    _currentRating = widget.initialRating;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(widget.starCount, (index) {
        return GestureDetector(
          onTap: widget.enabled ? () {
            setState(() {
              _currentRating = index + 1;
            });
            widget.onRatingChanged(_currentRating);
          } : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              index < _currentRating ? Icons.star : Icons.star_border,
              size: widget.size,
              color: index < _currentRating 
                  ? widget.activeColor
                  : widget.inactiveColor.withValues(alpha: 0.4),
            ),
          ),
        );
      }),
    );
  }
}

class RatingBadge extends StatelessWidget {
  final double rating;
  final int reviewCount;
  final String status;
  final bool showBadge;
  final bool compact;

  const RatingBadge({
    super.key,
    required this.rating,
    required this.reviewCount,
    required this.status,
    this.showBadge = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (reviewCount == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Nouveau',
          style: TextStyle(
            fontSize: compact ? 10 : 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 6 : 8,
            vertical: compact ? 2 : 4,
          ),
          decoration: BoxDecoration(
            color: _getBadgeColor().withValues(alpha: 0.1),
            border: Border.all(color: _getBadgeColor(), width: 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.star,
                size: compact ? 12 : 14,
                color: _getBadgeColor(),
              ),
              const SizedBox(width: 2),
              Text(
                rating.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: compact ? 10 : 12,
                  fontWeight: FontWeight.w600,
                  color: _getBadgeColor(),
                ),
              ),
              if (!compact) ...[
                const SizedBox(width: 2),
                Text(
                  '($reviewCount)',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (showBadge && _getSuperBadge() != null) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _getSuperBadgeColor(),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _getSuperBadge()!,
              style: TextStyle(
                fontSize: compact ? 8 : 10,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Color _getBadgeColor() {
    if (rating >= 4.5) return Colors.green;
    if (rating >= 4.0) return Colors.blue;
    if (rating >= 3.5) return Colors.orange;
    if (rating >= 3.0) return Colors.red;
    return Colors.grey;
  }

  String? _getSuperBadge() {
    switch (status) {
      case 'super_traveler':
        return 'SUPER';
      case 'warning':
        return 'ATTENTION';
      case 'suspended':
        return 'SUSPENDU';
      default:
        return null;
    }
  }

  Color _getSuperBadgeColor() {
    switch (status) {
      case 'super_traveler':
        return Colors.green;
      case 'warning':
        return Colors.orange;
      case 'suspended':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class RatingDisplay extends StatelessWidget {
  final double rating;
  final int reviewCount;
  final bool showDetails;
  final VoidCallback? onTap;

  const RatingDisplay({
    super.key,
    required this.rating,
    required this.reviewCount,
    this.showDetails = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (reviewCount == 0) {
      return GestureDetector(
        onTap: onTap,
        child: const Text(
          'Pas d\'évaluation',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StarRatingWidget(
            rating: rating,
            size: showDetails ? 16 : 14,
            showText: showDetails,
          ),
          if (!showDetails) ...[
            const SizedBox(width: 4),
            Text(
              '${rating.toStringAsFixed(1)} ($reviewCount)',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}