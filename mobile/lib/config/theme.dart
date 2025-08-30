import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppTheme {
  // Couleurs basées sur le logo bleu "K" de KiloShare
  static const Color primaryColor = Color(0xFF4A7DD8);        // Bleu principal du logo
  static const Color primaryDarkColor = Color(0xFF2D5AA6);    // Bleu plus sombre
  static const Color primaryLightColor = Color(0xFFE8F0FE);   // Bleu très clair
  static const Color secondaryColor = Color(0xFF6366F1);      // Indigo moderne
  static const Color accentColor = Color(0xFF10B981);         // Vert success
  
  static const Color backgroundColor = Color(0xFFF5F7FA);      // Gris très clair
  static const Color surfaceColor = Color(0xFFFFFFFF);        // Blanc pur
  static const Color surfaceVariantColor = Color(0xFFF8FAFC); // Blanc légèrement teinté
  static const Color errorColor = Color(0xFFEF4444);          // Rouge moderne
  static const Color warningColor = Color(0xFFF59E0B);        // Orange/jaune
  
  static const Color textPrimaryColor = Color(0xFF1F2937);    // Gris très sombre/noir
  static const Color textSecondaryColor = Color(0xFF6B7280);  // Gris moyen
  static const Color textTertiaryColor = Color(0xFF9CA3AF);   // Gris clair
  static const Color textHintColor = Color(0xFFD1D5DB);       // Gris très clair
  
  static const Color dividerColor = Color(0xFFE5E7EB);        // Bordure claire
  static const Color shadowColor = Color(0x0F000000);         // Ombre légère
  
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primarySwatch: MaterialColor(primaryColor.value, const {
      50: Color(0xFFEEF4FF),
      100: Color(0xFFDBE4FF),
      200: Color(0xFFBFD0FF),
      300: Color(0xFF93AFFF),
      400: Color(0xFF6080FF),
      500: primaryColor,
      600: Color(0xFF3B6FE5),
      700: Color(0xFF2D5AA6),
      800: Color(0xFF2A4E96),
      900: Color(0xFF274385),
    }),
    scaffoldBackgroundColor: backgroundColor,
    
    colorScheme: const ColorScheme.light(
      primary: primaryColor,
      onPrimary: Colors.white,
      secondary: secondaryColor,
      onSecondary: Colors.white,
      tertiary: accentColor,
      onTertiary: Colors.white,
      surface: surfaceColor,
      onSurface: textPrimaryColor,
      surfaceVariant: surfaceVariantColor,
      onSurfaceVariant: textSecondaryColor,
      error: errorColor,
      onError: Colors.white,
      background: backgroundColor,
      onBackground: textPrimaryColor,
      outline: dividerColor,
      shadow: shadowColor,
    ),
    
    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: surfaceColor,
      foregroundColor: textPrimaryColor,
      titleTextStyle: TextStyle(
        color: textPrimaryColor,
        fontSize: 18.sp,
        fontWeight: FontWeight.w600,
        fontFamily: 'Poppins',
      ),
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    ),
    
    textTheme: TextTheme(
      displayLarge: TextStyle(
        fontSize: 32.sp,
        fontWeight: FontWeight.bold,
        color: textPrimaryColor,
        fontFamily: 'Poppins',
      ),
      displayMedium: TextStyle(
        fontSize: 28.sp,
        fontWeight: FontWeight.bold,
        color: textPrimaryColor,
        fontFamily: 'Poppins',
      ),
      displaySmall: TextStyle(
        fontSize: 24.sp,
        fontWeight: FontWeight.w600,
        color: textPrimaryColor,
        fontFamily: 'Poppins',
      ),
      headlineMedium: TextStyle(
        fontSize: 20.sp,
        fontWeight: FontWeight.w600,
        color: textPrimaryColor,
        fontFamily: 'Poppins',
      ),
      headlineSmall: TextStyle(
        fontSize: 18.sp,
        fontWeight: FontWeight.w600,
        color: textPrimaryColor,
        fontFamily: 'Poppins',
      ),
      titleLarge: TextStyle(
        fontSize: 16.sp,
        fontWeight: FontWeight.w600,
        color: textPrimaryColor,
        fontFamily: 'Poppins',
      ),
      titleMedium: TextStyle(
        fontSize: 14.sp,
        fontWeight: FontWeight.w500,
        color: textPrimaryColor,
        fontFamily: 'Poppins',
      ),
      bodyLarge: TextStyle(
        fontSize: 16.sp,
        fontWeight: FontWeight.normal,
        color: textPrimaryColor,
        fontFamily: 'Poppins',
      ),
      bodyMedium: TextStyle(
        fontSize: 14.sp,
        fontWeight: FontWeight.normal,
        color: textSecondaryColor,
        fontFamily: 'Poppins',
      ),
      bodySmall: TextStyle(
        fontSize: 12.sp,
        fontWeight: FontWeight.normal,
        color: textSecondaryColor,
        fontFamily: 'Poppins',
      ),
      labelLarge: TextStyle(
        fontSize: 14.sp,
        fontWeight: FontWeight.w500,
        color: textPrimaryColor,
        fontFamily: 'Poppins',
      ),
    ),
    
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        minimumSize: Size(double.infinity, 52.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        elevation: 0,
        shadowColor: Colors.transparent,
        textStyle: TextStyle(
          fontSize: 16.sp,
          fontWeight: FontWeight.w600,
          fontFamily: 'Poppins',
          letterSpacing: 0.5,
        ),
      ),
    ),
    
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        minimumSize: Size(double.infinity, 48.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        side: const BorderSide(color: primaryColor, width: 1.5),
        textStyle: TextStyle(
          fontSize: 16.sp,
          fontWeight: FontWeight.w600,
          fontFamily: 'Poppins',
        ),
      ),
    ),
    
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceVariantColor,
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.r),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.r),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.r),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.r),
        borderSide: const BorderSide(color: errorColor, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.r),
        borderSide: const BorderSide(color: errorColor, width: 2),
      ),
      labelStyle: TextStyle(
        color: textSecondaryColor,
        fontSize: 14.sp,
        fontWeight: FontWeight.w500,
        fontFamily: 'Poppins',
      ),
      floatingLabelStyle: TextStyle(
        color: primaryColor,
        fontSize: 14.sp,
        fontWeight: FontWeight.w500,
        fontFamily: 'Poppins',
      ),
      hintStyle: TextStyle(
        color: textTertiaryColor,
        fontSize: 14.sp,
        fontFamily: 'Poppins',
      ),
      prefixIconColor: textTertiaryColor,
      suffixIconColor: textTertiaryColor,
    ),
    
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
      ),
      color: surfaceColor,
      shadowColor: shadowColor,
    ),
    
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surfaceColor,
      selectedItemColor: primaryColor,
      unselectedItemColor: textSecondaryColor,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
  );
  
  static ThemeData darkTheme = lightTheme.copyWith(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF121212),
    colorScheme: const ColorScheme.dark(
      primary: primaryColor,
      secondary: secondaryColor,
      surface: Color(0xFF1E1E1E),
      error: errorColor,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.white,
      onError: Colors.white,
    ),
  );
}