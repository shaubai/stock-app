import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_app/providers/auth_provider.dart';
import 'package:stock_app/services/auth_service.dart';

/// Fake AuthServiceBase for testing AuthProvider without real Firebase.
///
/// UserCredential/User have private constructors in firebase_auth and can't
/// be faked here, so sign-in methods return null — this covers the
/// "cancelled or failed sign-in" path, not "successful sign-in", but that's
/// enough to exercise AuthProvider's isLoading/error-handling logic, which
/// doesn't otherwise depend on inspecting the resulting user.
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

void main() {
  group('resolveDisplayName', () {
    test('uses displayName when present and non-empty', () {
      expect(
        resolveDisplayName(displayName: 'Wen', email: 'wen@example.com'),
        'Wen',
      );
    });

    test('falls back to email when displayName is null', () {
      expect(
        resolveDisplayName(displayName: null, email: 'wen@example.com'),
        'wen@example.com',
      );
    });

    test('falls back to email when displayName is an empty string (the actual Firebase bug)', () {
      // Firebase can return "" (not null) for displayName in some sign-in
      // flows. A naive `displayName ?? email ?? fallback` chain treats ""
      // as a valid value and doesn't fall through — this is exactly what
      // caused main.dart's `displayName[0]` to throw RangeError.
      expect(
        resolveDisplayName(displayName: '', email: 'wen@example.com'),
        'wen@example.com',
      );
    });

    test('falls back to 匿名用戶 when both displayName and email are null', () {
      expect(resolveDisplayName(displayName: null, email: null), '匿名用戶');
    });

    test('falls back to 匿名用戶 when both are empty strings', () {
      expect(resolveDisplayName(displayName: '', email: ''), '匿名用戶');
    });

    test('falls back to 匿名用戶 when displayName is empty and email is null', () {
      expect(resolveDisplayName(displayName: '', email: null), '匿名用戶');
    });
  });

  group('AuthProvider', () {
    late FakeAuthService fakeAuthService;
    late AuthProvider provider;

    setUp(() {
      fakeAuthService = FakeAuthService();
      provider = AuthProvider(authService: fakeAuthService);
    });

    tearDown(() {
      fakeAuthService.dispose();
    });

    test('initial state: not signed in, not loading, anonymous fallback display name', () {
      expect(provider.isSignedIn, isFalse);
      expect(provider.isLoading, isFalse);
      expect(provider.user, isNull);
      expect(provider.displayName, '匿名用戶');
      expect(provider.isAnonymous, isFalse);
    });

    test('signInWithGoogle delegates to AuthService and resets isLoading afterward', () async {
      final result = await provider.signInWithGoogle();

      expect(fakeAuthService.signInWithGoogleCallCount, 1);
      expect(result, isFalse, reason: 'fake returns null credential (simulated cancel)');
      expect(provider.isLoading, isFalse, reason: 'isLoading must reset even when sign-in yields no user');
    });

    test('signInWithGoogle returns false and resets isLoading when AuthService throws', () async {
      fakeAuthService.throwOnSignIn = true;

      final result = await provider.signInWithGoogle();

      expect(result, isFalse);
      expect(provider.isLoading, isFalse);
    });

    test('signInAnonymously delegates to AuthService', () async {
      final result = await provider.signInAnonymously();

      expect(fakeAuthService.signInAnonymouslyCallCount, 1);
      expect(result, isFalse);
      expect(provider.isLoading, isFalse);
    });

    test('signOut delegates to AuthService and clears user', () async {
      await provider.signOut();

      expect(fakeAuthService.signOutCallCount, 1);
      expect(provider.user, isNull);
      expect(provider.isLoading, isFalse);
    });

    test('signOut resets isLoading even when AuthService throws', () async {
      fakeAuthService.throwOnSignOut = true;

      await provider.signOut();

      expect(provider.isLoading, isFalse);
    });

    test('notifies listeners on sign-in and sign-out attempts', () async {
      var notifyCount = 0;
      provider.addListener(() => notifyCount++);

      await provider.signInAnonymously();
      await provider.signOut();

      expect(notifyCount, greaterThanOrEqualTo(2),
          reason: 'each call notifies at least once at start and once in finally');
    });
  });
}
