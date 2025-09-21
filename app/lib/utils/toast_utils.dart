import 'package:flutter/material.dart';

class ToastUtils {
  /// Affiche un toast de succès collé au bas de l'écran
  static void showSuccess(BuildContext context, String message, {int seconds = 3}) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.fixed,
        margin: EdgeInsets.zero,
        duration: Duration(seconds: seconds),
      ),
    );
  }

  /// Affiche un toast d'erreur collé au bas de l'écran
  static void showError(BuildContext context, String message, {int seconds = 4}) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.fixed,
        margin: EdgeInsets.zero,
        duration: Duration(seconds: seconds),
      ),
    );
  }

  /// Affiche un toast d'information collé au bas de l'écran
  static void showInfo(BuildContext context, String message, {int seconds = 3}) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.fixed,
        margin: EdgeInsets.zero,
        duration: Duration(seconds: seconds),
      ),
    );
  }

  /// Affiche un toast d'avertissement collé au bas de l'écran
  static void showWarning(BuildContext context, String message, {int seconds = 3}) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.fixed,
        margin: EdgeInsets.zero,
        duration: Duration(seconds: seconds),
      ),
    );
  }

  /// Affiche un toast personnalisé collé au bas de l'écran
  static void showCustom(
    BuildContext context,
    String message, {
    Color? backgroundColor,
    Color? textColor,
    IconData? icon,
    int seconds = 3,
  }) {
    if (!context.mounted) return;

    Widget content = Text(
      message,
      style: textColor != null ? TextStyle(color: textColor) : null,
    );

    if (icon != null) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textColor ?? Colors.white),
          const SizedBox(width: 8),
          Expanded(child: content),
        ],
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: content,
        backgroundColor: backgroundColor ?? Colors.grey[800],
        behavior: SnackBarBehavior.fixed,
        margin: EdgeInsets.zero,
        duration: Duration(seconds: seconds),
      ),
    );
  }

  /// Affiche un toast avec action collé au bas de l'écran
  static void showWithAction(
    BuildContext context,
    String message, {
    required String actionLabel,
    required VoidCallback onActionPressed,
    Color? backgroundColor,
    int seconds = 5,
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor ?? Colors.grey[800],
        behavior: SnackBarBehavior.fixed,
        margin: EdgeInsets.zero,
        duration: Duration(seconds: seconds),
        action: SnackBarAction(
          label: actionLabel,
          textColor: Colors.white,
          onPressed: onActionPressed,
        ),
      ),
    );
  }
}