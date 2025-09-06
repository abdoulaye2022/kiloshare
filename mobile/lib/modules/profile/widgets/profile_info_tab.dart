import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user_profile.dart';
import 'trust_badge_widget.dart';
import '../../reviews/models/review_model.dart';
import '../../reviews/services/review_service.dart';
import '../../reviews/widgets/review_display_widget.dart';
import '../../reviews/widgets/star_rating_widget.dart';

class ProfileInfoTab extends StatelessWidget {
  final UserProfile profile;
  final VoidCallback onEdit;
  final bool isAuthenticated;

  const ProfileInfoTab({
    super.key,
    required this.profile,
    required this.onEdit,
    this.isAuthenticated = true,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPersonalInfoSection(context),
          const SizedBox(height: 24),
          _buildContactSection(context),
          const SizedBox(height: 24),
          _buildProfessionalSection(context),
          const SizedBox(height: 24),
          _buildTrustSection(context),
          const SizedBox(height: 24),
          _buildRatingSection(context),
          const SizedBox(height: 24),
          _buildEditButton(context),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection(BuildContext context) {
    return _buildSection(
      context,
      title: 'Informations personnelles',
      icon: Icons.person,
      children: [
        if (profile.firstName != null || profile.lastName != null)
          _buildInfoTile(
            icon: Icons.badge,
            title: 'Nom complet',
            value: profile.displayName,
          ),
        if (profile.dateOfBirth != null)
          _buildInfoTile(
            icon: Icons.cake,
            title: 'Date de naissance',
            value: _formatDate(profile.dateOfBirth!),
          ),
        if (profile.gender != null)
          _buildInfoTile(
            icon: Icons.person_outline,
            title: 'Genre',
            value: _getGenderDisplay(profile.gender!),
          ),
        if (profile.bio != null && profile.bio!.isNotEmpty)
          _buildInfoTile(
            icon: Icons.description,
            title: 'Biographie',
            value: profile.bio!,
            isMultiline: true,
          ),
      ],
    );
  }

  Widget _buildContactSection(BuildContext context) {
    List<Widget> contactItems = [];

    if (profile.email != null && profile.email!.isNotEmpty) {
      contactItems.add(_buildInfoTile(
        icon: Icons.email,
        title: 'Email',
        value: profile.email!,
        onTap: () => _launchEmail(profile.email!),
      ));
    }

    if (profile.phone != null && profile.phone!.isNotEmpty) {
      contactItems.add(_buildInfoTile(
        icon: Icons.phone,
        title: 'Téléphone',
        value: profile.phone!,
        onTap: () => _launchPhone(profile.phone!),
      ));
    }

    if (profile.website != null && profile.website!.isNotEmpty) {
      contactItems.add(_buildInfoTile(
        icon: Icons.language,
        title: 'Site web',
        value: profile.website!,
        onTap: () => _launchUrl(profile.website!),
      ));
    }

    if (contactItems.isEmpty) {
      contactItems.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'Aucune information de contact disponible',
            style: TextStyle(
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return _buildSection(
      context,
      title: 'Contact',
      icon: Icons.contact_page,
      children: contactItems,
    );
  }

  Widget _buildProfessionalSection(BuildContext context) {
    List<Widget> professionalItems = [];

    if (profile.profession != null && profile.profession!.isNotEmpty) {
      professionalItems.add(_buildInfoTile(
        icon: Icons.work,
        title: 'Profession',
        value: profile.profession!,
      ));
    }

    if (profile.company != null && profile.company!.isNotEmpty) {
      professionalItems.add(_buildInfoTile(
        icon: Icons.business,
        title: 'Entreprise',
        value: profile.company!,
      ));
    }

    if (professionalItems.isEmpty) {
      professionalItems.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'Aucune information professionnelle disponible',
            style: TextStyle(
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return _buildSection(
      context,
      title: 'Informations professionnelles',
      icon: Icons.work_outline,
      children: professionalItems,
    );
  }

  Widget _buildTrustSection(BuildContext context) {
    return _buildSection(
      context,
      title: 'Confiance et badges',
      icon: Icons.verified_user,
      children: [
        Row(
          children: [
            TrustScoreWidget(
              trustScore: profile.trustScore,
              size: 48,
              showLabel: true,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Niveau: ${_getVerificationLevelDisplay(profile.verificationLevel)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    profile.isVerified ? 'Compte vérifié' : 'Compte non vérifié',
                    style: TextStyle(
                      color: profile.isVerified ? Colors.green : Colors.orange,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (profile.badges.isNotEmpty) ...[
          const Text(
            'Badges obtenus:',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TrustBadgeList(
            badges: profile.badges,
            size: 28,
            showLabels: true,
            maxVisible: 10,
          ),
        ] else
          const Text(
            'Aucun badge obtenu pour le moment',
            style: TextStyle(
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
    VoidCallback? onTap,
    bool isMultiline = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: Colors.grey[600],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      color: onTap != null ? Colors.blue : Colors.black87,
                      decoration: onTap != null ? TextDecoration.underline : null,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.open_in_new,
                size: 14,
                color: Colors.grey[400],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onEdit,
        icon: Icon(isAuthenticated ? Icons.edit : Icons.login),
        label: Text(isAuthenticated ? 'Modifier le profil' : 'Se connecter'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  // Helper methods
  String _formatDate(DateTime date) {
    const months = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
    ];
    
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _getGenderDisplay(String gender) {
    switch (gender) {
      case 'male':
        return 'Homme';
      case 'female':
        return 'Femme';
      case 'other':
        return 'Autre';
      default:
        return gender;
    }
  }

  String _getVerificationLevelDisplay(String level) {
    switch (level) {
      case 'none':
        return 'Non vérifié';
      case 'basic':
        return 'Vérification de base';
      case 'advanced':
        return 'Vérification avancée';
      case 'premium':
        return 'Vérification premium';
      default:
        return level;
    }
  }

  // Launch methods
  Future<void> _launchEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildRatingSection(BuildContext context) {
    return _buildSection(
      context,
      title: 'Évaluations',
      icon: Icons.star,
      children: [
        FutureBuilder<UserRatingModel>(
          future: _getUserRating(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (snapshot.hasError) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Erreur lors du chargement des évaluations',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Aucune donnée d\'évaluation'),
                ),
              );
            }

            final userRating = snapshot.data!;

            if (userRating.totalReviews == 0) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.star_outline,
                        size: 48,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Pas encore d\'évaluations',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: [
                // Rating Header compact
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      // Rating principal
                      Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.star,
                                color: Colors.amber[600],
                                size: 24,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                userRating.averageRating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '/5',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${userRating.totalReviews} avis',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(width: 20),
                      
                      // Détails par rôle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (userRating.asTravelerCount > 0)
                              _buildRoleRating(
                                'Voyageur',
                                userRating.asTravelerRating,
                                userRating.asTravelerCount,
                              ),
                            if (userRating.asSenderCount > 0)
                              _buildRoleRating(
                                'Expéditeur',
                                userRating.asSenderRating,
                                userRating.asSenderCount,
                              ),
                          ],
                        ),
                      ),
                      
                      // Badge si applicable
                      if (userRating.badges.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getBadgeColor(userRating.status),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            userRating.badges.first,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Bouton voir plus
                TextButton(
                  onPressed: () => _showAllReviews(context),
                  child: const Text('Voir toutes les évaluations'),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildRoleRating(String role, double rating, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            '$role: ',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          StarRatingWidget(
            rating: rating,
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            '($count)',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Color _getBadgeColor(String status) {
    switch (status) {
      case 'super_traveler':
        return Colors.green;
      case 'warning':
        return Colors.orange;
      case 'suspended':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  Future<UserRatingModel> _getUserRating() async {
    final reviewService = ReviewService();
    reviewService.initialize();
    return await reviewService.getUserRating(profile.id);
  }

  void _showAllReviews(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserReviewsScreen(
          userId: profile.id,
          userName: profile.displayName,
        ),
      ),
    );
  }
}

// Écran dédié pour afficher toutes les reviews d'un utilisateur
class UserReviewsScreen extends StatefulWidget {
  final int userId;
  final String userName;

  const UserReviewsScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<UserReviewsScreen> createState() => _UserReviewsScreenState();
}

class _UserReviewsScreenState extends State<UserReviewsScreen> {
  final ReviewService _reviewService = ReviewService();
  UserRatingModel? _userRating;
  List<ReviewModel> _reviews = [];
  bool _isLoading = true;
  bool _hasMore = true;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _reviewService.initialize();
    _loadReviews();
  }

  Future<void> _loadReviews({bool loadMore = false}) async {
    if (!loadMore) {
      setState(() {
        _isLoading = true;
        _currentPage = 1;
      });
    }

    try {
      final result = await _reviewService.getUserReviews(
        userId: widget.userId,
        page: _currentPage,
        limit: 10,
      );

      if (mounted) {
        setState(() {
          if (loadMore) {
            _reviews.addAll(result['reviews']);
          } else {
            _userRating = result['user_rating'];
            _reviews = result['reviews'];
          }
          _hasMore = result['has_more'];
          _isLoading = false;
          if (loadMore) _currentPage++;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Évaluations de ${widget.userName}'),
      ),
      body: _isLoading && _reviews.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Header avec rating global
                  if (_userRating != null)
                    UserRatingHeader(
                      userRating: _userRating!,
                      showDetails: true,
                    ),
                  
                  const SizedBox(height: 24),
                  
                  // Liste des reviews
                  ReviewListWidget(
                    reviews: _reviews,
                    showLoadMore: _hasMore,
                    onLoadMore: () => _loadReviews(loadMore: true),
                    isLoading: _isLoading,
                  ),
                ],
              ),
            ),
    );
  }
}