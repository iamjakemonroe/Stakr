import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads the caller's coin balance. This is READ-ONLY by design — there is no
/// method here to mutate a balance. All balance changes happen server-side
/// (Postgres trigger on signup, and later Edge Functions for stakes/payouts/
/// purchases), enforced by RLS that blocks client writes entirely.
class CoinRepository {
  CoinRepository(this._client);

  final SupabaseClient _client;

  /// Live-updating stream of the current balance for [userId], backed by
  /// Supabase Realtime on the `profiles` table.
  Stream<int> watchBalance(String userId) {
    return _client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map(
          (rows) => rows.isEmpty ? 0 : (rows.first['balance'] as num).toInt(),
        );
  }
}
