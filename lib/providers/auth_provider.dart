import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  User? _user;
  bool _isLoading = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isSignedIn => _user != null;
  String? get userId => _user?.uid;
  String? get userEmail => _user?.email;
  String get displayName => _user?.displayName ?? _user?.email ?? '匿名用戶';
  bool get isAnonymous => _user?.isAnonymous ?? false;

  AuthProvider() {
    // Listen to auth state changes
    _authService.authStateChanges.listen((User? user) {
      _user = user;
      notifyListeners();
    });

    // Initialize current user
    _user = _authService.currentUser;
  }

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();

    try {
      final userCredential = await _authService.signInWithGoogle();
      _user = userCredential?.user;
      return _user != null;
    } catch (e) {
      debugPrint('Error in AuthProvider.signInWithGoogle: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signInAnonymously() async {
    _isLoading = true;
    notifyListeners();

    try {
      final userCredential = await _authService.signInAnonymously();
      _user = userCredential?.user;
      return _user != null;
    } catch (e) {
      debugPrint('Error in AuthProvider.signInAnonymously: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.signOut();
      _user = null;
    } catch (e) {
      debugPrint('Error in AuthProvider.signOut: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
