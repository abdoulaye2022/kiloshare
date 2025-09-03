import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:io';

import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_event.dart';

class SocialLoginButtons extends StatelessWidget {
  final bool isLoading;
  
  const SocialLoginButtons({
    super.key,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Divider avec texte "OU"
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Text(
                'OU',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        
        SizedBox(height: 24.h),
        
        // Boutons sociaux
        _SocialButton(
          text: 'Continuer avec Google',
          backgroundColor: Colors.white,
          borderColor: Colors.grey[300]!,
          icon: _buildGoogleIcon(),
          textColor: Colors.black87,
          onPressed: isLoading ? null : () => _signInWithGoogle(context),
        ),
        
        
        // Apple Sign-In seulement sur iOS
        if (Platform.isIOS) ...[
          SizedBox(height: 12.h),
          _SocialButton(
            text: 'Continuer avec Apple',
            backgroundColor: Colors.black,
            icon: const Icon(Icons.apple, color: Colors.white, size: 24),
            textColor: Colors.white,
            onPressed: isLoading ? null : () => _signInWithApple(context),
          ),
        ],
      ],
    );
  }
  
  Widget _buildGoogleIcon() {
    return Container(
      width: 24.w,
      height: 24.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300, width: 0.5),
      ),
      child: Center(
        child: Container(
          width: 18.w,
          height: 18.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
          ),
          child: CustomPaint(
            painter: GoogleLogoPainter(),
            size: Size(18.w, 18.h),
          ),
        ),
      ),
    );
  }
  
  void _signInWithGoogle(BuildContext context) {
    print('🔍 Attempting Google Sign-In...');
    context.read<AuthBloc>().add(const SocialSignInRequested('google'));
  }
  
  
  void _signInWithApple(BuildContext context) {
    print('🔍 Attempting Apple Sign-In...');
    context.read<AuthBloc>().add(const SocialSignInRequested('apple'));
  }
}

class _SocialButton extends StatelessWidget {
  final String text;
  final Color backgroundColor;
  final Color? borderColor;
  final Widget icon;
  final Color textColor;
  final VoidCallback? onPressed;
  
  const _SocialButton({
    required this.text,
    required this.backgroundColor,
    this.borderColor,
    required this.icon,
    required this.textColor,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50.h,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          side: borderColor != null ? BorderSide(color: borderColor!) : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          elevation: 0,
        ),
        icon: SizedBox(width: 24.w, height: 24.h, child: icon),
        label: Text(
          text,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    
    // Background white circle
    paint.color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(2),
      ),
      paint,
    );
    
    // Google "G" avec les bonnes couleurs
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'G',
        style: TextStyle(
          fontSize: size.width * 0.8,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF4285F4), // Google Blue
          fontFamily: 'Roboto',
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    
    final centerX = (size.width - textPainter.width) / 2;
    final centerY = (size.height - textPainter.height) / 2;
    
    textPainter.paint(canvas, Offset(centerX, centerY));
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}