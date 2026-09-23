import 'package:supabase_flutter/supabase_flutter.dart';

/// All chess data access: realtime streams for a live match, and the RPC
/// calls that mutate matchmaking/invites/moves/settlement server-side (see
/// `supabase/migrations/20260922120000_chess_social_schema.sql`). Like
/// [CoinRepository], there is no client-side balance math here — every coin
/// movement happens inside a SECURITY DEFINER function.
class ChessRepository {
  ChessRepository(this._client);

  final SupabaseClient _client;

  /// Live-updating row for [matchId] — board FEN, status, players, result.
  Stream<Map<String, dynamic>?> watchMatch(String matchId) {
    return _client
        .from('matches')
        .stream(primaryKey: ['id'])
        .eq('id', matchId)
        .map((rows) => rows.isEmpty ? null : rows.first);
  }

  /// Live-updating move log for [matchId], oldest first.
  Stream<List<Map<String, dynamic>>> watchMoves(String matchId) {
    return _client
        .from('match_moves')
        .stream(primaryKey: ['id'])
        .eq('match_id', matchId)
        .order('ply');
  }

  /// Pending invites addressed to the current user (surfaced in the
  /// friends popup and as a home-screen banner).
  Stream<List<Map<String, dynamic>>> watchIncomingInvites(String userId) {
    return _client
        .from('match_invites')
        .stream(primaryKey: ['id'])
        .eq('to_user', userId)
        .order('created_at');
  }

  /// Invites the current user sent — watched so the sender's client can
  /// notice the moment the other person accepts (match_id gets set) and
  /// jump straight into the match without any polling on their end.
  Stream<List<Map<String, dynamic>>> watchOutgoingInvites(String userId) {
    return _client
        .from('match_invites')
        .stream(primaryKey: ['id'])
        .eq('from_user', userId)
        .order('created_at');
  }

  /// Joins the random-opponent queue at [stake]. Returns the new match id
  /// immediately if this call paired with someone already waiting;
  /// otherwise null, and the caller should watch [watchQueueMatch] for a
  /// pairing that happens later from the other side.
  Future<String?> joinMatchmakingQueue(int stake) async {
    final result = await _client.rpc(
      'join_matchmaking_queue',
      params: {'p_stake': stake},
    );
    return result as String?;
  }

  Future<void> leaveMatchmakingQueue() {
    return _client.rpc('leave_matchmaking_queue');
  }

  /// While queued, a match can be created by the *other* player's call to
  /// [joinMatchmakingQueue]. This watches for that: any active match where
  /// we're a player and it didn't exist a moment ago is picked up by the
  /// caller polling/subscribing to this alongside the queue row.
  Stream<List<Map<String, dynamic>>> watchQueueRow(String userId) {
    return _client
        .from('matchmaking_queue')
        .stream(primaryKey: ['user_id'])
        .eq('user_id', userId);
  }

  /// Matches where the user is a player, newest first — used to detect a
  /// queue pairing landing (status flips to active) and to build the
  /// "recents" opponent list for the friends popup.
  Stream<List<Map<String, dynamic>>> watchMyMatches(String userId) {
    return _client
        .from('matches')
        .stream(primaryKey: ['id'])
        .order('created_at');
    // Filtering to player_white == userId OR player_black == userId isn't
    // expressible in a single postgrest .eq() stream filter; RLS already
    // restricts rows to matches the user is in, so no extra filter is
    // needed for correctness — this just returns "my matches" by construction.
  }

  Future<String?> sendMatchInvite({
    required String toUserId,
    required int stake,
  }) async {
    final result = await _client.rpc(
      'send_match_invite',
      params: {'p_to_user': toUserId, 'p_stake': stake},
    );
    return result as String?;
  }

  Future<String?> respondMatchInvite({
    required String inviteId,
    required bool accept,
  }) async {
    final result = await _client.rpc(
      'respond_match_invite',
      params: {'p_invite_id': inviteId, 'p_accept': accept},
    );
    return result as String?;
  }

  Future<void> recordMove({
    required String matchId,
    required String from,
    required String to,
    String? promotion,
    required String san,
    required String fenAfter,
  }) {
    return _client.rpc(
      'record_move',
      params: {
        'p_match_id': matchId,
        'p_from': from,
        'p_to': to,
        'p_promotion': promotion,
        'p_san': san,
        'p_fen_after': fenAfter,
      },
    );
  }

  Future<void> reportMatchResult({
    required String matchId,
    String? winnerId,
    required String result,
  }) {
    return _client.rpc(
      'report_match_result',
      params: {
        'p_match_id': matchId,
        'p_winner_id': winnerId,
        'p_result': result,
      },
    );
  }

  Future<void> resignMatch(String matchId) {
    return _client.rpc('resign_match', params: {'p_match_id': matchId});
  }
}
