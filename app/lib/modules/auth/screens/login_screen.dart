import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../blocs/bloc.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_button.dart';
import '../widgets/auth_divider.dart';
import '../widgets/social_login_buttons.dart';
import '../../../widgets/ellipsis_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          // Navigate to home after successful login
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
      child: _buildLoginContent(context, theme),
    );
  }

  Widget _buildLoginContent(BuildContext context, ThemeData theme) {

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.w),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 40.h),
                
                // Logo and welcome text
                _buildHeader(theme),
                
                SizedBox(height: 48.h),
                
                // Login form
                _buildLoginForm(theme),
                
                SizedBox(height: 24.h),
                
                // Login button
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    final isLoading = state is AuthLoading;
                    return AuthButton(
                      text: 'Se connecter',
                      onPressed: isLoading ? null : _handleLogin,
                      isLoading: isLoading,
                    );
                  },
                ),
                
                SizedBox(height: 16.h),
                
                // Remember me and forgot password
                _buildFooterActions(theme),
                
                SizedBox(height: 32.h),
                
                // Social login divider
                const AuthDivider(text: 'Ou connectez-vous avec'),
                
                SizedBox(height: 24.h),
                
                // Social login buttons
                const SocialLoginButtons(),
                
                SizedBox(height: 16.h),
                
                // Phone authentication button
                EllipsisButton.outlined(
                  onPressed: () => context.push('/phone-auth'),
                  icon: const Icon(Icons.phone),
                  text: 'Se connecter avec le téléphone',
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: 24.w,
                      vertical: 16.h,
                    ),
                  ),
                ),
                
                SizedBox(height: 32.h),
                
                // Sign up link
                _buildSignUpLink(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      children: [
        // Logo avec animation subtile
        Container(
          height: 100.h,
          width: 100.w,
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25.r),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Image.asset(
            'assets/icons/logo.png',
            fit: BoxFit.contain,
          ),
        ),
        
        SizedBox(height: 32.h),
        
        Text(
          'Bon retour !',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        
        SizedBox(height: 12.h),
        
        Text(
          'Connectez-vous à votre compte\npour partager votre espace bagage',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLoginForm(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthTextField(
          controller: _emailController,
          label: 'Email',
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
        
        SizedBox(height: 16.h),
        
        AuthTextField(
          controller: _passwordController,
          label: 'Mot de passe',
          hint: 'Entrez votre mot de passe',
          obscureText: _obscurePassword,
          prefixIcon: Icons.lock_outline,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildFooterActions(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            SizedBox(
              height: 20.h,
              width: 20.w,
              child: Checkbox(
                value: _rememberMe,
                onChanged: (value) {
                  setState(() {
                    _rememberMe = value ?? false;
                  });
                },
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            SizedBox(width: 8.w),
            Text(
              'Se souvenir de moi',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        EllipsisButton.text(
          onPressed: () => context.push('/forgot-password'),
          text: 'Mot de passe oublié ?',
        ),
      ],
    );
  }

  Widget _buildSignUpLink(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Pas encore de compte ? ',
          style: theme.textTheme.bodyMedium,
        ),
        TextButton(
          onPressed: () => context.push('/register'),
          child: Text(
            'S\'inscrire',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    context.read<AuthBloc>().add(
      AuthLoginRequested(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      ),
    );
  }
}