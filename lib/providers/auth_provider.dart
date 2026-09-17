import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

/// Resolves the display name to show for a user, given Firebase's raw
/// displayName/email fields.
///
/// Pulled out as a standalone function (rather than inline in the
/// AuthProvider getter) because it's independently testable without needing
/// a real firebase_auth User instance, and because it fixes a real bug:
/// Firebase can return an empty string (not null) for displayName, which
/// bypassed a naive `??` fallback chain and caused a RangeError when the UI
/// tried to read character [0] of an empty display name.
String resolveDisplayName({String? displayName, String? email}) {
  if (displayName != null && displayName.isNotEmpty) return displayName;
  if (email != null && email.isNotEmpty) return email;
  return '匿名用戶';
}

class AuthProvider with ChangeNotifier {
  final AuthServiceBase _authService;
  User? _user;
  bool _isLoading = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isSignedIn => _user != null;
  String? get userId => _user?.uid;
  String? get userEmail => _user?.email;
  String get displayName =>
      resolveDisplayName(displayName: _user?.displayName, email: _user?.email);
  bool get isAnonymous => _user?.isAnonymous ?? false;

  AuthProvider({AuthServiceBase? authService})
      : _authService = authService ?? AuthService() {
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
