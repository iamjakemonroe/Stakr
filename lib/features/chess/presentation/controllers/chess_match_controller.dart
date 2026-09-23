import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/chess_repository.dart';
import '../../domain/chess_engine.dart';
import '../../domain/chess_move.dart';
import '../../domain/chess_position.dart';
import '../../domain/chess_types.dart';

final chessRepositoryProvider = Provider<ChessRepository>((ref) {
  return ChessRepository(ref.watch(supabaseClientProvider));
});

/// Invites addressed to the current user, for the home-screen "you've been
/// challenged" banner.
final incomingInvitesProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, userId) {
      return ref.watch(chessRepositoryProvider).watchIncomingInvites(userId);
    });

/// Invites the current user sent, watched so the sender's client can jump
/// straight into the match the moment the other side accepts.
final outgoingInvitesProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, userId) {
      return ref.watch(chessRepositoryProvider).watchOutgoingInvites(userId);
    });

const chessEngine = ChessEngine();

class ChessMatchState {
  const ChessMatchState({
    required this.position,
    this.matchRow,
    this.myColor,
    this.selectedSquare,
    this.legalDestinations = const [],
    this.lastMove,
    this.pendingPromotion,
    this.loading = true,
    this.error,
  });

  final ChessPosition position;
  final Map<String, dynamic>? matchRow;
  final PieceColor? myColor;
  final Square? selectedSquare;
  final List<ChessMove> legalDestinations;
  final ChessMove? lastMove;
  final ChessMove? pendingPromotion;
  final bool loading;
  final String? error;

  String get status => matchRow?['status'] as String? ?? 'pending';
  int get stake => (matchRow?['stake'] as num?)?.toInt() ?? 0;
  String? get winnerId => matchRow?['winner_id'] as String?;
  String? get result => matchRow?['result'] as String?;
  bool get isMyTurn =>
      myColor != null && myColor == position.sideToMove && status == 'active';
  GameStatus get gameStatus => chessEngine.status(position);

