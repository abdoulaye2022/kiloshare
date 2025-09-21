import 'package:flutter/foundation.dart';

class PlatformHelper {
  static bool get isAndroid {
    if (kIsWeb) return false;
    // Sur le web, on ne peut pas utiliser Platform.isAndroid
    return defaultTargetPlatform == TargetPlatform.android;
  }
  
  static bool get isIOS {
    if (kIsWeb) return false;
    // Sur le web, on ne peut pas utiliser Platform.isIOS
    return defaultTargetPlatform == TargetPlatform.iOS;
  }
  
  static bool get isMobile => isAndroid || isIOS;
  static bool get isWeb => kIsWeb;
}