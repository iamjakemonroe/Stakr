/// Reads build-time config injected via `--dart-define-from-file=env/local.json`.
///
/// The publishable key (formerly "anon key") is safe to ship in the client
/// (it's protected by Postgres RLS) — this is why we use dart-define instead
/// of bundling a secrets-shaped asset file. The secret/service role key must
/// NEVER be read here; it only ever lives server-side (Supabase CLI / Edge
/// Function runtime env).
class Env {
  Env._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  /// Fails fast at startup instead of surfacing a confusing Supabase client
  /// error later if the app was built without `--dart-define-from-file`.
  static void assertConfigured() {
    if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
      throw StateError(
        'Missing Supabase config. Run with:\n'
        '  flutter run --dart-define-from-file=env/local.json\n'
        'See env/local.example.json for the expected keys.',
      );
    }
  }
}
