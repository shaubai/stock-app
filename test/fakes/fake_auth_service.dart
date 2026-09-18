import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:stock_app/services/auth_service.dart';

/// Fake AuthServiceBase for testing without real Firebase.
///
/// UserCredential/User have private constructors in firebase_auth and can't
/// be faked here, so sign-in methods return null — this covers the
/// "cancelled or failed sign-in" path, not "successful sign-in", but that's
/// enough to exercise auth-dependent code's isLoading/error-handling logic
/// and unauthenticated-state UI (e.g. LoginScreen), which don't otherwise
/// depend on inspecting the resulting user.
///
/// Shared between test/providers/auth_provider_test.dart (drives
/// AuthProvider directly) and test/widget_test.dart (builds the whole app
/// with currentUserValue left null, so AuthWrapper renders LoginScreen
/// without ever touching real Firebase).
class FakeAuthService implements AuthServiceBase {
  final _controller = StreamController<User?>.broadcast();
  User? currentUserValue;
  bool throwOnSignIn = false;
  bool throwOnSignOut = false;
  int signInWithGoogleCallCount = 0;
  int signInAnonymouslyCallCount = 0;
  int signOutCallCount = 0;

  @override
  User? get currentUser => currentUserValue;

  @override
  Stream<User?> get authStateChanges => _controller.stream;

  @override
  Future<UserCredential?> signInWithGoogle() async {
    signInWithGoogleCallCount++;
    if (throwOnSignIn) throw Exception('simulated sign-in failure');
    return null; // simulates user cancelling the flow
  }

  @override
  Future<UserCredential?> signInAnonymously() async {
    signInAnonymouslyCallCount++;
    if (throwOnSignIn) throw Exception('simulated sign-in failure');
    return null;
  }

  @override
  Future<void> signOut() async {
    signOutCallCount++;
    if (throwOnSignOut) throw Exception('simulated sign-out failure');
  }

  void dispose() => _controller.close();
}
