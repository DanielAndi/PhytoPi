import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_config.dart';
import 'core/config/supabase_config.dart';
import 'core/platform/platform_detector.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'shared/widgets/platform_wrapper.dart';

void main() async {
  // Add comprehensive error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter Error: ${details.exception}');
    debugPrint('Stack: ${details.stack}');
  };
  
  // Handle platform errors
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Platform Error: $error');
    debugPrint('Stack: $stack');
    return true;
  };
  
  try {
    WidgetsFlutterBinding.ensureInitialized();
    debugPrint('Flutter binding initialized');
  } catch (e, stack) {
    debugPrint('Error initializing Flutter binding: $e');
    debugPrint('Stack: $stack');
    // Still try to run the app
  }
  
  // Initialize Supabase with error handling
  try {
    // Only initialize if we have valid-looking credentials
    if (AppConfig.supabaseUrl.isNotEmpty && 
        AppConfig.supabaseAnonKey.isNotEmpty &&
        AppConfig.supabaseAnonKey != 'your-anon-key-here') {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
      );
      SupabaseConfig.markAsInitialized();
      debugPrint('Supabase initialized successfully');
    } else {
      debugPrint('Warning: Supabase not configured. App will run in demo mode.');
    }
  } catch (e, stack) {
    // Log error but don't crash the app
    debugPrint('Error initializing Supabase: $e');
    debugPrint('Stack: $stack');
    debugPrint('App will continue without Supabase connection.');
  }
  
  // Kiosk mode setup (only for non-web platforms)
  try {
    if (PlatformDetector.isKiosk && !PlatformDetector.isWeb) {
      await _setupKioskMode();
    }
  } catch (e, stack) {
    debugPrint('Error in kiosk setup: $e');
    debugPrint('Stack: $stack');
  }
  
  try {
    debugPrint('Starting app...');
    runApp(const PhytoPiApp());
    debugPrint('App started');
  } catch (e, stack) {
    debugPrint('Fatal error starting app: $e');
    debugPrint('Stack: $stack');
    // Try to show error UI
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Error: $e'),
        ),
      ),
    ));
  }
}

/// Setup kiosk mode: fullscreen, prevent sleep, set orientation
Future<void> _setupKioskMode() async {
  try {
    // Set preferred orientations (typically landscape for kiosks)
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp, // Allow portrait as fallback
    ]);
    
    // Hide system UI for true fullscreen (kiosk mode)
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    
    // Keep screen on (prevent sleep)
    // Note: This might require platform-specific plugins for production
    // For now, we rely on system settings
    
    // Prevent app from being closed easily (kiosk mode)
    // Platform-specific implementations would go here
  } catch (e) {
    // Ignore errors if platform doesn't support these features
    debugPrint('Kiosk mode setup error: $e');
  }
}

class PhytoPiApp extends StatelessWidget {
  const PhytoPiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            try {
              return AuthProvider();
            } catch (e, stack) {
              debugPrint('Error creating AuthProvider: $e');
              debugPrint('Stack: $stack');
              // Return a minimal provider that won't crash
              return AuthProvider();
            }
          },
        ),
      ],
      child: MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        home: Builder(
          builder: (context) {
            try {
              return const PlatformWrapper(
                child: DashboardScreen(),
              );
            } catch (e, stack) {
              debugPrint('Error building dashboard: $e');
              debugPrint('Stack: $stack');
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error loading dashboard: $e'),
                    ],
                  ),
                ),
              );
            }
          },
        ),
        // Disable back button in kiosk mode
        builder: (context, child) {
          try {
            if (PlatformDetector.isKiosk && !AppConfig.enableBackButton) {
              return PopScope(
                canPop: false,
                child: child!,
              );
            }
            return child!;
          } catch (e) {
            debugPrint('Error in builder: $e');
            return child!;
          }
        },
      ),
    );
  }

  /// Build platform-specific theme
  ThemeData _buildTheme() {
    final baseTheme = ThemeData(
      primarySwatch: Colors.green,
      primaryColor: const Color(0xFF2E7D32),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2E7D32),
        brightness: Brightness.light,
      ),
      useMaterial3: true,
    );

    // Platform-specific theme adjustments
    if (PlatformDetector.isKiosk) {
      return baseTheme.copyWith(
        // Larger text for kiosk viewing distance
        textTheme: baseTheme.textTheme.apply(fontSizeFactor: 1.2),
        // High contrast for better visibility
        brightness: Brightness.light,
      );
    } else if (PlatformDetector.isMobile) {
      return baseTheme.copyWith(
        // Mobile-optimized theme
        textTheme: baseTheme.textTheme,
      );
    }
    
    // Web/Desktop theme
    return baseTheme;
  }
}
