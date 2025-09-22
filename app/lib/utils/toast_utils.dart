import 'package:flutter/material.dart';

class ToastUtils {
  /// Affiche un toast de succès collé au bas de l'écran
  static void showSuccess(BuildContext context, String message, {int seconds = 3}) {
    if (!context.mounted) return;

    try {
      ScaffoldMessenger.of(context)
        ..clearSnackBars() // Effacer les précédents snackbars
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.fixed,
            duration: Duration(seconds: seconds),
          ),
        );
    } catch (e) {
      // Si erreur avec ScaffoldMessenger, ne pas planter l'app
      debugPrint('ToastUtils.showSuccess error: $e');
    }
  }

  /// Affiche un toast d'erreur collé au bas de l'écran
  static void showError(BuildContext context, String message, {int seconds = 4}) {
    if (!context.mounted) return;

    try {
      ScaffoldMessenger.of(context)
        ..clearSnackBars() // Effacer les précédents snackbars
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.fixed,
            duration: Duration(seconds: seconds),
          ),
        );
    } catch (e) {
      // Si erreur avec ScaffoldMessenger, ne pas planter l'app
      debugPrint('ToastUtils.showError error: $e');
    }
  }

  /// Affiche un toast d'information collé au bas de l'écran
  static void showInfo(BuildContext context, String message, {int seconds = 3}) {
    if (!context.mounted) return;

    try {
      ScaffoldMessenger.of(context)
        ..clearSnackBars() // Effacer les précédents snackbars
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.blue,
            behavior: SnackBarBehavior.fixed,
            duration: Duration(seconds: seconds),
          ),
        );
    } catch (e) {
      // Si erreur avec ScaffoldMessenger, ne pas planter l'app
      debugPrint('ToastUtils.showInfo error: $e');
    }
  }

  /// Affiche un toast d'avertissement collé au bas de l'écran
  static void showWarning(BuildContext context, String message, {int seconds = 3}) {
    if (!context.mounted) return;

    try {
      ScaffoldMessenger.of(context)
        ..clearSnackBars() // Effacer les précédents snackbars
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.fixed,
            duration: Duration(seconds: seconds),
          ),
        );
    } catch (e) {
      // Si erreur avec ScaffoldMessenger, ne pas planter l'app
      debugPrint('ToastUtils.showWarning error: $e');
    }
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

    try {
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

      ScaffoldMessenger.of(context)
        ..clearSnackBars() // Effacer les précédents snackbars
        ..showSnackBar(
          SnackBar(
            content: content,
            backgroundColor: backgroundColor ?? Colors.grey[800],
            behavior: SnackBarBehavior.fixed,
            duration: Duration(seconds: seconds),
          ),
        );
    } catch (e) {
      // Si erreur avec ScaffoldMessenger, ne pas planter l'app
      debugPrint('ToastUtils.showCustom error: $e');
    }
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

    try {
      ScaffoldMessenger.of(context)
        ..clearSnackBars() // Effacer les précédents snackbars
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: backgroundColor ?? Colors.grey[800],
            behavior: SnackBarBehavior.fixed,
            duration: Duration(seconds: seconds),
            action: SnackBarAction(
              label: actionLabel,
              textColor: Colors.white,
              onPressed: onActionPressed,
            ),
          ),
        );
    } catch (e) {
      // Si erreur avec ScaffoldMessenger, ne pas planter l'app
      debugPrint('ToastUtils.showWithAction error: $e');
    }
  }
}