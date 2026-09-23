import 'package:supabase_flutter/supabase_flutter.dart';

/// Read access to other users' public profile fields (id, display_name,
/// username) — the columns `select any profile for search/matches` (see
/// the chess/social migration) exposes. Nothing here can write a balance;
/// mutation stays entirely in `set_username` and the coins/matches RPCs.
class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  static const _publicColumns = 'id, display_name, username';

  Future<Map<String, dynamic>?> fetchById(String id) {
    return _client
        .from('profiles')
        .select(_publicColumns)
        .eq('id', id)
        .maybeSingle();
  }

  Future<List<Map<String, dynamic>>> fetchByIds(List<String> ids) {
    if (ids.isEmpty) return Future.value(const []);
    return _client.from('profiles').select(_publicColumns).inFilter('id', ids);
  }

  /// Case-insensitive prefix/substring search by username, excluding [excludeId]
  /// (typically the caller, so you never see yourself in your own results).
  Future<List<Map<String, dynamic>>> searchByUsername(
    String query, {
    String? excludeId,
  }) async {
    if (query.trim().isEmpty) return const [];
    var builder = _client
        .from('profiles')
        .select(_publicColumns)
        .ilike('username', '%${query.trim()}%')
        .limit(25);
    final rows = await builder;
    final results = List<Map<String, dynamic>>.from(rows);
    if (excludeId != null) {
      results.removeWhere((row) => row['id'] == excludeId);
    }
    return results;
  }

  Future<void> setUsername(String username) {
    return _client.rpc('set_username', params: {'p_username': username});
  }
}
