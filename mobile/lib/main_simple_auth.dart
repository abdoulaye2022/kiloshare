import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'config/theme.dart';
import 'modules/auth/blocs/bloc.dart';
import 'modules/auth/services/auth_service.dart';
import 'modules/auth/services/phone_auth_service.dart';
import 'package:dio/dio.dart';

void main() {
  runApp(const KiloShareSimpleAuth());
}

class KiloShareSimpleAuth extends StatelessWidget {
  const KiloShareSimpleAuth({super.key});

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
        builder: (context, child) {
          return MaterialApp(
            title: 'KiloShare - Auth Simplifiée',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            home: const SimpleAuthScreen(),
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

class SimpleAuthScreen extends StatefulWidget {
  const SimpleAuthScreen({super.key});

  @override
  State<SimpleAuthScreen> createState() => _SimpleAuthScreenState();
}

class _SimpleAuthScreenState extends State<SimpleAuthScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: PageView(
        controller: _pageController,
        onPageChanged: (page) => setState(() => _currentPage = page),
        children: [
          SimpleLoginPage(onRegister: () => _goToPage(1)),
          SimpleRegisterPage(onBack: () => _goToPage(0)),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 16.h),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildPageDot(0, 'Connexion'),
            SizedBox(width: 8.w),
            _buildPageDot(1, 'Inscription'),
          ],
        ),
      ),
    );
  }

  Widget _buildPageDot(int page, String label) {
    final theme = Theme.of(context);
    final isActive = _currentPage == page;
    
    return GestureDetector(
      onTap: () => _goToPage(page),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: isActive ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isActive ? theme.colorScheme.primary : theme.colorScheme.outline,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isActive ? Colors.white : theme.colorScheme.onSurface,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  void _goToPage(int page) {
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

// Page de connexion simplifiée
class SimpleLoginPage extends StatefulWidget {
  final VoidCallback onRegister;

  const SimpleLoginPage({super.key, required this.onRegister});

  @override
  State<SimpleLoginPage> createState() => _SimpleLoginPageState();
}

class _SimpleLoginPageState extends State<SimpleLoginPage> {
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          children: [
            SizedBox(height: 60.h),
            
            // Logo et titre
            _buildHeader(theme),
            
            SizedBox(height: 60.h),
            
            // Options de connexion
            _buildLoginOptions(theme),
            
            const Spacer(),
            
            // Lien d'inscription
            _buildRegisterLink(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      children: [
        // Logo
        Container(
          height: 80.h,
          width: 80.w,
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.r),
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
        
        SizedBox(height: 24.h),
        
        Text(
          'Bienvenue sur\nKiloShare',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
            letterSpacing: -0.5,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
        
        SizedBox(height: 12.h),
        
        Text(
          'Partagez vos trajets et vos espaces bagages',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLoginOptions(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Connexion avec téléphone (priorité)
        _buildPhoneLogin(theme),
        
        SizedBox(height: 16.h),
        
        // Divider
        Row(
          children: [
            Expanded(child: Divider(color: theme.colorScheme.outline)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Text(
                'ou',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(child: Divider(color: theme.colorScheme.outline)),
          ],
        ),
        
        SizedBox(height: 16.h),
        
        // Social logins
        _buildSocialLogin(
          'Continuer avec Google',
          Icons.g_mobiledata,
          Colors.red,
          () => _handleGoogleLogin(),
        ),
        
        SizedBox(height: 12.h),
        
        _buildSocialLogin(
          'Continuer avec Facebook',
          Icons.facebook,
          const Color(0xFF1877F2),
          () => _handleFacebookLogin(),
        ),
        
        SizedBox(height: 12.h),
        
        _buildSocialLogin(
          'Continuer avec Apple',
          Icons.apple,
          Colors.black,
          () => _handleAppleLogin(),
        ),
      ],
    );
  }

  Widget _buildPhoneLogin(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: theme.colorScheme.primary, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 12.h),
            child: Row(
              children: [
                Icon(
                  Icons.phone_outlined,
                  color: theme.colorScheme.primary,
                  size: 20.sp,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'Connexion par téléphone',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiary,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    'Rapide',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: '+33 6 12 34 56 78',
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: theme.colorScheme.outline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              ),
            ),
          ),
          
          SizedBox(height: 16.h),
          
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
            child: ElevatedButton(
              onPressed: _isLoading ? null : () => _handlePhoneLogin(),
              child: _isLoading
                  ? SizedBox(
                      height: 20.h,
                      width: 20.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Recevoir le code SMS'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialLogin(String text, IconData icon, Color iconColor, VoidCallback onTap) {
    final theme = Theme.of(context);
    
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.symmetric(vertical: 14.h),
        side: BorderSide(color: theme.colorScheme.outline),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 20.sp),
          SizedBox(width: 12.w),
          Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterLink(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Nouveau sur KiloShare ? ',
          style: theme.textTheme.bodyMedium,
        ),
        GestureDetector(
          onTap: widget.onRegister,
          child: Text(
            'Créer un compte',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handlePhoneLogin() async {
    if (_phoneController.text.trim().isEmpty) {
      _showMessage('Veuillez entrer votre numéro de téléphone');
      return;
    }

    setState(() => _isLoading = true);
    
    // Simulation API call
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      setState(() => _isLoading = false);
      _showMessage('Code SMS envoyé ! 📱');
      // TODO: Naviguer vers la page de vérification SMS
    }
  }

  Future<void> _handleGoogleLogin() async {
    _showMessage('Connexion Google en développement 🚧');
    // TODO: Implémenter Google Sign In
  }

  Future<void> _handleFacebookLogin() async {
    _showMessage('Connexion Facebook en développement 🚧');
    // TODO: Implémenter Facebook Login
  }

  Future<void> _handleAppleLogin() async {
    _showMessage('Connexion Apple en développement 🚧');
    // TODO: Implémenter Apple Sign In
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }
}

// Page d'inscription simplifiée (téléphone d'abord)
class SimpleRegisterPage extends StatefulWidget {
  final VoidCallback onBack;

  const SimpleRegisterPage({super.key, required this.onBack});

  @override
  State<SimpleRegisterPage> createState() => _SimpleRegisterPageState();
}

class _SimpleRegisterPageState extends State<SimpleRegisterPage> {
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  bool _acceptTerms = false;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 20.h),
            
            // Header
            _buildHeader(theme),
            
            SizedBox(height: 40.h),
            
            // Form simple
            _buildSimpleForm(theme),
            
            SizedBox(height: 24.h),
            
            // Terms
            _buildTerms(theme),
            
            SizedBox(height: 32.h),
            
            // Register button
            ElevatedButton(
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
            
            const Spacer(),
            
            // Login link
            _buildLoginLink(theme),
          ],
        ),
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
            letterSpacing: -0.5,
          ),
        ),
        
        SizedBox(height: 8.h),
        
        Text(
          'Rejoignez des milliers de voyageurs',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleForm(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Nom complet
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'Nom complet',
            hintText: 'Jean Dupont',
            prefixIcon: Icon(Icons.person_outline),
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        
        SizedBox(height: 16.h),
        
        // Téléphone (priorité)
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
          ),
          child: TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Téléphone',
              hintText: '+33 6 12 34 56 78',
              prefixIcon: Icon(
                Icons.phone_outlined,
                color: theme.colorScheme.primary,
              ),
              suffixIcon: Container(
                margin: EdgeInsets.all(8.w),
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  'Obligatoire',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            ),
          ),
        ),
        
        SizedBox(height: 12.h),
        
        Text(
          'Votre numéro permet aux autres voyageurs de vous contacter directement',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildTerms(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: _acceptTerms,
          onChanged: (value) => setState(() => _acceptTerms = value ?? false),
        ),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'J\'accepte les ',
                  style: theme.textTheme.bodySmall,
                ),
                TextSpan(
                  text: 'conditions d\'utilisation',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
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
          'Déjà inscrit ? ',
          style: theme.textTheme.bodyMedium,
        ),
        GestureDetector(
          onTap: widget.onBack,
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
    if (_nameController.text.trim().isEmpty || _phoneController.text.trim().isEmpty) {
      _showMessage('Veuillez remplir tous les champs obligatoires');
      return;
    }

    setState(() => _isLoading = true);
    
    // Simulation API call
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      setState(() => _isLoading = false);
      _showMessage('Code de vérification envoyé ! 📱');
      // TODO: Naviguer vers la vérification SMS
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.tertiary,
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }
}