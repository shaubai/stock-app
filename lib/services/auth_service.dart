import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

/// The subset of AuthService that AuthProvider depends on.
///
/// Exists so AuthProvider can be constructed with a fake implementation in
/// tests, instead of always going through real Firebase/Google Sign-In.
abstract class AuthServiceBase {
  User? get currentUser;
  Stream<User?> get authStateChanges;
  Future<UserCredential?> signInWithGoogle();
  Future<UserCredential?> signInAnonymously();
  Future<void> signOut();
}

class AuthService implements AuthServiceBase {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Get current user
  @override
  User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes
  @override
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with Google
  @override
  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Web: Use popup
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        return await _auth.signInWithPopup(googleProvider);
      } else {
        // Mobile: Use Google Sign-In flow
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

        if (googleUser == null) {
          // User cancelled
          return null;
        }

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        return await _auth.signInWithCredential(credential);
      }
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      rethrow;
    }
  }

  /// Sign in anonymously
  @override
  Future<UserCredential?> signInAnonymously() async {
    try {
      return await _auth.signInAnonymously();
    } catch (e) {
      debugPrint('Error signing in anonymously: $e');
      rethrow;
    }
  }

  /// Sign out
  @override
  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        await _googleSignIn.signOut();
      }
      await _auth.signOut();
    } catch (e) {
      debugPrint('Error signing out: $e');
      rethrow;
    }
  }

  /// Check if user is signed in
  bool isSignedIn() {
    return _auth.currentUser != null;
  }

  /// Get user ID
  String? getUserId() {
    return _auth.currentUser?.uid;
  }

  /// Get user email
  String? getUserEmail() {
    return _auth.currentUser?.email;
  }

  /// Get user display name
  String? getUserDisplayName() {
    return _auth.currentUser?.displayName ?? '匿名用戶';
  }

  /// Check if user is anonymous
  bool isAnonymous() {
    return _auth.currentUser?.isAnonymous ?? false;
  }
}
