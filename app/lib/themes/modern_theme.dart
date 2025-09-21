import 'package:flutter/material.dart';

class ModernTheme {
  // Couleurs principales
  static const Color primaryBlue = Color(0xFF2563EB); // Bleu moderne
  static const Color lightBlue = Color(0xFFE0F2FE);
  static const Color darkBlue = Color(0xFF1E3A8A);
  
  // Couleurs neutres
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF0F172A);
  static const Color gray50 = Color(0xFFF8FAFC);
  static const Color gray100 = Color(0xFFF1F5F9);
  static const Color gray200 = Color(0xFFE2E8F0);
  static const Color gray300 = Color(0xFFCBD5E1);
  static const Color gray400 = Color(0xFF94A3B8);
  static const Color gray500 = Color(0xFF64748B);
  static const Color gray600 = Color(0xFF475569);
  static const Color gray700 = Color(0xFF334155);
  static const Color gray800 = Color(0xFF1E293B);
  static const Color gray900 = Color(0xFF0F172A);

  // Couleurs d'état
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Espacements
  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;

  // Rayons de bordure
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 20.0;

  // Ombres
  static List<BoxShadow> shadowSmall = [
    BoxShadow(
      color: black.withOpacity(0.1),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> shadowMedium = [
    BoxShadow(
      color: black.withOpacity(0.1),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> shadowLarge = [
    BoxShadow(
      color: black.withOpacity(0.15),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];

  // Animations
  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationNormal = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);

  static const Curve animationCurve = Curves.easeInOut;
}

// Widgets personnalisés avec animations

class AnimatedContainer extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? backgroundColor;
  final double? borderRadius;
  final List<BoxShadow>? boxShadow;
  final VoidCallback? onTap;

  const AnimatedContainer({
    super.key,
    required this.child,
    this.duration = ModernTheme.animationNormal,
    this.curve = ModernTheme.animationCurve,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.borderRadius,
    this.boxShadow,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: duration,
      curve: curve,
      tween: Tween<double>(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.95 + (0.05 * value),
          child: Opacity(
            opacity: value,
            child: Container(
              padding: padding,
              margin: margin,
              decoration: BoxDecoration(
                color: backgroundColor ?? ModernTheme.white,
                borderRadius: BorderRadius.circular(borderRadius ?? ModernTheme.radiusMedium),
                boxShadow: boxShadow,
              ),
              child: onTap != null
                  ? InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(borderRadius ?? ModernTheme.radiusMedium),
                      child: this.child,
                    )
                  : this.child,
            ),
          ),
        );
      },
    );
  }
}

class FadeInSlideUp extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;

  const FadeInSlideUp({
    super.key,
    required this.child,
    this.duration = ModernTheme.animationNormal,
    this.delay = Duration.zero,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: duration,
      curve: ModernTheme.animationCurve,
      tween: Tween<double>(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: this.child,
          ),
        );
      },
      child: child,
    );
  }
}

class ModernCard extends StatefulWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  final bool elevated;

  const ModernCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.elevated = true,
  });

  @override
  State<ModernCard> createState() => _ModernCardState();
}

class _ModernCardState extends State<ModernCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: ModernTheme.animationFast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: ModernTheme.animationCurve,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            margin: widget.margin ?? const EdgeInsets.all(ModernTheme.spacing8),
            decoration: BoxDecoration(
              color: ModernTheme.white,
              borderRadius: BorderRadius.circular(ModernTheme.radiusLarge),
              boxShadow: widget.elevated ? ModernTheme.shadowMedium : null,
              border: !widget.elevated 
                  ? Border.all(color: ModernTheme.gray200, width: 1)
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                onTapDown: widget.onTap != null ? (_) => _controller.forward() : null,
                onTapUp: widget.onTap != null ? (_) => _controller.reverse() : null,
                onTapCancel: widget.onTap != null ? () => _controller.reverse() : null,
                borderRadius: BorderRadius.circular(ModernTheme.radiusLarge),
                child: Padding(
                  padding: widget.padding ?? const EdgeInsets.all(ModernTheme.spacing16),
                  child: widget.child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class ModernButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final bool isLoading;
  final ModernButtonStyle style;

  const ModernButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.isLoading = false,
    this.style = ModernButtonStyle.primary,
  });

  @override
  State<ModernButton> createState() => _ModernButtonState();
}

enum ModernButtonStyle { primary, secondary, outline, ghost }

class _ModernButtonState extends State<ModernButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: ModernTheme.animationFast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: ModernTheme.animationCurve,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _backgroundColor {
    if (widget.backgroundColor != null) return widget.backgroundColor!;
    
    switch (widget.style) {
      case ModernButtonStyle.primary:
        return ModernTheme.primaryBlue;
      case ModernButtonStyle.secondary:
        return ModernTheme.gray100;
      case ModernButtonStyle.outline:
      case ModernButtonStyle.ghost:
        return Colors.transparent;
    }
  }

  Color get _textColor {
    if (widget.textColor != null) return widget.textColor!;
    
    switch (widget.style) {
      case ModernButtonStyle.primary:
        return ModernTheme.white;
      case ModernButtonStyle.secondary:
      case ModernButtonStyle.outline:
      case ModernButtonStyle.ghost:
        return ModernTheme.gray900;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              color: _backgroundColor,
              borderRadius: BorderRadius.circular(ModernTheme.radiusMedium),
              border: widget.style == ModernButtonStyle.outline 
                  ? Border.all(color: ModernTheme.gray300, width: 1)
                  : null,
              boxShadow: widget.style == ModernButtonStyle.primary 
                  ? ModernTheme.shadowSmall
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.isLoading ? null : widget.onPressed,
                onTapDown: widget.onPressed != null ? (_) => _controller.forward() : null,
                onTapUp: widget.onPressed != null ? (_) => _controller.reverse() : null,
                onTapCancel: widget.onPressed != null ? () => _controller.reverse() : null,
                borderRadius: BorderRadius.circular(ModernTheme.radiusMedium),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ModernTheme.spacing24,
                    vertical: ModernTheme.spacing16,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.isLoading) ...[
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(_textColor),
                          ),
                        ),
                        const SizedBox(width: ModernTheme.spacing8),
                      ] else if (widget.icon != null) ...[
                        Icon(
                          widget.icon,
                          size: 18,
                          color: _textColor,
                        ),
                        const SizedBox(width: ModernTheme.spacing8),
                      ],
                      Flexible(
                        child: Text(
                          widget.text,
                          style: TextStyle(
                            color: _textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}