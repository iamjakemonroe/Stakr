import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper around Supabase auth calls used by this app.
///
/// Account upgrade (anonymous -> permanent) is email-only for Step 1; phone
/// auth is deferred since it requires a paid SMS provider to be configured
/// in the Supabase dashboard first.
///
/// Two distinct email flows exist and must not be conflated:
///  - "Log in or sign up" from a signed-out state uses [signInWithEmailOtp] /
///    [verifySignInOtp] (`OtpType.email`) — this may sign into an existing
///    account or create a new one.
///  - "Save your account" from an active anonymous session uses [linkEmail] /
///    [verifyLinkOtp] (`OtpType.emailChange`) — this attaches the email to the
///    *current* `auth.users.id` via Supabase's anonymous-linking flow, which
///    is what carries the coin balance over instead of losing it.
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Session? get currentSession => _client.auth.currentSession;

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Future<void> signInAnonymously() {
    return _client.auth.signInAnonymously();
  }

  /// Sends a one-time code to sign in (existing account) or sign up (new
  /// account) with [email]. Only valid when there is no anonymous session to
  /// preserve.
  Future<void> signInWithEmailOtp(String email) {
    return _client.auth.signInWithOtp(email: email);
  }

  Future<void> verifySignInOtp({required String email, required String token}) {
    return _client.auth.verifyOTP(
      type: OtpType.email,
      email: email,
      token: token,
    );
  }

  /// Attaches [email] to the current (anonymous) session, sending a one-time
  /// code to confirm. Requires an active session.
  Future<void> linkEmail(String email) {
    return _client.auth.updateUser(UserAttributes(email: email));
  }

  Future<void> verifyLinkOtp({required String email, required String token}) {
    return _client.auth.verifyOTP(
      type: OtpType.emailChange,
      email: email,
      token: token,
    );
  }

  Future<void> signOut() {
    return _client.auth.signOut();
  }
}
