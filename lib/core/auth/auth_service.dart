import 'package:supabase_flutter/supabase_flutter.dart';

final class AuthSessionState {
  const AuthSessionState({
    required this.isConfigured,
    required this.isSignedIn,
    this.userId,
    this.email,
  });

  final bool isConfigured;
  final bool isSignedIn;
  final String? userId;
  final String? email;
}

abstract interface class AuthService {
  Stream<AuthSessionState> watchState();
  AuthSessionState get currentState;
  Future<void> signIn({required String email, required String password});
  Future<void> signUp({required String email, required String password});
  Future<void> signOut();
}

final class DisabledAuthService implements AuthService {
  const DisabledAuthService();

  static const AuthSessionState _state = AuthSessionState(
    isConfigured: false,
    isSignedIn: false,
  );

  @override
  AuthSessionState get currentState => _state;

  @override
  Stream<AuthSessionState> watchState() => Stream<AuthSessionState>.value(_state);

  @override
  Future<void> signIn({required String email, required String password}) {
    throw StateError('Cloud sync is not configured for this build.');
  }

  @override
  Future<void> signUp({required String email, required String password}) {
    throw StateError('Cloud sync is not configured for this build.');
  }

  @override
  Future<void> signOut() async {}
}

final class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this._client);

  final SupabaseClient _client;

  AuthSessionState _mapSession(Session? session) => AuthSessionState(
        isConfigured: true,
        isSignedIn: session != null,
        userId: session?.user.id,
        email: session?.user.email,
      );

  @override
  AuthSessionState get currentState => _mapSession(_client.auth.currentSession);

  @override
  Stream<AuthSessionState> watchState() async* {
    yield currentState;
    yield* _client.auth.onAuthStateChange.map((event) => _mapSession(event.session));
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    final String cleanEmail = email.trim();
    if (cleanEmail.isEmpty || password.isEmpty) {
      throw ArgumentError('Email and password are required.');
    }
    await _client.auth.signInWithPassword(email: cleanEmail, password: password);
  }

  @override
  Future<void> signUp({required String email, required String password}) async {
    final String cleanEmail = email.trim();
    if (cleanEmail.isEmpty || password.length < 8) {
      throw ArgumentError('A valid email and password of at least 8 characters are required.');
    }
    await _client.auth.signUp(email: cleanEmail, password: password);
  }

  @override
  Future<void> signOut() => _client.auth.signOut();
}
