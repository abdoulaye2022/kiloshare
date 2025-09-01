import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';

import '../../auth/blocs/auth/auth_bloc.dart';
import '../../auth/blocs/auth/auth_state.dart';
import '../../auth/blocs/auth/auth_event.dart';
import '../../auth/models/user_model.dart';
import '../models/user_profile.dart';
import '../services/profile_service.dart';
import '../../../themes/modern_theme.dart';

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
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();
  
  // State
  File? _selectedImage;
  String? _selectedGender;
  String? _selectedCountry;
  DateTime? _selectedBirthDate;
  UserProfile? _currentProfile;
  bool _isLoading = false;
  bool _isLoadingProfile = true;

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
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
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
          _addressController.text = profile.address ?? '';
          _cityController.text = profile.city ?? '';
          _postalCodeController.text = profile.postalCode ?? '';
          _selectedGender = profile.gender;
          _selectedCountry = profile.country;
          _selectedBirthDate = profile.dateOfBirth;
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
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'postal_code': _postalCodeController.text.trim(),
        'gender': _selectedGender,
        'country': _selectedCountry,
        'date_of_birth': _selectedBirthDate?.toIso8601String().split('T')[0],
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
                  child: CircleAvatar(
                    radius: 48,
                    backgroundImage: _selectedImage != null
                        ? FileImage(_selectedImage!)
                        : (_currentProfile?.avatarUrl != null
                            ? NetworkImage(_currentProfile!.avatarUrl!)
                            : null) as ImageProvider?,
                    child: _selectedImage == null && _currentProfile?.avatarUrl == null
                        ? Icon(Icons.person, size: 40, color: Colors.grey.shade600)
                        : null,
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
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Adresse complète',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
              maxLines: 2,
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
            DropdownButtonFormField<String>(
              value: _selectedCountry,
              decoration: const InputDecoration(
                labelText: 'Pays',
                border: OutlineInputBorder(),
              ),
              items: _profileService.getAvailableCountries()
                  .map((country) => DropdownMenuItem(
                        value: country,
                        child: Text(country),
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
}