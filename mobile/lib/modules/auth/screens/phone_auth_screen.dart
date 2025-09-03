import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_event.dart';
import '../blocs/auth/auth_state.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_button.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isCodeSent = false;
  final bool _showNameFields = false;
  String _formattedPhone = '';

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is PhoneCodeSent) {
          setState(() {
            _isCodeSent = true;
            _formattedPhone = state.phoneNumber;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Code de vérification envoyé'),
              backgroundColor: theme.colorScheme.primary,
            ),
          );
        } else if (state is AuthAuthenticated) {
          context.go('/home');
        } else if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: theme.colorScheme.error,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              // App bar avec bouton retour
              _buildAppBar(theme),
              
              // Contenu scrollable
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 24.h),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: 16.h),
                        
                        // Header
                        _buildHeader(theme),
                        
                        SizedBox(height: 40.h),
                        
                        // Phone auth form
                        _buildPhoneAuthForm(theme),
                        
                        SizedBox(height: 32.h),
                        
                        // Action button
                        _buildActionButton(),
                        
                        if (_isCodeSent) ...[
                          SizedBox(height: 16.h),
                          _buildResendButton(theme),
                        ],
                        
                        SizedBox(height: 24.h),
                        
                        // Navigation links
                        _buildNavigationLinks(theme),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(ThemeData theme) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              // Détecter d'où on vient basé sur l'état de navigation
              final currentLocation = GoRouterState.of(context).uri.toString();
              if (currentLocation.contains('from=register')) {
                context.go('/register');
              } else {
                context.go('/login');
              }
            },
            icon: Icon(
              Icons.arrow_back_ios,
              color: theme.colorScheme.onSurface,
            ),
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isCodeSent ? 'Vérification' : 'Connexion par téléphone',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          _isCodeSent 
              ? 'Entrez le code de vérification envoyé au $_formattedPhone'
              : 'Entrez votre numéro de téléphone pour recevoir un code de vérification',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneAuthForm(ThemeData theme) {
    return Column(
      children: [
        if (!_isCodeSent) ...[
          // Champ numéro de téléphone
          AuthTextField(
            controller: _phoneController,
            label: 'Numéro de téléphone',
            hint: '123 456 7890',
            keyboardType: TextInputType.phone,
            prefixIcon: Icons.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              PhoneNumberFormatter(),
            ],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Veuillez entrer votre numéro de téléphone';
              }
              return null;
            },
          ),
        ] else ...[
          // Champ code de vérification
          AuthTextField(
            controller: _codeController,
            label: 'Code de vérification',
            hint: 'Entrez le code à 6 chiffres',
            keyboardType: TextInputType.number,
            prefixIcon: Icons.verified_user,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Veuillez entrer le code de vérification';
              }
              if (value.length != 6) {
                return 'Le code doit contenir 6 chiffres';
              }
              return null;
            },
          ),
          
          SizedBox(height: 16.h),
          
          // Champs nom et prénom (si nouveaux utilisateurs)
          if (_showNameFields) ...[
            Row(
              children: [
                Expanded(
                  child: AuthTextField(
                    controller: _firstNameController,
                    label: 'Prénom',
                    hint: 'Votre prénom',
                    prefixIcon: Icons.person,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Prénom requis';
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: AuthTextField(
                    controller: _lastNameController,
                    label: 'Nom',
                    hint: 'Votre nom',
                    prefixIcon: Icons.person_outline,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Nom requis';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
          ],
        ],
      ],
    );
  }

  Widget _buildActionButton() {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        return AuthButton(
          text: _isCodeSent ? 'Vérifier le code' : 'Envoyer le code',
          onPressed: isLoading ? null : (_isCodeSent ? _verifyCode : _sendCode),
          isLoading: isLoading,
          icon: _isCodeSent ? Icons.check : Icons.sms,
        );
      },
    );
  }

  Widget _buildResendButton(ThemeData theme) {
    return Center(
      child: TextButton(
        onPressed: _resendCode,
        child: Text(
          'Renvoyer le code',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationLinks(ThemeData theme) {
    return Column(
      children: [
        // Divider
        Row(
          children: [
            Expanded(
              child: Divider(
                color: theme.colorScheme.outline.withOpacity(0.3),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Text(
                'ou',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: theme.colorScheme.outline.withOpacity(0.3),
              ),
            ),
          ],
        ),
        
        SizedBox(height: 24.h),
        
        // Navigation buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(
              onPressed: () => context.go('/login'),
              child: Text(
                'Se connecter par email',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Container(
              height: 20.h,
              width: 1,
              color: theme.colorScheme.outline.withOpacity(0.3),
            ),
            TextButton(
              onPressed: () => context.go('/register'),
              child: Text(
                'Créer un compte',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _sendCode() {
    if (_formKey.currentState!.validate()) {
      final phoneNumber = _phoneController.text;
      context.read<AuthBloc>().add(SendPhoneVerificationCode(phoneNumber));
    }
  }

  void _verifyCode() {
    if (_formKey.currentState!.validate()) {
      final code = _codeController.text;
      final firstName = _firstNameController.text.isNotEmpty 
          ? _firstNameController.text 
          : null;
      final lastName = _lastNameController.text.isNotEmpty 
          ? _lastNameController.text 
          : null;
      
      context.read<AuthBloc>().add(VerifyPhoneCode(
        _formattedPhone.isNotEmpty ? _formattedPhone : _phoneController.text,
        code,
        firstName: firstName,
        lastName: lastName,
      ));
    }
  }

  void _resendCode() {
    final phoneNumber = _formattedPhone.isNotEmpty ? _formattedPhone : _phoneController.text;
    context.read<AuthBloc>().add(SendPhoneVerificationCode(phoneNumber));
  }
}

// Formatter pour le numéro de téléphone format 111 111 1111
class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final newText = newValue.text;
    if (newText.length <= 10) {
      String formatted = '';
      for (int i = 0; i < newText.length; i++) {
        if (i == 3 || i == 6) {
          formatted += ' ';
        }
        formatted += newText[i];
      }
      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
    return oldValue;
  }
}