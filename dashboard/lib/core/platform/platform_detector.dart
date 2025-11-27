import 'dart:io' show Platform;
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
    // Check if we're in kiosk mode first (Linux with KIOSK_MODE=true)
    if (_isKioskMode()) {
      return AppPlatform.kiosk;
    }
    
    // Check if mobile platform
    if (_isMobileNative()) {
      return AppPlatform.mobile;
    }
    
    // Default to desktop for Linux, Windows, macOS
    return AppPlatform.desktop;
  }

  static bool get isWeb => kIsWeb;
  
  static bool get isMobile {
    // Allow forcing mobile layout for testing on desktop/web
    if (const bool.fromEnvironment('FORCE_MOBILE')) return true;

    if (kIsWeb) return false;
    try {
      return _isMobileNative();
    } catch (e) {
      return false;
    }
  }
  
  static bool _isMobileNative() {
    // Check if running on Android or iOS
    return Platform.isAndroid || Platform.isIOS;
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
    // Check if running on desktop platforms (Linux, Windows, macOS)
    return Platform.isLinux || Platform.isWindows || Platform.isMacOS;
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

