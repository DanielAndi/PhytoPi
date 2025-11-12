import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

enum AppPlatform {
  web,
  mobile,
  kiosk,
  desktop,
}

class PlatformDetector {
  static AppPlatform get currentPlatform {
    if (kIsWeb) {
      return AppPlatform.web;
    }
    
    // For non-web platforms, use conditional imports
    return _getCurrentPlatform();
  }
  
  // This will be implemented differently for web vs mobile/desktop
  static AppPlatform _getCurrentPlatform() {
    if (kIsWeb) {
      return AppPlatform.web;
    }
    // For non-web, we need to check the platform
    // Using a try-catch to handle web compilation
    try {
      // This code won't run on web due to kIsWeb check above
      // but we need to handle it for type checking
      return _getPlatformNative();
    } catch (e) {
      // Fallback to web if Platform is not available
      return AppPlatform.web;
    }
  }
  
  static AppPlatform _getPlatformNative() {
    // This is a stub - the actual implementation will be in platform-specific files
    // For now, return web as safe default
    return AppPlatform.web;
  }

  static bool get isWeb => kIsWeb;
  
  static bool get isMobile {
    if (kIsWeb) return false;
    try {
      return _isMobileNative();
    } catch (e) {
      return false;
    }
  }
  
  static bool _isMobileNative() {
    // Stub - should be implemented in platform-specific code
    return false;
  }
  
  static bool get isKiosk => currentPlatform == AppPlatform.kiosk;
  
  static bool get isDesktop {
    if (kIsWeb) return false;
    try {
      return _isDesktopNative();
    } catch (e) {
      return false;
    }
  }
  
  static bool _isDesktopNative() {
    // Stub - should be implemented in platform-specific code
    return false;
  }

  static bool _isKioskMode() {
    // Check compile-time flag to determine if in kiosk mode
    // For web, kiosk mode is determined at build time
    const kioskMode = bool.fromEnvironment('KIOSK_MODE', defaultValue: false);
    return kioskMode;
  }

  static bool isLargeScreen(BuildContext context) {
    // Useful for responsive design
    if (kIsWeb) {
      final width = MediaQuery.of(context).size.width;
      return width >= 1200;
    }
    // For mobile, check screen size
    final size = MediaQuery.of(context).size;
    return size.width >= 600;
  }

  static bool isTablet(BuildContext context) {
    if (kIsWeb) return false;
    final size = MediaQuery.of(context).size;
    final diagonal = (size.width * size.width + size.height * size.height) / (size.width + size.height);
    return diagonal > 7.0; // Approximate tablet size
  }
}

