import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../blocs/bloc.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_button.dart';
import '../widgets/auth_divider.dart';
import '../widgets/social_login_buttons.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          // Navigate to home after successful registration
          context.go('/home');
        } else if (state is AuthEmailVerificationRequired) {
          // Navigate to email verification screen
          context.go('/email-verification');
        } else if (state is AuthError) {
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: theme.colorScheme.error,
            ),
          );
          // Clear error after showing
          context.read<AuthBloc>().add(AuthErrorCleared());
        }
      },
      child: _buildRegisterContent(context, theme),
    );
  }

  Widget _buildRegisterContent(BuildContext context, ThemeData theme) {

    return Scaffold(
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
                      
                      // Registration form
                      _buildRegistrationForm(theme),
                      
                      SizedBox(height: 24.h),
                      
                      // Terms and conditions
                      _buildTermsCheckbox(theme),
                      
                      SizedBox(height: 32.h),
                      
                      // Register button
                      BlocBuilder<AuthBloc, AuthState>(
                        builder: (context, state) {
                          final isLoading = state is AuthLoading;
                          return AuthButton(
                            text: 'Créer mon compte',
                            onPressed: (_acceptTerms && !isLoading) ? _handleRegister : null,
                            isLoading: isLoading,
                          );
                        },
                      ),
                      
                      SizedBox(height: 32.h),
                      
                      // Social registration divider
                      const AuthDivider(text: 'Ou inscrivez-vous avec'),
                      
                      SizedBox(height: 24.h),
                      
                      // Social login buttons
                      const SocialLoginButtons(),
                      
                      SizedBox(height: 32.h),
                      
                      // Login link
                      _buildLoginLink(theme),
                      
                      SizedBox(height: 20.h),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(ThemeData theme) {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Row(
        children: [
          Container(
            height: 40.h,
            width: 40.w,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.shadow.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              onPressed: () => context.go('/login'),
              icon: Icon(
                Icons.arrow_back_ios_new,
                color: theme.colorScheme.onSurface,
                size: 18.sp,
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
          'Créer un compte',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onBackground,
            letterSpacing: -0.5,
          ),
        ),
        
        SizedBox(height: 8.h),
        
        Text(
          'Rejoignez la communauté KiloShare et commencez à partager vos espaces bagages',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildRegistrationForm(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Nom et prénom sur la même ligne
        Row(
          children: [
            Expanded(
              child: AuthTextField(
                controller: _firstNameController,
                label: 'Prénom',
                hint: 'Jean',
                prefixIcon: Icons.person_outline,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Le prénom est requis';
                  }
                  if (value.length < 2) {
                    return 'Minimum 2 caractères';
                  }
                  return null;
                },
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: AuthTextField(
                controller: _lastNameController,
                label: 'Nom',
                hint: 'Dupont',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Le nom est requis';
                  }
                  if (value.length < 2) {
                    return 'Minimum 2 caractères';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        
        SizedBox(height: 16.h),
        
        // Email
        AuthTextField(
          controller: _emailController,
          label: 'Email',
          hint: 'jean.dupont@example.com',
          keyboardType: TextInputType.emailAddress,
          prefixIcon: Icons.email_outlined,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'L\'email est requis';
            }
            
            // Validation d'email plus stricte
            final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
            if (!emailRegex.hasMatch(value.trim())) {
              return 'Veuillez entrer un email valide (ex: nom@exemple.com)';
            }
            
            return null;
          },
        ),
        
        SizedBox(height: 16.h),
        
        // Téléphone (optionnel)
        AuthTextField(
          controller: _phoneController,
          label: 'Téléphone (optionnel)',
          hint: '+33 6 12 34 56 78',
          keyboardType: TextInputType.phone,
          prefixIcon: Icons.phone_outlined,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s\(\)]')),
          ],
        ),
        
        SizedBox(height: 16.h),
        
        // Mot de passe
        AuthTextField(
          controller: _passwordController,
          label: 'Mot de passe',
          hint: 'Créez un mot de passe sécurisé',
          obscureText: _obscurePassword,
          prefixIcon: Icons.lock_outline,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
            onPressed: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Le mot de passe est requis';
            }
            if (value.length < 6) {
              return 'Minimum 6 caractères';
            }
            return null;
          },
        ),
        
        SizedBox(height: 16.h),
        
        // Confirmation mot de passe
        AuthTextField(
          controller: _confirmPasswordController,
          label: 'Confirmer le mot de passe',
          hint: 'Répétez le mot de passe',
          obscureText: _obscureConfirmPassword,
          prefixIcon: Icons.lock_outline,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
            onPressed: () {
              setState(() {
                _obscureConfirmPassword = !_obscureConfirmPassword;
              });
            },
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'La confirmation est requise';
            }
            if (value != _passwordController.text) {
              return 'Les mots de passe ne correspondent pas';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildTermsCheckbox(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 24.h,
          width: 24.w,
          child: Checkbox(
            value: _acceptTerms,
            onChanged: (value) {
              setState(() {
                _acceptTerms = value ?? false;
              });
            },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4.r),
            ),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.4,
              ),
              children: [
                TextSpan(
                  text: 'J\'accepte les ',
                  style: TextStyle(color: theme.colorScheme.onSurface),
                ),
                TextSpan(
                  text: 'Conditions d\'utilisation',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
                TextSpan(
                  text: ' et la ',
                  style: TextStyle(color: theme.colorScheme.onSurface),
                ),
                TextSpan(
                  text: 'Politique de confidentialité',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginLink(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Déjà un compte ? ',
          style: theme.textTheme.bodyMedium,
        ),
        TextButton(
          onPressed: () => context.pop(),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
          ),
          child: Text(
            'Se connecter',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptTerms) return;

    context.read<AuthBloc>().add(
      AuthRegisterRequested(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      ),
    );
  }
}