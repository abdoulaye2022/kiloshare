import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../../themes/modern_theme.dart';
import '../services/delivery_code_service.dart';
import '../models/delivery_code_model.dart';
import '../../booking/models/booking_model.dart';

class DeliveryCodeValidationScreen extends StatefulWidget {
  final BookingModel booking;

  const DeliveryCodeValidationScreen({
    super.key,
    required this.booking,
  });

  @override
  State<DeliveryCodeValidationScreen> createState() => _DeliveryCodeValidationScreenState();
}

class _DeliveryCodeValidationScreenState extends State<DeliveryCodeValidationScreen> {
  final DeliveryCodeService _deliveryCodeService = DeliveryCodeService.instance;
  final List<TextEditingController> _codeControllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());

  bool _isLoading = false;
  String? _errorMessage;
  int _attemptsRemaining = 3;
  List<File> _selectedPhotos = [];
  Position? _currentPosition;
  bool _isGettingLocation = false;
  DeliveryCodeModel? _deliveryCode;
  bool _isCodeAlreadyUsed = false;

  @override
  void initState() {
    super.initState();
    _loadDeliveryCodeInfo();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    for (var controller in _codeControllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  Future<void> _loadDeliveryCodeInfo() async {
    final result = await _deliveryCodeService.getDeliveryCode(widget.booking.id.toString());
    if (result['success'] && mounted) {
      final deliveryCode = result['delivery_code'] as DeliveryCodeModel;
      setState(() {
        _deliveryCode = deliveryCode;
        _attemptsRemaining = deliveryCode.attemptsRemaining;
        _isCodeAlreadyUsed = deliveryCode.hasBeenUsed;
      });

      // Si le code a déjà été utilisé, afficher un message et empêcher la validation
      if (_isCodeAlreadyUsed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showAlreadyValidatedDialog();
        });
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    try {
      // Vérifier les permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        throw Exception('Permissions de géolocalisation refusées');
      }

      // Obtenir la position
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      setState(() {
        _currentPosition = position;
        _isGettingLocation = false;
      });
    } catch (e) {
      setState(() {
        _isGettingLocation = false;
      });
      _showErrorDialog('Erreur de géolocalisation',
          'Impossible d\'obtenir votre position. Assurez-vous que la géolocalisation est activée.');
    }
  }

  String get _enteredCode {
    return _codeControllers.map((controller) => controller.text).join();
  }

  bool get _isCodeComplete {
    return _enteredCode.length == 6 && _enteredCode.replaceAll(RegExp(r'\D'), '').length == 6;
  }

  void _onCodeChanged(int index, String value) {
    // Permettre seulement les chiffres
    if (value.isNotEmpty && !RegExp(r'^[0-9]$').hasMatch(value)) {
      _codeControllers[index].clear();
      return;
    }

    if (value.isNotEmpty) {
      // Passer au champ suivant
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        // Dernier champ, enlever le focus
        _focusNodes[index].unfocus();
      }
    }

    setState(() {
      _errorMessage = null;
    });
  }

  void _onCodeKeyDown(int index, KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
      if (_codeControllers[index].text.isEmpty && index > 0) {
        // Revenir au champ précédent si le champ actuel est vide
        _focusNodes[index - 1].requestFocus();
      }
    }
  }

  Future<void> _validateCode() async {
    if (!_isCodeComplete) {
      setState(() {
        _errorMessage = 'Veuillez saisir un code à 6 chiffres';
      });
      return;
    }

    if (_currentPosition == null) {
      _showErrorDialog('Géolocalisation requise',
          'La géolocalisation est requise pour valider le code de livraison.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // TODO: Upload photos first if selected and get URLs
      List<String>? photoUrls;
      if (_selectedPhotos.isNotEmpty) {
        // For now, skip photo upload - will be implemented later
        photoUrls = [];
      }

      final result = await _deliveryCodeService.validateDeliveryCode(
        bookingId: widget.booking.id.toString(),
        code: _enteredCode,
        latitude: _currentPosition?.latitude,
        longitude: _currentPosition?.longitude,
        photoUrls: photoUrls,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (result['success']) {
          _showSuccessDialog(result['message']);
        } else {
          setState(() {
            _errorMessage = result['error'];
            _attemptsRemaining = result['attempts_remaining'] ?? 0;
          });

          // Effacer le code si incorrect
          _clearCode();

          if (_attemptsRemaining <= 0) {
            _showErrorDialog('Code expiré',
                'Vous avez atteint le nombre maximum de tentatives. Le code est maintenant expiré.');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erreur de connexion: $e';
        });
      }
    }
  }

  void _clearCode() {
    for (var controller in _codeControllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();
  }

  Future<void> _takePhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(source: ImageSource.camera);
      if (photo != null && mounted) {
        setState(() {
          _selectedPhotos.add(File(photo.path));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la prise de photo: $e')),
        );
      }
    }
  }

  Future<void> _pickPhotos() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> photos = await picker.pickMultiImage(limit: 3 - _selectedPhotos.length);
      if (photos.isNotEmpty && mounted) {
        setState(() {
          _selectedPhotos.addAll(photos.map((xFile) => File(xFile.path)));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la sélection des photos: $e')),
        );
      }
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _selectedPhotos.removeAt(index);
    });
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.check_circle,
          color: ModernTheme.success,
          size: 64,
        ),
        title: const Text('Livraison confirmée'),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Fermer dialog
              Navigator.of(context).pop(true); // Retourner à l'écran précédent avec succès
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.success,
              foregroundColor: Colors.white,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.error_outline,
          color: ModernTheme.error,
          size: 64,
        ),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showAlreadyValidatedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.check_circle,
          color: ModernTheme.success,
          size: 64,
        ),
        title: const Text('Code déjà validé'),
        content: Text(
          'Ce code de livraison a déjà été validé${_deliveryCode?.usedAt != null ? ' le ${_formatDate(_deliveryCode!.usedAt!)}' : ''}. '
          'La livraison a été confirmée avec succès.\n\n'
          'Vous pouvez fermer cet écran.'
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Fermer dialog
              Navigator.of(context).pop(); // Retourner à l'écran précédent
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.success,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retour'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} à ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.gray50,
      appBar: AppBar(
        title: const Text('Code de livraison'),
        backgroundColor: ModernTheme.white,
        elevation: 0,
        iconTheme: IconThemeData(color: ModernTheme.gray700),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ModernTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Informations de la réservation
            _buildBookingInfo(),
            const SizedBox(height: ModernTheme.spacing24),

            // Instructions
            _buildInstructions(),
            const SizedBox(height: ModernTheme.spacing24),

            // Saisie du code
            _buildCodeInput(),
            const SizedBox(height: ModernTheme.spacing24),

            // Géolocalisation
            _buildLocationSection(),
            const SizedBox(height: ModernTheme.spacing24),

            // Photos
            _buildPhotosSection(),
            const SizedBox(height: ModernTheme.spacing32),

            // Bouton de validation
            _buildValidationButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingInfo() {
    return Container(
      padding: const EdgeInsets.all(ModernTheme.spacing16),
      decoration: BoxDecoration(
        color: ModernTheme.white,
        borderRadius: BorderRadius.circular(ModernTheme.radiusLarge),
        boxShadow: ModernTheme.shadowSmall,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_shipping, color: ModernTheme.primaryBlue),
              const SizedBox(width: ModernTheme.spacing8),
              Expanded(
                child: Text(
                  'Réservation #${widget.booking.id}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: ModernTheme.spacing12),
          Text(
            'Colis: ${widget.booking.packageDescription}',
            style: TextStyle(
              color: ModernTheme.gray600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: ModernTheme.spacing8),
          Text(
            'Poids: ${widget.booking.weightKg} kg',
            style: TextStyle(
              color: ModernTheme.gray600,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(ModernTheme.spacing16),
      decoration: BoxDecoration(
        color: ModernTheme.lightBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(ModernTheme.radiusMedium),
        border: Border.all(color: ModernTheme.primaryBlue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: ModernTheme.primaryBlue),
              const SizedBox(width: ModernTheme.spacing8),
              const Text(
                'Instructions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: ModernTheme.spacing12),
          const Text(
            '1. Demandez le code à 6 chiffres à l\'expéditeur\n'
            '2. Saisissez le code ci-dessous\n'
            '3. Prenez une photo du colis (obligatoire)\n'
            '4. Validez pour confirmer la livraison',
            style: TextStyle(fontSize: 14),
          ),
          if (_attemptsRemaining > 0) ...[
            const SizedBox(height: ModernTheme.spacing12),
            Text(
              'Tentatives restantes: $_attemptsRemaining',
              style: TextStyle(
                color: _attemptsRemaining <= 1 ? ModernTheme.error : ModernTheme.warning,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCodeInput() {
    return Container(
      padding: const EdgeInsets.all(ModernTheme.spacing16),
      decoration: BoxDecoration(
        color: ModernTheme.white,
        borderRadius: BorderRadius.circular(ModernTheme.radiusLarge),
        boxShadow: ModernTheme.shadowSmall,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Code de livraison',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: ModernTheme.spacing16),

          // Champs de saisie du code
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(6, (index) {
              return SizedBox(
                width: 40,
                height: 50,
                child: TextField(
                  controller: _codeControllers[index],
                  focusNode: _focusNodes[index],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(1),
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ModernTheme.radiusSmall),
                      borderSide: BorderSide(color: ModernTheme.gray300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ModernTheme.radiusSmall),
                      borderSide: BorderSide(color: ModernTheme.primaryBlue, width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ModernTheme.radiusSmall),
                      borderSide: BorderSide(color: ModernTheme.error, width: 2),
                    ),
                  ),
                  onChanged: (value) => _onCodeChanged(index, value),
                  onSubmitted: (_) {
                    if (_isCodeComplete) {
                      _validateCode();
                    }
                  },
                ),
              );
            }),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: ModernTheme.spacing12),
            Container(
              padding: const EdgeInsets.all(ModernTheme.spacing12),
              decoration: BoxDecoration(
                color: ModernTheme.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(ModernTheme.radiusSmall),
                border: Border.all(color: ModernTheme.error.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: ModernTheme.error, size: 20),
                  const SizedBox(width: ModernTheme.spacing8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: ModernTheme.error,
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
    );
  }

  Widget _buildLocationSection() {
    return Container(
      padding: const EdgeInsets.all(ModernTheme.spacing16),
      decoration: BoxDecoration(
        color: ModernTheme.white,
        borderRadius: BorderRadius.circular(ModernTheme.radiusLarge),
        boxShadow: ModernTheme.shadowSmall,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_on,
                color: _currentPosition != null ? ModernTheme.success : ModernTheme.warning,
              ),
              const SizedBox(width: ModernTheme.spacing8),
              const Text(
                'Géolocalisation',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: ModernTheme.spacing12),

          if (_isGettingLocation)
            const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: ModernTheme.spacing8),
                Text('Obtention de votre position...'),
              ],
            )
          else if (_currentPosition != null)
            Row(
              children: [
                Icon(Icons.check_circle, color: ModernTheme.success, size: 20),
                const SizedBox(width: ModernTheme.spacing8),
                const Text('Position obtenue avec succès'),
              ],
            )
          else
            Row(
              children: [
                Icon(Icons.warning, color: ModernTheme.warning, size: 20),
                const SizedBox(width: ModernTheme.spacing8),
                const Expanded(child: Text('Position non disponible')),
                TextButton(
                  onPressed: _getCurrentLocation,
                  child: const Text('Réessayer'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPhotosSection() {
    return Container(
      padding: const EdgeInsets.all(ModernTheme.spacing16),
      decoration: BoxDecoration(
        color: ModernTheme.white,
        borderRadius: BorderRadius.circular(ModernTheme.radiusLarge),
        boxShadow: ModernTheme.shadowSmall,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.camera_alt, color: ModernTheme.primaryBlue),
              const SizedBox(width: ModernTheme.spacing8),
              const Text(
                'Photos du colis (obligatoire)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: ModernTheme.spacing16),

          // Photos sélectionnées
          if (_selectedPhotos.isNotEmpty) ...[
            Wrap(
              spacing: ModernTheme.spacing8,
              runSpacing: ModernTheme.spacing8,
              children: _selectedPhotos.asMap().entries.map((entry) {
                final index = entry.key;
                final photo = entry.value;
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(ModernTheme.radiusSmall),
                      child: Image.file(
                        photo,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _removePhoto(index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
            const SizedBox(height: ModernTheme.spacing16),
          ],

          // Boutons pour ajouter des photos
          if (_selectedPhotos.length < 3) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _takePhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Prendre photo'),
                  ),
                ),
                const SizedBox(width: ModernTheme.spacing8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickPhotos,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Galerie'),
                  ),
                ),
              ],
            ),
          ],

          if (_selectedPhotos.isEmpty) ...[
            const SizedBox(height: ModernTheme.spacing12),
            Container(
              padding: const EdgeInsets.all(ModernTheme.spacing12),
              decoration: BoxDecoration(
                color: ModernTheme.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(ModernTheme.radiusSmall),
                border: Border.all(color: ModernTheme.warning.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: ModernTheme.warning, size: 20),
                  const SizedBox(width: ModernTheme.spacing8),
                  const Expanded(
                    child: Text(
                      'Au moins une photo du colis est requise pour confirmer la livraison',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildValidationButton() {
    final canValidate = _isCodeComplete &&
                       _currentPosition != null &&
                       _selectedPhotos.isNotEmpty &&
                       !_isLoading &&
                       _attemptsRemaining > 0 &&
                       !_isCodeAlreadyUsed;

    return Column(
      children: [
        // Message si le code est déjà utilisé
        if (_isCodeAlreadyUsed) ...[
          Container(
            padding: const EdgeInsets.all(ModernTheme.spacing16),
            margin: const EdgeInsets.only(bottom: ModernTheme.spacing16),
            decoration: BoxDecoration(
              color: ModernTheme.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(ModernTheme.radiusMedium),
              border: Border.all(color: ModernTheme.success.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: ModernTheme.success),
                const SizedBox(width: ModernTheme.spacing8),
                Expanded(
                  child: Text(
                    'Ce code a déjà été validé. La livraison est confirmée.',
                    style: TextStyle(
                      color: ModernTheme.success,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Bouton de validation
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: canValidate ? _validateCode : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isCodeAlreadyUsed ? ModernTheme.gray400 : ModernTheme.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ModernTheme.radiusMedium),
              ),
              elevation: canValidate ? 4 : 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    _isCodeAlreadyUsed ? 'Code déjà validé' : 'Confirmer la livraison',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}