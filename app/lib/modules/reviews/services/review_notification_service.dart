import 'package:flutter/material.dart';
import '../models/review_model.dart';
import '../services/review_service.dart';
import '../widgets/review_form_widget.dart';

class ReviewNotificationService {
  static final ReviewNotificationService _instance = ReviewNotificationService._internal();
  factory ReviewNotificationService() => _instance;
  ReviewNotificationService._internal();

  final ReviewService _reviewService = ReviewService();

  /// Initialiser le service
  void initialize() {
    _reviewService.initialize();
  }

  /// Vérifier et afficher les reviews en attente pour l'utilisateur
  Future<void> checkAndShowPendingReviews(BuildContext context) async {
    try {
      final pendingReviews = await _reviewService.getPendingReviews();
      
      if (pendingReviews.isNotEmpty && context.mounted) {
        _showPendingReviewsDialog(context, pendingReviews);
      }
    } catch (e) {
      // Silently fail - les reviews ne sont pas critiques
    }
  }

  /// Déclencher une notification de review pour une booking spécifique
  Future<void> triggerReviewNotification({
    required BuildContext context,
    required int bookingId,
    required String userRole,
    required String route,
    bool immediate = false,
  }) async {
    if (immediate) {
      // Afficher immédiatement le formulaire de review
      _showReviewForm(context, bookingId, userRole, route);
    } else {
      // Afficher une notification discrète d'abord
      _showReviewNotification(context, bookingId, userRole, route);
    }
  }

  /// Afficher une notification discrète pour inviter à évaluer
  void _showReviewNotification(
    BuildContext context,
    int bookingId,
    String userRole,
    String route,
  ) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.star_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Comment s\'est passée la livraison ?',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    route,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'Évaluer',
          textColor: Colors.white,
          onPressed: () => _showReviewForm(context, bookingId, userRole, route),
        ),
        duration: const Duration(seconds: 8),
        backgroundColor: Colors.blue[700],
        behavior: SnackBarBehavior.fixed,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  /// Afficher le formulaire de review
  void _showReviewForm(
    BuildContext context,
    int bookingId,
    String userRole,
    String route,
  ) {
    ReviewFormModal.show(
      context: context,
      bookingId: bookingId,
      userRole: userRole,
      route: route,
      onSuccess: () {
        // Optionnel: afficher un feedback de succès
        if (context.mounted) {
          _showSuccessMessage(context);
        }
      },
    );
  }

  /// Afficher un message de succès après review
  void _showSuccessMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.white,
            ),
            SizedBox(width: 12),
            Text(
              'Merci pour votre évaluation !',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.fixed,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  /// Afficher un dialog avec toutes les reviews en attente
  void _showPendingReviewsDialog(
    BuildContext context,
    List<PendingReviewModel> pendingReviews,
  ) {
    if (pendingReviews.length == 1) {
      // Si une seule review, afficher directement le formulaire
      final review = pendingReviews.first;
      _showReviewForm(context, review.bookingId, review.userRole, review.route);
      return;
    }

    // Plusieurs reviews en attente, afficher la liste
    showDialog(
      context: context,
      builder: (context) => PendingReviewsDialog(
        pendingReviews: pendingReviews,
        onReviewSelected: (review) {
          Navigator.of(context).pop();
          _showReviewForm(context, review.bookingId, review.userRole, review.route);
        },
      ),
    );
  }

  /// Obtenir le nombre de reviews en attente (pour affichage badge)
  Future<int> getPendingReviewsCount() async {
    try {
      final pendingReviews = await _reviewService.getPendingReviews();
      return pendingReviews.length;
    } catch (e) {
      return 0;
    }
  }
}

/// Dialog pour afficher plusieurs reviews en attente
class PendingReviewsDialog extends StatelessWidget {
  final List<PendingReviewModel> pendingReviews;
  final Function(PendingReviewModel) onReviewSelected;

  const PendingReviewsDialog({
    super.key,
    required this.pendingReviews,
    required this.onReviewSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                const Icon(
                  Icons.star_outline,
                  color: Colors.blue,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Évaluations en attente',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${pendingReviews.length} livraison${pendingReviews.length > 1 ? 's' : ''} à évaluer',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Liste des reviews en attente
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: pendingReviews.length,
                itemBuilder: (context, index) {
                  final review = pendingReviews[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(
                        review.userRole == 'sender' ? Icons.send : Icons.flight,
                        color: Colors.blue,
                      ),
                      title: Text(
                        review.route,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('En tant que ${review.roleDisplayName}'),
                          Text(
                            review.timeElapsed,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                      ),
                      onTap: () => onReviewSelected(review),
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Bouton fermer
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Plus tard'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget pour afficher le badge du nombre de reviews en attente
class PendingReviewsBadge extends StatefulWidget {
  final Widget child;
  final bool showBadge;

  const PendingReviewsBadge({
    super.key,
    required this.child,
    this.showBadge = true,
  });

  @override
  State<PendingReviewsBadge> createState() => _PendingReviewsBadgeState();
}

class _PendingReviewsBadgeState extends State<PendingReviewsBadge> {
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.showBadge) {
      _loadPendingCount();
    }
  }

  Future<void> _loadPendingCount() async {
    final count = await ReviewNotificationService().getPendingReviewsCount();
    if (mounted) {
      setState(() {
        _pendingCount = count;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (widget.showBadge && _pendingCount > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                _pendingCount > 99 ? '99+' : _pendingCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}