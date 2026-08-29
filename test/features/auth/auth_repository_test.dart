import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flameup/core/errors/failure.dart';
import 'package:flameup/features/auth/data/auth_repository.dart';
import 'package:flameup/features/auth/domain/auth_user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_mocks/google_sign_in_mocks.dart';
import 'package:mock_exceptions/mock_exceptions.dart';

void main() {
  group('email and password', () {
    test('sign up returns a permanent user carrying the display name',
        () async {
      final auth = MockFirebaseAuth();
      final repo = AuthRepository(auth: auth, google: MockGoogleSignIn());

      final result = await repo.signUpWithEmail(
        email: 'liya@example.com',
        password: 'berbere123',
        displayName: 'Liya Bekele',
      );

      final user = result.valueOrNull;
      expect(result.isOk, isTrue);
      expect(user!.isGuest, isFalse);
      expect(user.isPermanent, isTrue);
      expect(user.uid, isNotEmpty);
    });

    test('sign in succeeds for an existing account', () async {
      final auth = MockFirebaseAuth(
        mockUser: MockUser(
          uid: 'uid-1',
          email: 'liya@example.com',
          displayName: 'Liya',
        ),
      );
      final repo = AuthRepository(auth: auth, google: MockGoogleSignIn());

      final result = await repo.signInWithEmail(
        email: 'liya@example.com',
        password: 'berbere123',
      );

      expect(result.valueOrNull?.uid, 'uid-1');
    });

    test('a provider error becomes a Failure, never a raw exception', () async {
      final auth = MockFirebaseAuth();
      whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
          .on(auth)
          .thenThrow(FirebaseAuthException(code: 'wrong-password'));
      final repo = AuthRepository(auth: auth, google: MockGoogleSignIn());

      final result = await repo.signInWithEmail(
        email: 'liya@example.com',
        password: 'wrong',
      );

      expect(result.isErr, isTrue);
      final failure = result.failureOrNull!;
      expect(failure, isA<AuthFailure>());
      // The key is what the UI localises; the code never reaches a widget.
      expect(failure.messageKey, 'authErrorInvalidCredentials');
    });
  });

  group('guest mode', () {
    test('a guest is a real account with a uid', () async {
      final auth = MockFirebaseAuth();
      final repo = AuthRepository(auth: auth, google: MockGoogleSignIn());

      final result = await repo.signInAsGuest();
      final user = result.valueOrNull;

      expect(user, isNotNull);
      expect(
        user!.uid,
        isNotEmpty,
        reason: 'progress attaches to this uid, so it must be real',
      );
      expect(user.isGuest, isTrue);
      expect(user.isPermanent, isFalse);
    });
  });

  group('guest upgrade', () {
    test('links the credential onto the existing user, keeping its uid',
        () async {
      // The single most important behaviour in the auth feature. Upgrading
      // must call linkWithCredential on the *existing* anonymous user, which
      // converts it in place and keeps the uid. Signing out and creating a new
      // account instead would silently strand every document already written
      // under the guest's uid -- XP, cooking history, achievements, mastery,
      // saved recipes, family recipes.
      //
      // firebase_auth_mocks cannot model the anonymous -> permanent
      // transition (MockUserCredential asserts isAnonymous never changes), so
      // this uses a spy that records which path the repository took. The uid
      // guarantee itself is Firebase's, and is exercised end to end against
      // the emulator in the Phase 14 integration tests.
      final auth = _SpyAuth(uid: 'guest-uid-42');
      final repo = AuthRepository(auth: auth, google: MockGoogleSignIn());

      final result = await repo.upgradeGuest(
        method: SignInMethod.password,
        email: 'liya@example.com',
        password: 'berbere123',
        displayName: 'Liya Bekele',
      );

      expect(result.isOk, isTrue, reason: result.failureOrNull.toString());
      expect(
        auth.linkedCredentials,
        hasLength(1),
        reason: 'must link, not create a second account',
      );
      expect(auth.linkedCredentials.single.providerId, 'password');
      expect(
        auth.signOutCalls,
        isZero,
        reason: 'signing out would orphan the guest\'s data',
      );
      expect(
        auth.createdAccounts,
        isZero,
        reason: 'a new account would mean a new uid',
      );
      expect(result.valueOrNull!.uid, 'guest-uid-42');
    });

    test('refuses when nobody is signed in', () async {
      final auth = MockFirebaseAuth();
      final repo = AuthRepository(auth: auth, google: MockGoogleSignIn());

      final result = await repo.upgradeGuest(
        method: SignInMethod.password,
        email: 'liya@example.com',
        password: 'berbere123',
      );

      expect(result.isErr, isTrue);
      expect(result.failureOrNull!.messageKey, 'authErrorSignedOut');
    });

    test('refuses for an account that is already permanent', () async {
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'uid-1', email: 'liya@example.com'),
      );
      final repo = AuthRepository(auth: auth, google: MockGoogleSignIn());

      final result = await repo.upgradeGuest(
        method: SignInMethod.password,
        email: 'other@example.com',
        password: 'berbere123',
      );

      expect(result.isErr, isTrue);
      expect(
        result.failureOrNull!.messageKey,
        'authErrorProviderAlreadyLinked',
      );
    });

    test('rejects guest as an upgrade target', () async {
      final auth = MockFirebaseAuth();
      final repo = AuthRepository(auth: auth, google: MockGoogleSignIn());
      await repo.signInAsGuest();

      final result = await repo.upgradeGuest(method: SignInMethod.guest);

      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<ValidationFailure>());
    });
  });

  group('session', () {
    test('sign out clears the current user', () async {
      final auth = MockFirebaseAuth(signedIn: true);
      final repo = AuthRepository(auth: auth, google: MockGoogleSignIn());

      expect(repo.currentUser, isNotNull);
      await repo.signOut();
      expect(repo.currentUser, isNull);
    });

    test('authStateChanges emits sign-in and sign-out', () async {
      final auth = MockFirebaseAuth();
      final repo = AuthRepository(auth: auth, google: MockGoogleSignIn());

      final seen = <bool>[];
      final sub = repo.authStateChanges().listen((u) => seen.add(u != null));

      await repo.signInAsGuest();
      await Future<void>.delayed(Duration.zero);
      await repo.signOut();
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(seen, contains(true));
      expect(seen.last, isFalse);
    });
  });

  group('AuthUser', () {
    test('derives a short name from the display name', () {
      const user = AuthUser(
        uid: 'u1',
        isGuest: false,
        displayName: 'Liya Bekele',
        methods: [SignInMethod.password],
      );
      expect(user.shortName, 'Liya');
    });

    test('falls back to the email local part', () {
      const user = AuthUser(
        uid: 'u1',
        isGuest: false,
        email: 'liya@example.com',
        methods: [SignInMethod.password],
      );
      expect(user.shortName, 'liya');
    });

    test('a guest has no name to show', () {
      const user = AuthUser(uid: 'u1', isGuest: true, methods: []);
      expect(user.shortName, '');
    });

    test('maps provider ids to sign-in methods', () {
      expect(SignInMethod.fromProviderId('password'), SignInMethod.password);
      expect(SignInMethod.fromProviderId('google.com'), SignInMethod.google);
      expect(SignInMethod.fromProviderId('apple.com'), SignInMethod.apple);
      expect(SignInMethod.fromProviderId('anonymous'), SignInMethod.guest);
    });
  });
}

