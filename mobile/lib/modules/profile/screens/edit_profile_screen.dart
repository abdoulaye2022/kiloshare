import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';

import '../../auth/blocs/auth/auth_bloc.dart';
import '../../auth/blocs/auth/auth_state.dart';
import '../../auth/blocs/auth/auth_event.dart';
import '../models/user_profile.dart';
import '../services/profile_service.dart';
import '../../../themes/modern_theme.dart';
import '../../../widgets/optimized_cloudinary_image.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final ProfileService _profileService = ProfileService();
  final ImagePicker _imagePicker = ImagePicker();
  
  // Controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();
  final _professionController = TextEditingController();
  final _companyController = TextEditingController();
  final _websiteController = TextEditingController();
  final _addressLine1Controller = TextEditingController();
  final _addressLine2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _stateProvinceController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _nationalityController = TextEditingController();
  final _emergencyContactNameController = TextEditingController();
  final _emergencyContactPhoneController = TextEditingController();
  final _emergencyContactRelationController = TextEditingController();
  
  // State
  File? _selectedImage;
  String? _selectedGender;
  String? _selectedCountry;
  String? _selectedLanguage;
  String? _selectedTimezone;
  String? _selectedProfileVisibility;
  DateTime? _selectedBirthDate;
  UserProfile? _currentProfile;
  bool _isLoading = false;
  bool _isLoadingProfile = true;
  bool _newsletterSubscribed = true;
  bool _marketingEmails = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _professionController.dispose();
    _companyController.dispose();
    _websiteController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _cityController.dispose();
    _stateProvinceController.dispose();
    _postalCodeController.dispose();
    _nationalityController.dispose();
    _emergencyContactNameController.dispose();
    _emergencyContactPhoneController.dispose();
    _emergencyContactRelationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await _profileService.getUserProfile();
      if (profile != null) {
        setState(() {
          _currentProfile = profile;
          _firstNameController.text = profile.firstName ?? '';
          _lastNameController.text = profile.lastName ?? '';
          _phoneController.text = profile.phone ?? '';
          _bioController.text = profile.bio ?? '';
          _professionController.text = profile.profession ?? '';
          _companyController.text = profile.company ?? '';
          _websiteController.text = profile.website ?? '';
          _addressLine1Controller.text = profile.addressLine1 ?? profile.address ?? '';
          _addressLine2Controller.text = profile.addressLine2 ?? '';
          _cityController.text = profile.city ?? '';
          _stateProvinceController.text = profile.stateProvince ?? '';
          _postalCodeController.text = profile.postalCode ?? '';
          _nationalityController.text = profile.nationality ?? '';
          _emergencyContactNameController.text = profile.emergencyContactName ?? '';
          _emergencyContactPhoneController.text = profile.emergencyContactPhone ?? '';
          _emergencyContactRelationController.text = profile.emergencyContactRelation ?? '';
          // Utiliser les valeurs du profil ou des valeurs par défaut
          _selectedLanguage = profile.preferredLanguage ?? 'fr';
          _selectedTimezone = profile.timezone ?? 'Europe/Paris';
          _selectedProfileVisibility = profile.profileVisibility ?? 'public';
          _selectedGender = profile.gender ?? '';
          _selectedCountry = profile.country ?? '';
          _selectedBirthDate = profile.dateOfBirth;
          _newsletterSubscribed = profile.newsletterSubscribed ?? false;
          _marketingEmails = profile.marketingEmails ?? false;
          _isLoadingProfile = false;
        });
      } else {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingProfile = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement du profil: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _selectBirthDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 13)), // Minimum 13 ans
    );
    
    if (picked != null) {
      setState(() {
        _selectedBirthDate = picked;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? avatarUrl;
      
      // Upload avatar if selected
      if (_selectedImage != null) {
        avatarUrl = await _profileService.uploadAvatar(_selectedImage!);
      }

      // Prepare profile data
      final profileData = {
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'bio': _bioController.text.trim(),
        'profession': _professionController.text.trim(),
        'company': _companyController.text.trim(),
        'website': _websiteController.text.trim(),
        'address_line1': _addressLine1Controller.text.trim(),
        'address_line2': _addressLine2Controller.text.trim(),
        'city': _cityController.text.trim(),
        'state_province': _stateProvinceController.text.trim(),
        'postal_code': _postalCodeController.text.trim(),
        'gender': _selectedGender,
        'country': _selectedCountry,
        'nationality': _nationalityController.text.trim(),
        'date_of_birth': _selectedBirthDate?.toIso8601String().split('T')[0],
        'emergency_contact_name': _emergencyContactNameController.text.trim(),
        'emergency_contact_phone': _emergencyContactPhoneController.text.trim(),
        'emergency_contact_relation': _emergencyContactRelationController.text.trim(),
        'preferred_language': _selectedLanguage,
        'timezone': _selectedTimezone,
        'profile_visibility': _selectedProfileVisibility,
        'newsletter_subscribed': _newsletterSubscribed ? 1 : 0,
        'marketing_emails': _marketingEmails ? 1 : 0,
        if (avatarUrl != null) 'profile_picture': avatarUrl,
      };

      // Remove empty values
      profileData.removeWhere((key, value) => value == null || value.toString().trim().isEmpty);

      // Validate data
      final validationError = _profileService.validateProfileData(profileData);
      if (validationError != null) {
        throw Exception(validationError);
      }

      // Update or create profile
      if (_currentProfile != null) {
        await _profileService.updateUserProfile(profileData);
      } else {
        await _profileService.createUserProfile(profileData);
      }

      if (mounted) {
        // Refresh current user in AuthBloc to update avatar in all screens
        final authState = context.read<AuthBloc>().state;
        if (authState is AuthAuthenticated) {
          // Get updated user profile
          final updatedProfile = await _profileService.getUserProfile();
          if (updatedProfile != null) {
            // Update AuthBloc with new profile picture and basic info
            final updatedUser = authState.user.copyWith(
              profilePicture: updatedProfile.avatarUrl,
              firstName: updatedProfile.firstName,
              lastName: updatedProfile.lastName,
            );
            if (mounted) {
              context.read<AuthBloc>().add(AuthUserUpdated(user: updatedUser));
            }
          }
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil sauvegardé avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
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
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.gray50,
      appBar: AppBar(
        title: Text(
          'Modifier le profil',
          style: TextStyle(
            color: ModernTheme.gray900,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: ModernTheme.white,
        elevation: 0,
        iconTheme: IconThemeData(color: ModernTheme.gray700),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Sauvegarder'),
          ),
        ],
      ),
      body: _isLoadingProfile
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildAvatarSection(),
                    const SizedBox(height: 24),
                    _buildPersonalInfoSection(),
                    const SizedBox(height: 24),
                    _buildContactInfoSection(),
                    const SizedBox(height: 24),
                    _buildProfessionalInfoSection(),
                    const SizedBox(height: 24),
                    _buildAddressSection(),
                    const SizedBox(height: 24),
                    _buildAdditionalInfoSection(),
                    const SizedBox(height: 24),
                    _buildEmergencyContactSection(),
                    const SizedBox(height: 24),
                    _buildPreferencesSection(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAvatarSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              'Photo de profil',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Stack(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300, width: 2),
                  ),
                  child: _selectedImage != null
                      ? CircleAvatar(
                          radius: 48,
                          backgroundImage: FileImage(_selectedImage!),
                        )
                      : CloudinaryAvatar(
                          imageUrl: _currentProfile?.avatarUrl,
                          userName: _currentProfile?.displayName ?? 'User',
                          radius: 48,
                        ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                      onPressed: _pickImage,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Touchez l\'icône pour changer',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informations personnelles',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _firstNameController,
                    decoration: const InputDecoration(
                      labelText: 'Prénom',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Le prénom est requis';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _lastNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Le nom est requis';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedGender,
              decoration: const InputDecoration(
                labelText: 'Genre',
                border: OutlineInputBorder(),
              ),
              items: _profileService.getAvailableGenders()
                  .map((gender) => DropdownMenuItem(
                        value: gender,
                        child: Text(_profileService.getGenderDisplayName(gender)),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedGender = value;
                });
              },
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _selectBirthDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date de naissance',
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  _selectedBirthDate != null
                      ? '${_selectedBirthDate!.day}/${_selectedBirthDate!.month}/${_selectedBirthDate!.year}'
                      : 'Sélectionner une date',
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bioController,
              decoration: const InputDecoration(
                labelText: 'Biographie',
                border: OutlineInputBorder(),
                hintText: 'Parlez-nous de vous...',
              ),
              maxLines: 3,
              maxLength: 500,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contact',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Téléphone',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value != null && value.trim().isNotEmpty && !_profileService.isValidPhone(value)) {
                  return 'Numéro de téléphone invalide';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _websiteController,
              decoration: const InputDecoration(
                labelText: 'Site web',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.web),
                hintText: 'https://www.exemple.com',
              ),
              keyboardType: TextInputType.url,
              validator: (value) {
                if (value != null && value.trim().isNotEmpty && !_profileService.isValidWebsite(value)) {
                  return 'URL invalide';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfessionalInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informations professionnelles',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _professionController,
              decoration: const InputDecoration(
                labelText: 'Profession',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.work),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _companyController,
              decoration: const InputDecoration(
                labelText: 'Entreprise',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Adresse',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressLine1Controller,
              decoration: const InputDecoration(
                labelText: 'Adresse ligne 1',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressLine2Controller,
              decoration: const InputDecoration(
                labelText: 'Adresse ligne 2 (optionnel)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(
                      labelText: 'Ville',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _postalCodeController,
                    decoration: const InputDecoration(
                      labelText: 'Code postal',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _stateProvinceController,
              decoration: const InputDecoration(
                labelText: 'État/Province (optionnel)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCountry,
              decoration: const InputDecoration(
                labelText: 'Pays',
                border: OutlineInputBorder(),
              ),
              items: _profileService.getAvailableCountries()
                  .map((country) => DropdownMenuItem(
                        value: country,
                        child: Text(country.isEmpty ? 'Non spécifié' : country),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCountry = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informations complémentaires',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nationalityController,
              decoration: const InputDecoration(
                labelText: 'Nationalité',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.flag),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyContactSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contact d\'urgence',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emergencyContactNameController,
              decoration: const InputDecoration(
                labelText: 'Nom du contact',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emergencyContactPhoneController,
              decoration: const InputDecoration(
                labelText: 'Téléphone du contact',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emergencyContactRelationController,
              decoration: const InputDecoration(
                labelText: 'Relation (ex: conjoint, parent, ami)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.family_restroom),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferencesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Préférences',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedLanguage,
              decoration: const InputDecoration(
                labelText: 'Langue préférée',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.language),
              ),
              items: const [
                DropdownMenuItem(value: 'fr', child: Text('Français')),
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'es', child: Text('Español')),
                DropdownMenuItem(value: 'de', child: Text('Deutsch')),
                DropdownMenuItem(value: 'it', child: Text('Italiano')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedLanguage = value;
                });
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedTimezone,
              decoration: const InputDecoration(
                labelText: 'Fuseau horaire',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.access_time),
              ),
              items: const [
                DropdownMenuItem(value: 'Europe/Paris', child: Text('Europe/Paris (CET)')),
                DropdownMenuItem(value: 'Europe/London', child: Text('Europe/London (GMT)')),
                DropdownMenuItem(value: 'America/New_York', child: Text('America/New_York (EST)')),
                DropdownMenuItem(value: 'America/Los_Angeles', child: Text('America/Los_Angeles (PST)')),
                DropdownMenuItem(value: 'Asia/Tokyo', child: Text('Asia/Tokyo (JST)')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedTimezone = value;
                });
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedProfileVisibility,
              decoration: const InputDecoration(
                labelText: 'Visibilité du profil',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.visibility),
              ),
              items: const [
                DropdownMenuItem(value: 'public', child: Text('Public')),
                DropdownMenuItem(value: 'private', child: Text('Privé')),
                DropdownMenuItem(value: 'friends_only', child: Text('Amis uniquement')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedProfileVisibility = value;
                });
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Recevoir la newsletter'),
              subtitle: const Text('Informations sur les nouvelles fonctionnalités'),
              value: _newsletterSubscribed,
              onChanged: (value) {
                setState(() {
                  _newsletterSubscribed = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Emails marketing'),
              subtitle: const Text('Promotions et offres spéciales'),
              value: _marketingEmails,
              onChanged: (value) {
                setState(() {
                  _marketingEmails = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}