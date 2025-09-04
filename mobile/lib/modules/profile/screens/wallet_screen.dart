import 'package:flutter/material.dart';
import '../../../services/stripe_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> with WidgetsBindingObserver {
  final StripeService _stripeService = StripeService.instance;
  
  Map<String, dynamic>? _accountInfo;
  bool _isLoading = true;
  String? _error;
  bool _isProcessingAction = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadStripeAccountInfo();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Recharger les infos quand l'utilisateur revient dans l'app
    // Ceci est utile après avoir complété l'onboarding Stripe dans le navigateur
    if (state == AppLifecycleState.resumed) {
      _loadStripeAccountInfo();
    }
  }

  Future<void> _loadStripeAccountInfo() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _stripeService.getAccountStatus();
      final accountInfo = result['success'] == true ? result : null;
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

    if (accountInfo == null) {
      statusColor = Colors.red;
      statusIcon = Icons.error;
      statusText = 'Erreur de chargement';
    } else {
      final hasAccount = accountInfo['has_account'] == true;
      final transactionReady = accountInfo['transaction_ready'] == true;
      final onboardingComplete = accountInfo['onboarding_complete'] == true;
      final account = accountInfo['account'];
      final hasRestrictions = account?['has_restrictions'] == true;

      if (!hasAccount) {
        statusColor = Colors.grey;
        statusIcon = Icons.account_balance_wallet;
        statusText = 'Portefeuille non configuré';
      } else if (hasRestrictions) {
        statusColor = Colors.orange;
        statusIcon = Icons.verified_user;
        statusText = 'Vérification d\'identité requise';
      } else if (!onboardingComplete) {
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
        statusText = 'Configuration incomplète';
      } else if (!transactionReady) {
        statusColor = Colors.blue;
        statusIcon = Icons.pending;
        statusText = 'En cours de vérification';
      } else {
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Portefeuille configuré';
      }
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
                        accountInfo['message'] ?? 'Aucune information disponible',
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
            // Section spéciale pour la vérification d'identité
            if (accountInfo != null && 
                accountInfo['onboarding_complete'] == true && 
                accountInfo['account']?['has_restrictions'] == true) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Vérification d\'identité requise',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Votre compte Stripe est configuré mais nécessite une vérification d\'identité pour accepter des paiements. Cette étape est requise par Stripe pour assurer la sécurité des transactions.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Configuration bancaire: ✅ Terminée\n'
                      '• Vérification d\'identité: ⏳ En attente',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        height: 1.3,
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
        if (accountInfo != null && accountInfo['has_account'] != true) ...[
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
        ] else if (accountInfo != null && (accountInfo['onboarding_complete'] != true || accountInfo['account']?['has_restrictions'] == true)) ...[
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
              label: Text(_isProcessingAction ? 'Ouverture...' : 
                accountInfo['account']?['has_restrictions'] == true ? 
                'Compléter la vérification d\'identité' : 
                'Terminer la configuration'),
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
        ] else if (accountInfo != null && accountInfo['transaction_ready'] == true) ...[
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
      // Déterminer quelle étape du processus d'onboarding
      final bool hasRestrictions = _accountInfo?['account']?['has_restrictions'] == true;
      final bool onboardingComplete = _accountInfo?['onboarding_complete'] == true;
      
      Map<String, dynamic> result;
      
      if (!onboardingComplete) {
        // Étape 1: Configuration initiale (informations bancaires)
        result = await _stripeService.refreshAccountLink();
      } else if (hasRestrictions) {
        // Étape 2: Vérification d'identité
        result = await _stripeService.refreshAccountLink();
      } else {
        // Cas où l'account est déjà complet
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Votre compte Stripe est déjà configuré'),
              backgroundColor: Colors.green,
            ),
          );
        }
        return;
      }

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
            String message;
            if (!onboardingComplete) {
              message = 'Configuration bancaire Stripe ouverte dans votre navigateur';
            } else {
              message = 'Vérification d\'identité Stripe ouverte dans votre navigateur';
            }
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
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