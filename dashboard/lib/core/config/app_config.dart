class AppConfig {
  // Supabase Configuration
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'http://localhost:54321',
  );
  
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'your-anon-key-here',
  );
  
  // App Configuration
  static const String appName = 'PhytoPi Dashboard';
  static const String appVersion = '1.0.0';
  
  // API Configuration
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:54321',
  );
  
  // Feature Flags
  static const bool enableAnalytics = true;
  static const bool enableNotifications = true;
  static const bool enableMLInsights = true;
}
