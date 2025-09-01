import 'package:flutter/material.dart';
import '../../../services/stripe_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final StripeService _stripeService = StripeService.instance;
  
  StripeAccountInfo? _accountInfo;
  bool _isLoading = true;
  String? _error;
  bool _isProcessingAction = false;

  @override
  void initState() {
    super.initState();
    _loadStripeAccountInfo();
  }

  Future<void> _loadStripeAccountInfo() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final accountInfo = await _stripeService.getAccountInfo();
      setState(() {
        _accountInfo = accountInfo;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erreur lors du chargement des informations Stripe: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Portefeuille et Paiements'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStripeAccountInfo,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _isLoading 
          ? _buildLoadingWidget()
          : _error != null 
              ? _buildErrorWidget()
              : _buildWalletContent(),
    );
  }

  Widget _buildLoadingWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Chargement des informations...'),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
          const SizedBox(height: 16),
          Text(
            'Erreur de chargement',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.red.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _error ?? 'Une erreur inconnue s\'est produite',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadStripeAccountInfo,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAccountStatusCard(),
          const SizedBox(height: 24),
          _buildInfoSection(),
          const SizedBox(height: 24),
          _buildActionsSection(),
        ],
      ),
    );
  }

  Widget _buildAccountStatusCard() {
    final accountInfo = _accountInfo;
    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (accountInfo == null || accountInfo.needsSetup) {
      statusColor = Colors.grey;
      statusIcon = Icons.account_balance_wallet;
      statusText = 'Portefeuille non configuré';
    } else if (accountInfo.needsOnboarding) {
      statusColor = Colors.orange;
      statusIcon = Icons.hourglass_empty;
      statusText = 'Configuration incomplète';
    } else if (accountInfo.isFullyConfigured) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'Portefeuille configuré';
    } else {
      statusColor = Colors.red;
      statusIcon = Icons.error;
      statusText = 'Statut inconnu';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withOpacity(0.1),
                  radius: 24,
                  child: Icon(statusIcon, color: statusColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Statut du portefeuille',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        statusText,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (accountInfo != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: statusColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        accountInfo.statusDescription,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'À propos de Stripe Connect',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildInfoItem(
                  Icons.security,
                  'Sécurisé',
                  'Vos données bancaires sont protégées par Stripe, leader mondial des paiements en ligne.',
                  Colors.green,
                ),
                const SizedBox(height: 16),
                _buildInfoItem(
                  Icons.speed,
                  'Rapide',
                  'Recevez vos paiements directement sur votre compte bancaire en 2-7 jours ouvrables.',
                  Colors.blue,
                ),
                const SizedBox(height: 16),
                _buildInfoItem(
                  Icons.visibility,
                  'Transparent',
                  'Suivez tous vos gains et transactions en temps réel avec des rapports détaillés.',
                  Colors.purple,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(IconData icon, String title, String description, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          radius: 16,
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionsSection() {
    final accountInfo = _accountInfo;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actions',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (accountInfo?.needsSetup == true) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isProcessingAction ? null : _createStripeAccount,
              icon: _isProcessingAction 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: Text(_isProcessingAction ? 'Configuration...' : 'Configurer mon portefeuille'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ] else if (accountInfo?.needsOnboarding == true) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isProcessingAction ? null : _continueOnboarding,
              icon: _isProcessingAction 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.launch),
              label: Text(_isProcessingAction ? 'Ouverture...' : 'Terminer la configuration'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isProcessingAction ? null : _refreshOnboarding,
              icon: const Icon(Icons.refresh),
              label: const Text('Nouveau lien de configuration'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ] else if (accountInfo?.isFullyConfigured == true) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade600),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Configuration terminée',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Vous pouvez maintenant accepter des réservations et recevoir des paiements.',
                        style: TextStyle(
                          color: Colors.green.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isProcessingAction ? null : _loadStripeAccountInfo,
              icon: const Icon(Icons.refresh),
              label: const Text('Vérifier le statut'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ] else ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.hourglass_empty, color: Colors.orange.shade600),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Statut en cours de vérification',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Votre compte Stripe est en cours de vérification. Cette étape peut prendre de quelques minutes à quelques jours.',
                  style: TextStyle(
                    color: Colors.orange.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _createStripeAccount() async {
    setState(() {
      _isProcessingAction = true;
    });

    try {
      final result = await _stripeService.createConnectedAccount();

      if (result['success'] == true) {
        final onboardingUrl = result['onboarding_url'] as String;
        
        // Ouvrir l'URL d'onboarding
        final launched = await _stripeService.openOnboardingUrl(onboardingUrl);
        
        if (!launched) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Impossible d\'ouvrir le lien de configuration'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Configuration Stripe ouverte dans votre navigateur'),
                backgroundColor: Colors.green,
              ),
            );
            
            // Attendre un peu puis recharger les infos
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                _loadStripeAccountInfo();
              }
            });
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error'] ?? 'Erreur lors de la création du compte'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAction = false;
        });
      }
    }
  }

  Future<void> _continueOnboarding() async {
    setState(() {
      _isProcessingAction = true;
    });

    try {
      final result = await _stripeService.refreshAccountLink();

      if (result['success'] == true) {
        final onboardingUrl = result['onboarding_url'] as String;
        
        // Ouvrir l'URL d'onboarding
        final launched = await _stripeService.openOnboardingUrl(onboardingUrl);
        
        if (!launched) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Impossible d\'ouvrir le lien de configuration'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Configuration Stripe ouverte dans votre navigateur'),
                backgroundColor: Colors.green,
              ),
            );
            
            // Attendre un peu puis recharger les infos
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                _loadStripeAccountInfo();
              }
            });
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error'] ?? 'Erreur lors de la génération du lien'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAction = false;
        });
      }
    }
  }

  Future<void> _refreshOnboarding() async {
    setState(() {
      _isProcessingAction = true;
    });

    try {
      await _continueOnboarding();
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAction = false;
        });
      }
    }
  }
}