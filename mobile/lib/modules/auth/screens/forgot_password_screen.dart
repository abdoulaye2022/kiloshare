import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../blocs/bloc.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthPasswordResetSent) {
          setState(() {
            _emailSent = true;
          });
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
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              // App bar avec bouton retour
              _buildAppBar(theme),
              
              // Contenu
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 24.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: 40.h),
                      
                      if (!_emailSent) ...[
                        // Page de saisie email
                        _buildForgotPasswordForm(theme),
                      ] else ...[
                        // Page de confirmation
                        _buildConfirmationView(theme),
                      ],
                    ],
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
              onPressed: () => context.pop(),
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

  Widget _buildForgotPasswordForm(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Illustration
        Container(
          height: 120.h,
          width: 120.w,
          margin: EdgeInsets.only(bottom: 32.h),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.lock_reset_outlined,
            size: 60.sp,
            color: theme.colorScheme.primary,
          ),
        ),
        
        // Header
        Text(
          'Mot de passe oublié ?',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        
        SizedBox(height: 12.h),
        
        Text(
          'Ne vous inquiétez pas, nous allons vous envoyer un lien de réinitialisation sur votre adresse email.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        
        SizedBox(height: 40.h),
        
        // Form
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthTextField(
                controller: _emailController,
                label: 'Adresse email',
                hint: 'Entrez votre adresse email',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.email_outlined,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'L\'email est requis';
                  }
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                    return 'Veuillez entrer un email valide';
                  }
                  return null;
                },
              ),
              
              SizedBox(height: 32.h),
              
              // Send button
              BlocBuilder<AuthBloc, AuthState>(
                builder: (context, state) {
                  final isLoading = state is AuthLoading;
                  return AuthButton(
                    text: 'Envoyer le lien',
                    onPressed: isLoading ? null : _handleSendResetLink,
                    isLoading: isLoading,
                  );
                },
              ),
              
              SizedBox(height: 24.h),
              
              // Back to login
              TextButton(
                onPressed: () => context.pop(),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.arrow_back,
                      size: 16.sp,
                      color: theme.colorScheme.primary,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'Retour à la connexion',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmationView(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Success illustration
        Container(
          height: 120.h,
          width: 120.w,
          margin: EdgeInsets.only(bottom: 32.h),
          decoration: BoxDecoration(
            color: theme.colorScheme.tertiary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.mark_email_read_outlined,
            size: 60.sp,
            color: theme.colorScheme.tertiary,
          ),
        ),
        
        // Success message
        Text(
          'Email envoyé !',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        
        SizedBox(height: 12.h),
        
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
            children: [
              const TextSpan(
                text: 'Nous avons envoyé un lien de réinitialisation à\n',
              ),
              TextSpan(
                text: _emailController.text,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        
        SizedBox(height: 32.h),
        
        // Instructions
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Column(
            children: [
              Icon(
                Icons.info_outline,
                color: theme.colorScheme.onSurfaceVariant,
                size: 24.sp,
              ),
              SizedBox(height: 12.h),
              Text(
                'Vérifiez votre boîte de réception (et vos spams) puis cliquez sur le lien pour réinitialiser votre mot de passe.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        
        SizedBox(height: 32.h),
        
        // Actions
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _emailSent = false;
                });
              },
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16.h),
                side: BorderSide(color: theme.colorScheme.primary),
              ),
              child: Text(
                'Renvoyer l\'email',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            
            SizedBox(height: 16.h),
            
            TextButton(
              onPressed: () => context.pop(),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16.h),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.arrow_back,
                    size: 16.sp,
                    color: theme.colorScheme.onSurface,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'Retour à la connexion',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _handleSendResetLink() async {
    if (!_formKey.currentState!.validate()) return;

    context.read<AuthBloc>().add(
      AuthForgotPasswordRequested(
        email: _emailController.text.trim(),
      ),
    );
  }
}