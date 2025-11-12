import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _initializeAuth();
  }

  void _initializeAuth() {
    if (!SupabaseConfig.isInitialized) {
      debugPrint('AuthProvider: Supabase not initialized - running in demo mode');
      _user = null;
      return;
    }
    
    try {
      // Listen to auth state changes
      SupabaseConfig.client?.auth.onAuthStateChange.listen((data) {
        _user = data.session?.user;
        notifyListeners();
      });
    } catch (e) {
      // Supabase not initialized, app running in demo mode
      debugPrint('AuthProvider: Error setting up auth listener - $e');
      _user = null;
    }
  }

  Future<void> signIn(String email, String password) async {
    if (!SupabaseConfig.isInitialized) {
      _error = 'Supabase is not configured';
      notifyListeners();
      return;
    }
    
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await SupabaseConfig.client?.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signUp(String email, String password) async {
    if (!SupabaseConfig.isInitialized) {
      _error = 'Supabase is not configured';
      notifyListeners();
      return;
    }
    
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await SupabaseConfig.client?.auth.signUp(
        email: email,
        password: password,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    if (!SupabaseConfig.isInitialized) {
      _user = null;
      notifyListeners();
      return;
    }
    
    try {
      _isLoading = true;
      notifyListeners();

      await SupabaseConfig.client?.auth.signOut();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
