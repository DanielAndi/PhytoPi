import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static SupabaseClient get client => Supabase.instance.client;
  
  // Database Tables
  static const String devicesTable = 'devices';
  static const String sensorsTable = 'sensors';
  static const String readingsTable = 'readings';
  static const String alertsTable = 'alerts';
  static const String usersTable = 'users';
  static const String mlInferencesTable = 'ml_inferences';
  
  // Real-time Channels
  static const String readingsChannel = 'readings';
  static const String alertsChannel = 'alerts';
  static const String devicesChannel = 'devices';
}