/// A spy standing in for an anonymous [FirebaseAuth] session.
///
/// Records which path an upgrade took. Only the members [AuthRepository]
/// touches are implemented; anything else throws loudly rather than silently
/// returning a wrong answer.
class _SpyAuth extends Fake implements FirebaseAuth {
  _SpyAuth({required String uid}) : _user = _SpyUser(uid: uid) {
    _user._auth = this;
  }

  final _SpyUser _user;

  final List<AuthCredential> linkedCredentials = [];
  int signOutCalls = 0;
  int createdAccounts = 0;

  @override
  User? get currentUser => _user;

  @override
  Future<void> signOut() async => signOutCalls++;

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    createdAccounts++;
    throw StateError('upgrade must link, not create a new account');
  }
}

class _SpyUser extends Fake implements User {
  _SpyUser({required this.uid});

  late final _SpyAuth _auth;

  @override
  final String uid;

  @override
  bool get isAnonymous => true;

  @override
  String? get email => 'liya@example.com';

  @override
  String? get displayName => 'Liya Bekele';

  @override
  String? get photoURL => null;

  @override
  bool get emailVerified => false;

  @override
  List<UserInfo> get providerData => const [];

  @override
  Future<UserCredential> linkWithCredential(AuthCredential credential) async {
    _auth.linkedCredentials.add(credential);
    return _SpyCredential(this);
  }

  @override
  Future<void> updateDisplayName(String? displayName) async {}

  @override
  Future<void> reload() async {}
}

class _SpyCredential extends Fake implements UserCredential {
  _SpyCredential(this._user);

  final User _user;

  @override
  User? get user => _user;
}
