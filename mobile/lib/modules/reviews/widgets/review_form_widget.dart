import 'package:flutter/material.dart';
import '../services/review_service.dart';
import '../widgets/star_rating_widget.dart';

class ReviewFormWidget extends StatefulWidget {
  final int bookingId;
  final String userRole; // 'sender' or 'traveler'
  final String? route;
  final VoidCallback? onSuccess;
  final VoidCallback? onCancel;

  const ReviewFormWidget({
    super.key,
    required this.bookingId,
    required this.userRole,
    this.route,
    this.onSuccess,
    this.onCancel,
  });

  @override
  State<ReviewFormWidget> createState() => _ReviewFormWidgetState();
}

class _ReviewFormWidgetState extends State<ReviewFormWidget> {
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;
  final _reviewService = ReviewService();

  @override
  void initState() {
    super.initState();
    _reviewService.initialize();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Comment s\'est passée la livraison ?',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.route != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.route!,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          'En tant que ${widget.userRole == 'sender' ? 'expéditeur' : 'voyageur'}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onCancel,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Rating Section
              Center(
                child: Column(
                  children: [
                    Text(
                      'Note générale',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    InteractiveStarRating(
                      initialRating: _rating,
                      onRatingChanged: (rating) {
                        setState(() {
                          _rating = rating;
                        });
                      },
                      size: 40,
                      enabled: !_isSubmitting,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getRatingText(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Comment Section
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Commentaire (optionnel)',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _commentController,
                    maxLines: 4,
                    maxLength: 500,
                    enabled: !_isSubmitting,
                    decoration: InputDecoration(
                      hintText: 'Partagez votre expérience...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).primaryColor,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Info text
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue[600],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Votre évaluation sera visible une fois que les deux parties auront évalué ou après 14 jours.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _rating > 0 && !_isSubmitting ? _submitReview : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Envoyer l\'évaluation',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Cancel Button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _isSubmitting ? null : widget.onCancel,
                  child: const Text(
                    'Annuler',
                    style: TextStyle(
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getRatingText() {
    switch (_rating) {
      case 1:
        return 'Très décevant';
      case 2:
        return 'Décevant';
      case 3:
        return 'Correct';
      case 4:
        return 'Bien';
      case 5:
        return 'Excellent';
      default:
        return 'Sélectionnez une note';
    }
  }

  Future<void> _submitReview() async {
    if (_rating == 0) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _reviewService.createReview(
        bookingId: widget.bookingId,
        rating: _rating,
        comment: _commentController.text.isEmpty ? null : _commentController.text,
      );

      if (mounted) {
        // Succès
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Évaluation envoyée avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
        
        widget.onSuccess?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}

/// Modal pour afficher le formulaire de review
class ReviewFormModal {
  static Future<void> show({
    required BuildContext context,
    required int bookingId,
    required String userRole,
    String? route,
    VoidCallback? onSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: ReviewFormWidget(
          bookingId: bookingId,
          userRole: userRole,
          route: route,
          onSuccess: () {
            Navigator.of(context).pop();
            onSuccess?.call();
          },
          onCancel: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}

/// Widget compact pour déclencher une review rapide
class QuickReviewButton extends StatelessWidget {
  final int bookingId;
  final String userRole;
  final String? route;
  final VoidCallback? onSuccess;
  final bool showIcon;

  const QuickReviewButton({
    super.key,
    required this.bookingId,
    required this.userRole,
    this.route,
    this.onSuccess,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _showReviewForm(context),
      icon: showIcon ? const Icon(Icons.star_outline, size: 18) : const SizedBox.shrink(),
      label: const Text('Évaluer'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  void _showReviewForm(BuildContext context) {
    ReviewFormModal.show(
      context: context,
      bookingId: bookingId,
      userRole: userRole,
      route: route,
      onSuccess: onSuccess,
    );
  }
}