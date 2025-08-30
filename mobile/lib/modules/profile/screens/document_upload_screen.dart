import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../bloc/profile_bloc.dart';
import '../bloc/profile_event.dart';
import '../bloc/profile_state.dart';
import '../services/profile_service.dart';

enum FileSource { camera, gallery, files }

class DocumentUploadScreen extends StatefulWidget {
  const DocumentUploadScreen({super.key});

  @override
  State<DocumentUploadScreen> createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends State<DocumentUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _profileService = ProfileService();
  final _documentNumberController = TextEditingController();
  
  String? _selectedDocumentType;
  File? _selectedFile;
  DateTime? _selectedExpiryDate;
  bool _isLoading = false;
  
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void dispose() {
    _documentNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Télécharger un document'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          TextButton(
            onPressed: _isLoading || _selectedFile == null ? null : _uploadDocument,
            child: _isLoading 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Télécharger'),
          ),
        ],
      ),
      body: BlocListener<ProfileBloc, ProfileState>(
        listener: (context, state) {
          if (state is DocumentUploaded) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Document téléchargé avec succès'),
                backgroundColor: Colors.green,
              ),
            );
            context.pop();
          } else if (state is ProfileActionError && state.action == 'upload_document') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
          
          setState(() {
            _isLoading = state is ProfileActionLoading && state.action == 'upload_document';
          });
        },
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInstructionsCard(),
                const SizedBox(height: 24),
                _buildDocumentTypeSection(),
                const SizedBox(height: 24),
                _buildFileSelectionSection(),
                const SizedBox(height: 24),
                _buildDocumentDetailsSection(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  'Instructions importantes',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '• Assurez-vous que le document est lisible et de bonne qualité\n'
              '• Les formats acceptés sont : JPG, JPEG, PNG, PDF\n'
              '• Taille maximale : 10 MB par fichier\n'
              '• Les documents seront vérifiés dans un délai de 24 à 48 heures\n'
              '• Vos données sont sécurisées et conformes au RGPD',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentTypeSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Type de document *',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            DropdownButtonFormField<String>(
              value: _selectedDocumentType,
              decoration: const InputDecoration(
                hintText: 'Sélectionnez le type de document',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              items: _profileService.getAvailableDocumentTypes().map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Row(
                    children: [
                      Icon(_getDocumentTypeIcon(type), size: 20),
                      const SizedBox(width: 8),
                      Text(_profileService.getDocumentTypeDisplayName(type)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedDocumentType = value;
                  _selectedExpiryDate = null; // Reset expiry date when type changes
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez sélectionner un type de document';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 12),
            
            if (_selectedDocumentType != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb, color: Colors.orange[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getDocumentTypeHint(_selectedDocumentType!),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileSelectionSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fichier *',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            if (_selectedFile == null) ...[
              Container(
                width: double.infinity,
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!, width: 2, style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_upload, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'Aucun fichier sélectionné',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Appuyez sur un bouton ci-dessous pour choisir',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _selectFile(FileSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Prendre une photo'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _selectFile(FileSource.gallery),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Galerie'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _selectFile(FileSource.files),
                  icon: const Icon(Icons.folder),
                  label: const Text('Choisir un fichier'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  border: Border.all(color: Colors.green[200]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Fichier sélectionné',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Nom: ${_getFileName(_selectedFile!)}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      'Taille: ${_getFileSize(_selectedFile!)}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _previewFile(_selectedFile!),
                      icon: const Icon(Icons.visibility),
                      label: const Text('Aperçu'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedFile = null;
                        });
                      },
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text('Supprimer'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentDetailsSection() {
    if (_selectedDocumentType == null) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Détails du document',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            if (_needsDocumentNumber(_selectedDocumentType!)) ...[
              TextFormField(
                controller: _documentNumberController,
                decoration: InputDecoration(
                  labelText: _getDocumentNumberLabel(_selectedDocumentType!),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.numbers),
                  hintText: _getDocumentNumberHint(_selectedDocumentType!),
                ),
                validator: (value) {
                  if (_needsDocumentNumber(_selectedDocumentType!) && 
                      (value == null || value.trim().isEmpty)) {
                    return 'Ce champ est requis pour ce type de document';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
            ],
            
            if (_needsExpiryDate(_selectedDocumentType!)) ...[
              InkWell(
                onTap: _selectExpiryDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Date d\'expiration',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.calendar_today),
                    suffixIcon: _selectedExpiryDate != null
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _selectedExpiryDate = null;
                              });
                            },
                          )
                        : null,
                  ),
                  child: Text(
                    _selectedExpiryDate != null
                        ? _formatDate(_selectedExpiryDate!)
                        : 'Sélectionner une date (optionnel)',
                    style: TextStyle(
                      color: _selectedExpiryDate != null ? Colors.black87 : Colors.grey,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }


  Future<void> _selectFile(FileSource source) async {
    try {
      File? file;
      
      switch (source) {
        case FileSource.camera:
          final XFile? pickedFile = await _imagePicker.pickImage(
            source: ImageSource.camera,
            maxWidth: 1920,
            maxHeight: 1920,
            imageQuality: 85,
          );
          if (pickedFile != null) {
            file = File(pickedFile.path);
          }
          break;
          
        case FileSource.gallery:
          final XFile? pickedFile = await _imagePicker.pickImage(
            source: ImageSource.gallery,
            maxWidth: 1920,
            maxHeight: 1920,
            imageQuality: 85,
          );
          if (pickedFile != null) {
            file = File(pickedFile.path);
          }
          break;
          
        case FileSource.files:
          final FilePickerResult? result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
            allowMultiple: false,
          );
          if (result != null && result.files.isNotEmpty) {
            file = File(result.files.first.path!);
          }
          break;
      }

      if (file != null) {
        final fileSize = await file.length();
        if (fileSize > 10 * 1024 * 1024) { // 10 MB
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Le fichier est trop volumineux (maximum 10 MB)'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        setState(() {
          _selectedFile = file;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sélection du fichier: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _previewFile(File file) async {
    if (file.path.toLowerCase().endsWith('.pdf')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aperçu PDF non disponible'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Aperçu'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Flexible(
              child: Image.file(
                file,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectExpiryDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedExpiryDate ?? DateTime.now().add(const Duration(days: 365 * 5)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 50)),
    );

    if (picked != null && picked != _selectedExpiryDate) {
      setState(() {
        _selectedExpiryDate = picked;
      });
    }
  }

  Future<void> _uploadDocument() async {
    if (!_formKey.currentState!.validate() || _selectedFile == null) {
      return;
    }

    if (mounted) {
      context.read<ProfileBloc>().add(
        UploadDocument(
          documentFile: _selectedFile!,
          documentType: _selectedDocumentType!,
          documentNumber: _documentNumberController.text.trim().isNotEmpty 
              ? _documentNumberController.text.trim() 
              : null,
          expiryDate: _selectedExpiryDate,
        ),
      );
    }
  }

  // Helper methods
  IconData _getDocumentTypeIcon(String type) {
    switch (type) {
      case 'identity_card':
        return Icons.credit_card;
      case 'passport':
        return Icons.book;
      case 'driver_license':
        return Icons.drive_eta;
      case 'proof_of_address':
        return Icons.home;
      case 'bank_statement':
        return Icons.account_balance;
      case 'utility_bill':
        return Icons.receipt;
      case 'selfie_with_id':
        return Icons.camera_alt;
      default:
        return Icons.description;
    }
  }

  String _getDocumentTypeHint(String type) {
    switch (type) {
      case 'identity_card':
        return 'Carte nationale d\'identité française ou européenne';
      case 'passport':
        return 'Passeport en cours de validité';
      case 'driver_license':
        return 'Permis de conduire français ou européen';
      case 'proof_of_address':
        return 'Facture, quittance de loyer, etc. (moins de 3 mois)';
      case 'bank_statement':
        return 'Relevé bancaire récent (moins de 3 mois)';
      case 'utility_bill':
        return 'Facture d\'électricité, gaz, eau ou téléphone';
      case 'selfie_with_id':
        return 'Photo de vous tenant votre pièce d\'identité';
      default:
        return '';
    }
  }

  bool _needsDocumentNumber(String type) {
    return ['identity_card', 'passport', 'driver_license'].contains(type);
  }

  bool _needsExpiryDate(String type) {
    return ['identity_card', 'passport', 'driver_license'].contains(type);
  }

  String _getDocumentNumberLabel(String type) {
    switch (type) {
      case 'identity_card':
        return 'Numéro de carte d\'identité';
      case 'passport':
        return 'Numéro de passeport';
      case 'driver_license':
        return 'Numéro de permis';
      default:
        return 'Numéro du document';
    }
  }

  String _getDocumentNumberHint(String type) {
    switch (type) {
      case 'identity_card':
        return 'Ex: 123456789012';
      case 'passport':
        return 'Ex: 12AB34567';
      case 'driver_license':
        return 'Ex: 123456789012';
      default:
        return '';
    }
  }

  String _getFileName(File file) {
    return file.path.split('/').last;
  }

  String _getFileSize(File file) {
    final bytes = file.lengthSync();
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
           '${date.month.toString().padLeft(2, '0')}/'
           '${date.year}';
  }
}