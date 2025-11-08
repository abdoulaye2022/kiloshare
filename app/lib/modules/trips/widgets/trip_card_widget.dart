import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kiloshare/widgets/ellipsis_button.dart';
import '../models/trip_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../profile/widgets/avatar_display_widget.dart';

class TripCardWidget extends StatelessWidget {
  final Trip trip;
  final VoidCallback? onTap;
  final bool showUserInfo;
  final bool isCompact;
  final bool isAuthenticated;
  final Widget? trailing;

  const TripCardWidget({
    super.key,
    required this.trip,
    this.onTap,
    this.showUserInfo = true,
    this.isCompact = false,
    this.isAuthenticated = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            // Image à gauche (si disponible)
            if (trip.hasImages && trip.primaryImage != null)
              Container(
                width: 80,
                height: 120,
                margin: const EdgeInsets.only(right: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: trip.primaryImage!.thumbnail ?? trip.primaryImage!.url,
                    width: 80,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            
            // Contenu principal à droite
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with route and status
                    _buildHeader(context),
                    
                    const SizedBox(height: 12),
                    
                    // Main info
                    _buildMainInfo(context),
              
              if (!isCompact) ...[
                const SizedBox(height: 12),
                
                // Pricing and capacity
                _buildPricingInfo(context),
                
                if (showUserInfo && trip.user != null) ...[
                  const SizedBox(height: 12),
                  _buildUserInfo(context),
                ],
                
                const SizedBox(height: 8),
                
                      // Footer with additional info
                      _buildFooter(context),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        // Route
        Expanded(
          child: Row(
            children: [
              Icon(
                Icons.flight_takeoff,
                size: 20,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  trip.routeDisplay,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        
        // Status badge
        _buildStatusBadge(context),
        
        // Verified ticket badge
        if (trip.ticketVerified)
          Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified, size: 12, color: Colors.green[700]),
                const SizedBox(width: 2),
                Text(
                  'Vérifié',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
          ),
        
        // Trailing widget (e.g., menu button)
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );
  }

  Widget _buildMainInfo(BuildContext context) {
    final dateFormatter = DateFormat('dd MMM yyyy', 'fr_FR');
    final timeFormatter = DateFormat('HH:mm', 'fr_FR');
    final monthYearFormatter = DateFormat('MMM yyyy', 'fr_FR');
    
    return Row(
      children: [
        // Departure info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Départ',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isAuthenticated 
                    ? dateFormatter.format(trip.departureDate.toLocal())
                    : monthYearFormatter.format(trip.departureDate.toLocal()),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isAuthenticated)
                Text(
                  timeFormatter.format(trip.departureDate.toLocal()),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
            ],
          ),
        ),
        
        // Duration indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: [
              Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
              const SizedBox(height: 2),
              Text(
                trip.durationDisplay,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        
        // Arrival info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Arrivée',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isAuthenticated 
                    ? dateFormatter.format(trip.arrivalDate.toLocal())
                    : monthYearFormatter.format(trip.arrivalDate.toLocal()),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isAuthenticated)
                Text(
                  timeFormatter.format(trip.arrivalDate.toLocal()),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPricingInfo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          // Weight capacity
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.luggage, size: 16, color: Colors.blue[700]),
                    const SizedBox(width: 4),
                    Text(
                      'Capacité',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _getWeightDisplay(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
              ],
            ),
          ),
          
          // Price per kg
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.attach_money, size: 16, color: Colors.blue[700]),
                    const SizedBox(width: 4),
                    Text(
                      'Prix/kg',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _getPriceDisplay(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isAuthenticated ? Colors.blue[800] : Colors.orange[700],
                  ),
                ),
              ],
            ),
          ),
          
          // Total earnings potential
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(Icons.account_balance_wallet, size: 16, color: Colors.blue[700]),
                    const SizedBox(width: 4),
                    Text(
                      'Max',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _getMaxEarningsDisplay(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isAuthenticated ? Colors.blue[800] : Colors.orange[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfo(BuildContext context) {
    final user = trip.user!;
    
    return Row(
      children: [
        // Avatar
        isAuthenticated
            ? AvatarDisplayWidget(
                avatarUrl: user.profilePicture,
                userName: user.displayName,
                size: 32,
                borderWidth: 0,
              )
            : CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey[300],
                child: Icon(
                  Icons.person,
                  size: 20,
                  color: Colors.grey[600],
                ),
              ),
        
        const SizedBox(width: 8),
        
        // User name and verified status
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    isAuthenticated ? user.displayName : 'Transporteur vérifié',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (user.isVerified) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.verified,
                      size: 14,
                      color: Colors.blue[600],
                    ),
                  ],
                ],
              ),
              Text(
                isAuthenticated ? 'Transporteur' : 'Connectez-vous pour voir plus',
                style: TextStyle(
                  fontSize: 12,
                  color: isAuthenticated ? Colors.grey[600] : Colors.orange[600],
                ),
              ),
            ],
          ),
        ),
        
        // Rating placeholder
        Row(
          children: [
            Icon(Icons.star, size: 14, color: Colors.amber[600]),
            const SizedBox(width: 2),
            const Text(
              '4.8',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Row(
      children: [
        // Flight info
        if (trip.airline != null || trip.flightNumber != null)
          Expanded(
            child: Row(
              children: [
                Icon(Icons.airplane_ticket, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  [trip.airline, trip.flightNumber]
                      .where((e) => e != null)
                      .join(' • '),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        
        // Days remaining
        if (trip.remainingDays > 0) ...[
          if (trip.airline != null || trip.flightNumber != null)
            const SizedBox(width: 16),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _getRemainingDaysColor(trip.remainingDays).withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Dans ${trip.remainingDays} jour${trip.remainingDays > 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _getRemainingDaysColor(trip.remainingDays),
              ),
            ),
          ),
        ],
        
        // Views count
        if (trip.viewCount > 0) ...[
          const SizedBox(width: 8),
          Row(
            children: [
              Icon(Icons.visibility, size: 12, color: Colors.grey[500]),
              const SizedBox(width: 2),
              Text(
                trip.viewCount.toString(),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    Color color;
    String text;

    switch (trip.status) {
      case TripStatus.draft:
        color = Colors.orange;
        text = 'Brouillon';
        break;
      case TripStatus.pendingApproval:
        color = Colors.amber;
        text = 'En attente';
        break;
      case TripStatus.active:
        color = Colors.green;
        text = 'Publié';
        break;
      case TripStatus.rejected:
        color = Colors.red;
        text = 'Rejeté';
        break;
      case TripStatus.pendingReview:
        color = Colors.purple;
        text = 'En révision';
        break;
      case TripStatus.booked:
        color = Colors.orange;
        text = 'Réservé';
        break;
      case TripStatus.inProgress:
        color = Colors.indigo;
        text = 'En cours';
        break;
      case TripStatus.completed:
        color = Colors.blue;
        text = 'Terminé';
        break;
      case TripStatus.cancelled:
        color = Colors.grey;
        text = 'Annulé';
        break;
      case TripStatus.paused:
        color = Colors.yellow;
        text = 'En pause';
        break;
      case TripStatus.expired:
        color = Colors.brown;
        text = 'Expiré';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color.withOpacity(0.8),
        ),
      ),
    );
  }

  Color _getRemainingDaysColor(int days) {
    if (days <= 1) return Colors.red;
    if (days <= 3) return Colors.orange;
    if (days <= 7) return Colors.blue;
    return Colors.green;
  }

  String _getWeightDisplay() {
    if (isAuthenticated) {
      return '${trip.availableWeightKg.toStringAsFixed(1)} kg';
    } else {
      // Show weight range for non-authenticated users
      final weight = trip.availableWeightKg;
      if (weight <= 5) {
        return '1-5 kg';
      } else if (weight <= 10) {
        return '5-10 kg';
      } else if (weight <= 15) {
        return '10-15 kg';
      } else if (weight <= 20) {
        return '15-20 kg';
      } else {
        return '20+ kg';
      }
    }
  }

  String _getPriceDisplay() {
    if (isAuthenticated) {
      return '${trip.pricePerKg.toStringAsFixed(2)} ${trip.currency}';
    } else {
      return 'Connectez-vous\npour voir le prix';
    }
  }

  String _getMaxEarningsDisplay() {
    if (isAuthenticated) {
      return '${trip.totalEarningsPotential.toStringAsFixed(0)} ${trip.currency}';
    } else {
      return 'Prix\ndisponible';
    }
  }
}