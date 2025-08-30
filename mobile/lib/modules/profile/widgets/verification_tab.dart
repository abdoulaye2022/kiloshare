import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/user_profile.dart';
import '../bloc/profile_bloc.dart';
import '../bloc/profile_event.dart';
import 'trust_badge_widget.dart';

class VerificationTab extends StatelessWidget {
  final UserProfile profile;
  final List<VerificationDocument> documents;
  final List<TrustBadge> badges;
  final VerificationStatus verificationStatus;
  final VoidCallback onUploadDocument;

  const VerificationTab({
    super.key,
    required this.profile,
    required this.documents,
    required this.badges,
    required this.verificationStatus,
    required this.onUploadDocument,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildVerificationOverview(context),
          const SizedBox(height: 24),
          _buildDocumentsSection(context),
          const SizedBox(height: 24),
          _buildBadgesSection(context),
        ],
      ),
    );
  }

  Widget _buildVerificationOverview(BuildContext context) {
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
                  Icons.verified_user,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Statut de vérification',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Trust Score
            Row(
              children: [
                TrustScoreWidget(
                  trustScore: verificationStatus.trustScore,
                  size: 60,
                  showLabel: false,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Score de confiance',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        '${(verificationStatus.trustScore * 100).toInt()}/100',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _getScoreColor(verificationStatus.trustScore),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Verification Level Progress
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Niveau de vérification',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      verificationStatus.levelDisplay,
                      style: TextStyle(
                        color: _getVerificationLevelColor(verificationStatus.verificationLevel),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: verificationStatus.completionPercentage,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getVerificationLevelColor(verificationStatus.verificationLevel),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(verificationStatus.completionPercentage * 100).toInt()}% complété',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Statistics
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  context,
                  'Documents',
                  '${verificationStatus.documentsCount}',
                  Icons.description,
                ),
                _buildStatItem(
                  context,
                  'Approuvés',
                  '${verificationStatus.approvedDocuments}',
                  Icons.check_circle,
                  color: Colors.green,
                ),
                _buildStatItem(
                  context,
                  'Badges',
                  '${verificationStatus.badgesCount}',
                  Icons.emoji_events,
                  color: Colors.amber,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: color ?? Theme.of(context).primaryColor,
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color ?? Theme.of(context).primaryColor,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentsSection(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.description),
                    const SizedBox(width: 8),
                    Text(
                      'Documents de vérification',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: onUploadDocument,
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: const Text('Ajouter'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (documents.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 48,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Aucun document téléchargé',
                        style: TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...documents.map((document) => _buildDocumentTile(context, document)),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentTile(BuildContext context, VerificationDocument document) {
    Color statusColor = _getDocumentStatusColor(document.status);
    IconData statusIcon = _getDocumentStatusIcon(document.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            statusIcon,
            color: statusColor,
            size: 20,
          ),
        ),
        title: Text(
          document.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Statut: ${document.statusDisplay}',
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'Téléchargé le ${_formatDate(document.uploadedAt)}',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 11,
              ),
            ),
            if (document.expiryDate != null && !document.isExpired)
              Text(
                'Expire le ${_formatDate(document.expiryDate!)}',
                style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 11,
                ),
              ),
            if (document.isExpired)
              const Text(
                'DOCUMENT EXPIRÉ',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'delete':
                _showDeleteConfirmation(context, document);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Supprimer'),
                ],
              ),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildBadgesSection(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events),
                const SizedBox(width: 8),
                Text(
                  'Badges de confiance',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (badges.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.emoji_events_outlined,
                        size: 48,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Aucun badge obtenu',
                        style: TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Complétez votre profil et téléchargez des documents pour obtenir des badges',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              TrustBadgeList(
                badges: badges,
                size: 32,
                showLabels: true,
                maxVisible: 20,
                alignment: MainAxisAlignment.center,
              ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  Color _getScoreColor(double score) {
    if (score >= 0.8) return const Color(0xFF10B981);
    if (score >= 0.6) return const Color(0xFF3B82F6);
    if (score >= 0.4) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  Color _getVerificationLevelColor(String level) {
    switch (level) {
      case 'none':
        return Colors.grey;
      case 'basic':
        return Colors.blue;
      case 'advanced':
        return Colors.green;
      case 'premium':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Color _getDocumentStatusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'expired':
        return Colors.orange;
      case 'pending':
      default:
        return Colors.amber;
    }
  }

  IconData _getDocumentStatusIcon(String status) {
    switch (status) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'expired':
        return Icons.schedule;
      case 'pending':
      default:
        return Icons.access_time;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
           '${date.month.toString().padLeft(2, '0')}/'
           '${date.year}';
  }

  void _showDeleteConfirmation(BuildContext context, VerificationDocument document) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le document'),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer "${document.displayName}" ?'
          '\n\nCette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<ProfileBloc>().add(DeleteDocument(documentId: document.id));
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}