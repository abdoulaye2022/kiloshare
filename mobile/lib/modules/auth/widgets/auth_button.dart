import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AuthButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isSecondary;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;

  const AuthButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isSecondary = false,
    this.icon,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    final effectiveBackgroundColor = backgroundColor ?? 
        (isSecondary ? theme.colorScheme.surface : theme.colorScheme.primary);
    
    final effectiveTextColor = textColor ?? 
        (isSecondary ? theme.colorScheme.primary : theme.colorScheme.onPrimary);

    return SizedBox(
      height: 52.h,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: effectiveBackgroundColor,
          foregroundColor: effectiveTextColor,
          elevation: isSecondary ? 0 : 2,
          shadowColor: theme.shadowColor.withOpacity(0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
            side: isSecondary ? BorderSide(
              color: theme.colorScheme.primary,
              width: 1.5,
            ) : BorderSide.none,
          ),
          textStyle: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        child: isLoading
            ? SizedBox(
                height: 20.h,
                width: 20.w,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(effectiveTextColor),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20.sp),
                    SizedBox(width: 8.w),
                  ],
                  Text(text),
                ],
              ),
      ),
    );
  }
}

class SocialButton extends StatelessWidget {
  final String text;
  final String iconPath;
  final VoidCallback? onPressed;
  final bool isLoading;

  const SocialButton({
    super.key,
    required this.text,
    required this.iconPath,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 52.h,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: theme.colorScheme.surface,
          foregroundColor: theme.colorScheme.onSurface,
          side: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          textStyle: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        child: isLoading
            ? SizedBox(
                height: 20.h,
                width: 20.w,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.onSurface,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // For now, using an icon instead of SVG
                  Icon(
                    _getIconFromPath(iconPath),
                    size: 20.sp,
                    color: theme.colorScheme.onSurface,
                  ),
                  SizedBox(width: 12.w),
                  Text(text),
                ],
              ),
      ),
    );
  }

  IconData _getIconFromPath(String path) {
    // Simple mapping for common social icons
    if (path.contains('google')) return Icons.g_mobiledata;
    if (path.contains('apple')) return Icons.apple;
    return Icons.login;
  }
}