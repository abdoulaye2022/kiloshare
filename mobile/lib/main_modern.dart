import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'config/theme.dart';
import 'modules/auth/blocs/bloc.dart';
import 'modules/auth/services/auth_service.dart';
import 'modules/auth/services/phone_auth_service.dart';
import 'package:dio/dio.dart';

void main() {
  runApp(const KiloShareModernApp());
}

class KiloShareModernApp extends StatelessWidget {
  const KiloShareModernApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (context) {
            final dio = Dio();
            return AuthBloc(
              authService: AuthService(),
              phoneAuthService: PhoneAuthService(dio),
            );
          },
        ),
      ],
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) {
          return MaterialApp(
            title: 'KiloShare - Modern Auth',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            home: const AuthNavigator(),
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(1.0),
                ),
                child: child!,
              );
            },
          );
        },
      ),
    );
  }
}

class AuthNavigator extends StatefulWidget {
  const AuthNavigator({super.key});

  @override
  State<AuthNavigator> createState() => _AuthNavigatorState();
}

class _AuthNavigatorState extends State<AuthNavigator> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: [
          // Page 0: Login
          ModernLoginWrapper(
            onRegister: () => _navigateToPage(1),
            onForgotPassword: () => _navigateToPage(2),
          ),
          
          // Page 1: Register
          ModernRegisterWrapper(
            onBack: () => _navigateToPage(0),
          ),
          
          // Page 2: Forgot Password
          ModernForgotPasswordWrapper(
            onBack: () => _navigateToPage(0),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        height: 60.h,
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildNavDot(0),
            SizedBox(width: 8.w),
            _buildNavDot(1),
            SizedBox(width: 8.w),
            _buildNavDot(2),
          ],
        ),
      ),
    );
  }

  Widget _buildNavDot(int index) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => _navigateToPage(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 8.h,
        width: isActive ? 24.w : 8.w,
        decoration: BoxDecoration(
          color: isActive 
            ? Theme.of(context).colorScheme.primary 
            : Theme.of(context).colorScheme.outline,
          borderRadius: BorderRadius.circular(4.r),
        ),
      ),
    );
  }

  void _navigateToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

// Wrapper pour la page de connexion avec navigation personnalisée
class ModernLoginWrapper extends StatelessWidget {
  final VoidCallback onRegister;
  final VoidCallback onForgotPassword;

