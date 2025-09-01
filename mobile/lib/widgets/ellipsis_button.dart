import 'package:flutter/material.dart';

/// Widget bouton avec ellipsis automatique pour éviter les retours à la ligne
class EllipsisButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget? icon;
  final String text;
  final ButtonStyle? style;
  final bool isElevated;
  final bool isOutlined;

  const EllipsisButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.icon,
    this.style,
    this.isElevated = true,
    this.isOutlined = false,
  });

  const EllipsisButton.elevated({
    super.key,
    required this.onPressed,
    required this.text,
    this.icon,
    this.style,
  }) : isElevated = true, isOutlined = false;

  const EllipsisButton.outlined({
    super.key,
    required this.onPressed,
    required this.text,
    this.icon,
    this.style,
  }) : isElevated = false, isOutlined = true;

  const EllipsisButton.text({
    super.key,
    required this.onPressed,
    required this.text,
    this.icon,
    this.style,
  }) : isElevated = false, isOutlined = false;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text,
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
      style: const TextStyle(fontSize: 14),
    );

    if (isElevated) {
      return icon != null
        ? ElevatedButton.icon(
            onPressed: onPressed,
            icon: icon!,
            label: label,
            style: style?.copyWith(
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ) ?? ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          )
        : ElevatedButton(
            onPressed: onPressed,
            style: style?.copyWith(
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ) ?? ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: label,
          );
    } else if (isOutlined) {
      return icon != null
        ? OutlinedButton.icon(
            onPressed: onPressed,
            icon: icon!,
            label: label,
            style: style?.copyWith(
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ) ?? OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          )
        : OutlinedButton(
            onPressed: onPressed,
            style: style?.copyWith(
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ) ?? OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: label,
          );
    } else {
      return icon != null
        ? TextButton.icon(
            onPressed: onPressed,
            icon: icon!,
            label: label,
            style: style?.copyWith(
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ) ?? TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          )
        : TextButton(
            onPressed: onPressed,
            style: style?.copyWith(
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ) ?? TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: label,
          );
    }
  }
}