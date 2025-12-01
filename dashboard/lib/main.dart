import 'dart:async';
import 'dart:ui' show PlatformDispatcher, PointerDeviceKind; // Import PlatformDispatcher explicitly
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_config.dart';
import 'core/config/supabase_config.dart';
import 'core/platform/platform_detector.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/dashboard/providers/device_provider.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/marketing/screens/landing_page_screen.dart';
import 'shared/widgets/platform_wrapper.dart';

void main() {
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
  
  // Ensure binding is initialized before runapp (although runapp does it)
  // but more importantly before other platform channel calls
  WidgetsFlutterBinding.ensureInitialized(); 
  
  // Let's try running app immediately.
  runApp(const AppRoot());
}

/// Root widget that handles initialization and shows splash screen
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  bool _initialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Defer initialization to the next frame to ensure the UI has a chance to mount
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    debugPrint('AppRoot: Starting initialization...');
    
    // Safety timeout: If initialization takes more than 5 seconds, force the app to load
    // This prevents getting stuck on the loading screen if Supabase hangs
    final timeoutTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && !_initialized) {
        debugPrint('AppRoot: Initialization timed out. Forcing app load in demo mode.');
        setState(() {
          _initialized = true;
          // Don't set error, just let it run
        });
      }
    });

    try {
      // Initialize Supabase
      debugPrint('AppRoot: Checking Supabase Config...');
      
      // Wait for a small delay to ensure the UI has rendered at least one frame
      await Future.delayed(const Duration(milliseconds: 100));

      if (AppConfig.supabaseUrl.isNotEmpty && 
          AppConfig.supabaseAnonKey.isNotEmpty &&
          AppConfig.supabaseAnonKey != 'your-anon-key-here') {
        
        debugPrint('AppRoot: Initializing Supabase...');
        
        // Race Supabase init with a shorter timeout
        // Manually throw generic exception to avoid TimeoutException type issues if it's not imported correctly
        // although dart:async is imported. The error log showed 'TimeoutException' isn't a type.
        // This is strange as dart:async is imported. Let's check imports.
        // Ah, the previous tool call added imports but maybe I missed dart:async in the replace block?
        // Let's fix the replace block to include dart:async at the top.
        
        await Future.any([
          Supabase.initialize(
            url: AppConfig.supabaseUrl,
            anonKey: AppConfig.supabaseAnonKey,
            authOptions: const FlutterAuthClientOptions(
              authFlowType: AuthFlowType.pkce,
            ),
            debug: true,
          ),
          Future.delayed(const Duration(seconds: 4), () {
             // Just return null or throw a simple string to simplify
             throw 'Supabase Init Timeout';
          }),
        ]);
        
        SupabaseConfig.markAsInitialized();
        debugPrint('AppRoot: Supabase initialized successfully');
      } else {
        debugPrint('AppRoot: Warning: Supabase not configured. App will run in demo mode.');
      }

      // Kiosk mode setup (only for non-web platforms)
      if (PlatformDetector.isKiosk && !PlatformDetector.isWeb) {
        await _setupKioskMode();
      }
    } catch (e, stack) {
      debugPrint('AppRoot: Error during initialization: $e');
      debugPrint('Stack: $stack');
      // We don't set _error here to avoid showing the error screen for timeouts
      // instead we just let it fall through to finally and load the app
      
      // Simplified check
      final String errorStr = e.toString();
      if (!errorStr.contains('Timeout')) {
         // Only log actual errors, but still allow app to proceed in demo mode
         debugPrint('AppRoot: Non-fatal initialization error. Proceeding.');
      }
    } finally {
      timeoutTimer.cancel();
      if (mounted && !_initialized) {
        setState(() {
          _initialized = true;
        });
      }
    }
  }

  Future<void> _setupKioskMode() async {
    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
        DeviceOrientation.portraitUp,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    } catch (e) {
      debugPrint('Kiosk mode setup error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show error screen if initialization failed
    if (_error != null) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Initialization Error', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(_error!, textAlign: TextAlign.center),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _error = null;
                      _initialized = false;
                    });
                    _initializeApp();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Show loading screen while initializing
    if (!_initialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                const Text(
                  'PhytoPi Dashboard',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 8),
                Text(
                  'Initializing...',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Show main app when initialized
    return const PhytoPiApp();
  }
}

class PhytoPiApp extends StatelessWidget {
  const PhytoPiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeController()),
        ChangeNotifierProvider(
          create: (_) {
            try {
              return AuthProvider();
            } catch (e, stack) {
              debugPrint('Error creating AuthProvider: $e');
              debugPrint('Stack: $stack');
              return AuthProvider();
            }
          },
        ),
        ChangeNotifierProvider(create: (_) => DeviceProvider()),
      ],
      child: Consumer<ThemeController>(
        builder: (context, themeController, _) {
          return MaterialApp(
            title: AppConfig.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeController.themeMode,
            scrollBehavior: const MaterialScrollBehavior().copyWith(
              physics:
                  const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.stylus,
                PointerDeviceKind.unknown,
              },
            ),
            home: Consumer<AuthProvider>(
              builder: (context, authProvider, _) {
                return Builder(
                  builder: (context) {
                    try {
                      debugPrint('Building home. Web: ${PlatformDetector.isWeb}, Auth: ${authProvider.isAuthenticated}');
                      
                      // If user is authenticated, show dashboard
                      if (authProvider.isAuthenticated) {
                        return const PlatformWrapper(
                          child: DashboardScreen(),
                        );
                      }

                      // Web unauthenticated users show landing page
                      if (PlatformDetector.isWeb) {
                        return const LandingPageScreen();
                      }

                      if (PlatformDetector.isKiosk) {
                        return const PlatformWrapper(
                          child: DashboardScreen(),
                        );
                      } else {
                        return const LoginScreen();
                      }
                    } catch (e, stack) {
                      debugPrint('Error building initial screen: $e');
                      debugPrint('Stack: $stack');
                      return Scaffold(
                        body: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error, size: 48, color: Colors.red),
                              const SizedBox(height: 16),
                              Text('Error loading app: $e'),
                            ],
                          ),
                        ),
                      );
                    }
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