  const ModernLoginWrapper({
    super.key,
    required this.onRegister,
    required this.onForgotPassword,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 40.h),
              
              // Header avec logo
              _buildHeader(context),
              
              SizedBox(height: 48.h),
              
              // Champs de connexion (simulation)
              _buildLoginForm(context),
              
              SizedBox(height: 24.h),
              
              // Bouton de connexion
              ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Design moderne appliqué! 🎨'),
                      backgroundColor: Theme.of(context).colorScheme.tertiary,
                    ),
                  );
                },
                child: const Text('Se connecter'),
              ),
              
              SizedBox(height: 16.h),
              
              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: onForgotPassword,
                    child: Text(
                      'Mot de passe oublié ?',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onRegister,
                    child: Text(
                      'S\'inscrire',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        // Logo avec design moderne
        Container(
          height: 100.h,
          width: 100.w,
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25.r),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withOpacity(0.1),
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

  Widget _buildLoginForm(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        // Email field (simulation)
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: TextField(
            decoration: InputDecoration(
              labelText: 'Email',
              hintText: 'Entrez votre email',
              prefixIcon: Icon(
                Icons.email_outlined,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: 16.h,
              ),
            ),
          ),
        ),
        
        SizedBox(height: 16.h),
        
        // Password field (simulation)
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: TextField(
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Mot de passe',
              hintText: 'Entrez votre mot de passe',
              prefixIcon: Icon(
                Icons.lock_outline,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              suffixIcon: Icon(
                Icons.visibility_off,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: 16.h,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Wrapper complet pour l'inscription avec le même design
class ModernRegisterWrapper extends StatefulWidget {
  final VoidCallback onBack;

  const ModernRegisterWrapper({
    super.key,
    required this.onBack,
  });

  @override
  State<ModernRegisterWrapper> createState() => _ModernRegisterWrapperState();
}

class _ModernRegisterWrapperState extends State<ModernRegisterWrapper> {
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
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                      SizedBox(
                        height: 52.h,
                        child: ElevatedButton(
                          onPressed: (_acceptTerms && !_isLoading) ? _handleRegister : null,
                          child: _isLoading
                              ? SizedBox(
                                  height: 20.h,
                                  width: 20.w,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text('Créer mon compte'),
                        ),
                      ),
                      
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
              onPressed: widget.onBack,
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
            color: theme.colorScheme.onSurface,
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
              child: _buildTextField(
                controller: _firstNameController,
                label: 'Prénom',
                hint: 'Jean',
                icon: Icons.person_outline,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Requis';
                  }
                  if (value.length < 2) {
                    return 'Min 2 car.';
                  }
                  return null;
                },
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildTextField(
                controller: _lastNameController,
                label: 'Nom',
                hint: 'Dupont',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Requis';
                  }
                  if (value.length < 2) {
                    return 'Min 2 car.';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        
        SizedBox(height: 16.h),
        
        // Email
        _buildTextField(
          controller: _emailController,
          label: 'Email',
          hint: 'jean.dupont@example.com',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'L\'email est requis';
            }
            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
              return 'Email invalide';
            }
            return null;
          },
        ),
        
        SizedBox(height: 16.h),
        
        // Téléphone
        _buildTextField(
          controller: _phoneController,
          label: 'Téléphone (optionnel)',
          hint: '+33 6 12 34 56 78',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        
        SizedBox(height: 16.h),
        
        // Mot de passe
        _buildTextField(
          controller: _passwordController,
          label: 'Mot de passe',
          hint: 'Créez un mot de passe sécurisé',
          icon: Icons.lock_outline,
          obscureText: _obscurePassword,
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
              return 'Mot de passe requis';
            }
            if (value.length < 6) {
              return 'Minimum 6 caractères';
            }
            return null;
          },
        ),
        
        SizedBox(height: 16.h),
        
        // Confirmation mot de passe
        _buildTextField(
          controller: _confirmPasswordController,
          label: 'Confirmer le mot de passe',
          hint: 'Répétez le mot de passe',
          icon: Icons.lock_outline,
          obscureText: _obscureConfirmPassword,
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
              return 'Confirmation requise';
            }
            if (value != _passwordController.text) {
              return 'Mots de passe différents';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? icon,
    Widget? suffixIcon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: icon != null ? Icon(icon, color: theme.colorScheme.onSurfaceVariant) : null,
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        ),
      ),
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
          child: Text.rich(
            TextSpan(
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
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
          onPressed: widget.onBack,
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

    setState(() {
      _isLoading = true;
    });

    // Simulation d'appel API
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Inscription réussie! 🎉'),
          backgroundColor: Theme.of(context).colorScheme.tertiary,
        ),
      );
      
      setState(() {
        _isLoading = false;
      });
    }
  }

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
}

// Wrapper complet pour mot de passe oublié avec le même design
class ModernForgotPasswordWrapper extends StatefulWidget {
  final VoidCallback onBack;

  const ModernForgotPasswordWrapper({
    super.key,
    required this.onBack,
  });

  @override
  State<ModernForgotPasswordWrapper> createState() => _ModernForgotPasswordWrapperState();
}

class _ModernForgotPasswordWrapperState extends State<ModernForgotPasswordWrapper> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _emailSent = false;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
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
              onPressed: widget.onBack,
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
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'L\'email est requis';
                    }
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                      return 'Veuillez entrer un email valide';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: 'Adresse email',
                    hintText: 'Entrez votre adresse email',
                    prefixIcon: Icon(
                      Icons.email_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 16.h,
                    ),
                  ),
                ),
              ),
              
              SizedBox(height: 32.h),
              
              // Send button
              SizedBox(
                height: 52.h,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSendResetLink,
                  child: _isLoading
                      ? SizedBox(
                          height: 20.h,
                          width: 20.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Envoyer le lien'),
                ),
              ),
              
              SizedBox(height: 24.h),
              
              // Back to login
              TextButton(
                onPressed: widget.onBack,
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
            color: theme.colorScheme.tertiary.withOpacity(0.1),
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
        
        Text.rich(
          TextSpan(
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
          textAlign: TextAlign.center,
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
              onPressed: widget.onBack,
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

    setState(() {
      _isLoading = true;
    });

    // Simulation d'appel API
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() {
        _isLoading = false;
        _emailSent = true;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
}