  ChessMatchState copyWith({
    ChessPosition? position,
    Map<String, dynamic>? matchRow,
    PieceColor? myColor,
    Square? selectedSquare,
    bool clearSelectedSquare = false,
    List<ChessMove>? legalDestinations,
    ChessMove? lastMove,
    ChessMove? pendingPromotion,
    bool clearPendingPromotion = false,
    bool? loading,
    String? error,
  }) {
    return ChessMatchState(
      position: position ?? this.position,
      matchRow: matchRow ?? this.matchRow,
      myColor: myColor ?? this.myColor,
      selectedSquare: clearSelectedSquare
          ? null
          : (selectedSquare ?? this.selectedSquare),
      legalDestinations: legalDestinations ?? this.legalDestinations,
      lastMove: lastMove ?? this.lastMove,
      pendingPromotion: clearPendingPromotion
          ? null
          : (pendingPromotion ?? this.pendingPromotion),
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

/// Drives a single live chess match: merges the `matches` row stream (the
/// authoritative board) with the `match_moves` stream (for animating the
/// most recent move), holds local-only selection/promotion UI state, and
/// submits moves through [ChessRepository]. Because `board_fen` is
/// server-authoritative, this never trusts its own optimistic position
/// past the next realtime event — see `_applyMatchRow`.
class ChessMatchController extends StateNotifier<ChessMatchState> {
  ChessMatchController(this._repository, this._matchId, this._myUserId)
    : super(ChessMatchState(position: ChessPosition.initial())) {
    _matchSub = _repository.watchMatch(_matchId).listen(_onMatchRow);
    _movesSub = _repository.watchMoves(_matchId).listen(_onMoves);
  }

  final ChessRepository _repository;
  final String _matchId;
  final String _myUserId;

  StreamSubscription<Map<String, dynamic>?>? _matchSub;
  StreamSubscription<List<Map<String, dynamic>>>? _movesSub;
  bool _hasReportedTermination = false;
  int _lastSeenPly = 0;

  void _onMatchRow(Map<String, dynamic>? row) {
    if (row == null) {
      state = state.copyWith(loading: false, error: 'Match not found');
      return;
    }

    final position = ChessPosition.fromFen(row['board_fen'] as String);
    final myColor = row['player_white'] == _myUserId
        ? PieceColor.white
        : (row['player_black'] == _myUserId ? PieceColor.black : null);

    state = state.copyWith(
      position: position,
      matchRow: row,
      myColor: myColor,
      loading: false,
      clearSelectedSquare: true,
      legalDestinations: const [],
    );

    if (row['status'] == 'active') {
      _maybeReportTermination(position, row);
    }
  }

  void _onMoves(List<Map<String, dynamic>> moves) {
    if (moves.isEmpty) return;
    final latest = moves.last;
    final ply = (latest['ply'] as num).toInt();
    if (ply <= _lastSeenPly) return;
    _lastSeenPly = ply;

    final from = Square.fromAlgebraic(latest['from_square'] as String);
    final to = Square.fromAlgebraic(latest['to_square'] as String);
    // The piece now sitting on `to` in the current position is exactly the
    // piece this move placed there (promotions included), so we can
    // reconstruct just enough of the move for animation purposes without
    // re-deriving full move metadata from SAN.
    final movedPiece = state.position.at(to);
    if (movedPiece == null) return;

    state = state.copyWith(
      lastMove: ChessMove(from: from, to: to, piece: movedPiece),
    );
  }

  void _maybeReportTermination(
    ChessPosition position,
    Map<String, dynamic> row,
  ) {
    final gameStatus = chessEngine.status(position);
    if (gameStatus != GameStatus.checkmate &&
        gameStatus != GameStatus.stalemate &&
        gameStatus != GameStatus.draw) {
      _hasReportedTermination = false;
      return;
    }
    if (_hasReportedTermination) return;
    _hasReportedTermination = true;

    String? winnerId;
    String result;
    if (gameStatus == GameStatus.checkmate) {
      // The side to move is the side in checkmate, i.e. the loser.
      final winnerColor = position.sideToMove.opponent;
      winnerId = winnerColor == PieceColor.white
          ? row['player_white'] as String?
          : row['player_black'] as String?;
      result = 'checkmate';
    } else {
      result = gameStatus == GameStatus.stalemate ? 'stalemate' : 'draw';
    }

    _repository.reportMatchResult(
      matchId: _matchId,
      winnerId: winnerId,
      result: result,
    );
  }

  void selectSquare(Square square) {
    if (!state.isMyTurn || state.pendingPromotion != null) return;

    final piece = state.position.at(square);

    if (state.selectedSquare == null) {
      if (piece == null || piece.color != state.myColor) return;
      final legal = chessEngine
          .legalMoves(state.position)
          .where((m) => m.from == square)
          .toList();
      state = state.copyWith(selectedSquare: square, legalDestinations: legal);
      return;
    }

    if (square == state.selectedSquare) {
      state = state.copyWith(
        clearSelectedSquare: true,
        legalDestinations: const [],
      );
      return;
    }

    final candidate = state.legalDestinations
        .where((m) => m.to == square)
        .toList();
    if (candidate.isEmpty) {
      // Tapped a different square of our own — reselect instead of no-op.
      if (piece != null && piece.color == state.myColor) {
        final legal = chessEngine
            .legalMoves(state.position)
            .where((m) => m.from == square)
            .toList();
        state = state.copyWith(
          selectedSquare: square,
          legalDestinations: legal,
        );
      } else {
        state = state.copyWith(
          clearSelectedSquare: true,
          legalDestinations: const [],
        );
      }
      return;
    }

    if (candidate.length > 1) {
      // All candidates share from/to and differ only by promotion choice.
      state = state.copyWith(
        pendingPromotion: candidate.first,
        clearSelectedSquare: true,
        legalDestinations: const [],
      );
      return;
    }

    _commitMove(candidate.first);
  }

  void choosePromotion(PieceType type) {
    final pending = state.pendingPromotion;
    if (pending == null) return;
    _commitMove(
      ChessMove(
        from: pending.from,
        to: pending.to,
        piece: pending.piece,
        captured: pending.captured,
        promotion: type,
        flag: MoveFlag.promotion,
      ),
    );
  }

  void _commitMove(ChessMove move) {
    final beforePosition = state.position;
    final san = chessEngine.toSan(beforePosition, move);
    final afterPosition = beforePosition.applyMove(move);

    // Optimistic local update for a snappy feel; _onMatchRow will overwrite
    // this with the server-confirmed position moments later (or, on
    // failure, effectively revert it since the server row never moved).
    state = state.copyWith(
      position: afterPosition,
      clearSelectedSquare: true,
      legalDestinations: const [],
      clearPendingPromotion: true,
      lastMove: move,
    );

    _repository
        .recordMove(
          matchId: _matchId,
          from: move.from.algebraic,
          to: move.to.algebraic,
          promotion: move.promotion?.letter.toLowerCase(),
          san: san,
          fenAfter: afterPosition.toFen(),
        )
        .catchError((_) {
          state = state.copyWith(error: 'Move failed to sync — reconnecting.');
        });
  }

  void cancelPromotion() {
    state = state.copyWith(clearPendingPromotion: true);
  }

  Future<void> resign() => _repository.resignMatch(_matchId);

  @override
  void dispose() {
    _matchSub?.cancel();
    _movesSub?.cancel();
    super.dispose();
  }
}

final chessMatchControllerProvider =
    StateNotifierProvider.family<ChessMatchController, ChessMatchState, String>(
      (ref, matchId) {
        final repository = ref.watch(chessRepositoryProvider);
        final userId = ref.watch(currentUserProvider)?.id ?? '';
        return ChessMatchController(repository, matchId, userId);
      },
    );
