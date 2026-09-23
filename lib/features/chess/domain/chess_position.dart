import 'chess_move.dart';
import 'chess_types.dart';

const String startingFen =
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// Immutable snapshot of a chess game: piece placement, whose turn it is,
/// castling rights, and the en-passant target square. [applyMove] returns a
/// new position rather than mutating in place, so the engine can freely
/// "try" a move (to test for check) without needing an undo stack.
class ChessPosition {
  ChessPosition({
    required this.board,
    required this.sideToMove,
    required this.whiteKingside,
    required this.whiteQueenside,
    required this.blackKingside,
    required this.blackQueenside,
    required this.enPassantTarget,
    required this.halfmoveClock,
    required this.fullmoveNumber,
  });

  /// board[rank][file], rank 0 = rank '1', file 0 = file 'a'.
  final List<List<ChessPiece?>> board;
  final PieceColor sideToMove;
  final bool whiteKingside;
  final bool whiteQueenside;
  final bool blackKingside;
  final bool blackQueenside;
  final Square? enPassantTarget;
  final int halfmoveClock;
  final int fullmoveNumber;

  factory ChessPosition.initial() => ChessPosition.fromFen(startingFen);

  ChessPiece? at(Square s) => s.isOnBoard ? board[s.rank][s.file] : null;

  factory ChessPosition.fromFen(String fen) {
    final parts = fen.trim().split(RegExp(r'\s+'));
    final placement = parts[0];
    final side = parts.length > 1 ? parts[1] : 'w';
    final castling = parts.length > 2 ? parts[2] : '-';
    final enPassant = parts.length > 3 ? parts[3] : '-';
    final halfmove = parts.length > 4 ? int.tryParse(parts[4]) ?? 0 : 0;
    final fullmove = parts.length > 5 ? int.tryParse(parts[5]) ?? 1 : 1;

    final board = List.generate(8, (_) => List<ChessPiece?>.filled(8, null));
    final ranks = placement.split('/');
    for (var fenRankIdx = 0; fenRankIdx < 8; fenRankIdx++) {
      final rank = 7 - fenRankIdx; // FEN goes rank 8 -> rank 1
      var file = 0;
      for (final ch in ranks[fenRankIdx].split('')) {
        final empties = int.tryParse(ch);
        if (empties != null) {
          file += empties;
        } else {
          final color = ch == ch.toUpperCase()
              ? PieceColor.white
              : PieceColor.black;
          board[rank][file] = ChessPiece(PieceType.fromLetter(ch), color);
          file++;
        }
      }
    }

    return ChessPosition(
      board: board,
      sideToMove: side == 'w' ? PieceColor.white : PieceColor.black,
      whiteKingside: castling.contains('K'),
      whiteQueenside: castling.contains('Q'),
      blackKingside: castling.contains('k'),
      blackQueenside: castling.contains('q'),
      enPassantTarget: enPassant == '-'
          ? null
          : Square.fromAlgebraic(enPassant),
      halfmoveClock: halfmove,
      fullmoveNumber: fullmove,
    );
  }

  String toFen() {
    final buffer = StringBuffer();
    for (var fenRankIdx = 0; fenRankIdx < 8; fenRankIdx++) {
      final rank = 7 - fenRankIdx;
      var empties = 0;
      for (var file = 0; file < 8; file++) {
        final piece = board[rank][file];
        if (piece == null) {
          empties++;
          continue;
        }
        if (empties > 0) {
          buffer.write(empties);
          empties = 0;
        }
        buffer.write(piece.fenChar);
      }
      if (empties > 0) buffer.write(empties);
      if (fenRankIdx != 7) buffer.write('/');
    }

    buffer.write(sideToMove == PieceColor.white ? ' w ' : ' b ');

    final castling = StringBuffer();
    if (whiteKingside) castling.write('K');
    if (whiteQueenside) castling.write('Q');
    if (blackKingside) castling.write('k');
    if (blackQueenside) castling.write('q');
    buffer.write(castling.isEmpty ? '-' : castling.toString());

    buffer.write(' ${enPassantTarget?.algebraic ?? '-'}');
    buffer.write(' $halfmoveClock $fullmoveNumber');
    return buffer.toString();
  }

  /// Applies a fully-resolved, already-legal [move] and returns the
  /// resulting position. Does not itself validate legality — that's
  /// [ChessEngine]'s job before this is ever called.
  ChessPosition applyMove(ChessMove move) {
    final newBoard = [
      for (final rank in board) [...rank],
    ];

    Square? newEnPassant;
    var newHalfmove = halfmoveClock + 1;

    newBoard[move.from.rank][move.from.file] = null;

    switch (move.flag) {
      case MoveFlag.enPassant:
        final capturedRank = move.piece.color == PieceColor.white
            ? move.to.rank - 1
            : move.to.rank + 1;
        newBoard[capturedRank][move.to.file] = null;
        newBoard[move.to.rank][move.to.file] = move.piece;
      case MoveFlag.promotion:
        newBoard[move.to.rank][move.to.file] = ChessPiece(
          move.promotion!,
          move.piece.color,
        );
      case MoveFlag.castleKingside:
        newBoard[move.to.rank][move.to.file] = move.piece;
        final rookFrom = Square(7, move.from.rank);
        final rookTo = Square(5, move.from.rank);
        newBoard[rookTo.rank][rookTo.file] =
            newBoard[rookFrom.rank][rookFrom.file];
        newBoard[rookFrom.rank][rookFrom.file] = null;
      case MoveFlag.castleQueenside:
        newBoard[move.to.rank][move.to.file] = move.piece;
        final rookFrom = Square(0, move.from.rank);
        final rookTo = Square(3, move.from.rank);
        newBoard[rookTo.rank][rookTo.file] =
            newBoard[rookFrom.rank][rookFrom.file];
        newBoard[rookFrom.rank][rookFrom.file] = null;
      case MoveFlag.doublePawnPush:
        newBoard[move.to.rank][move.to.file] = move.piece;
        newEnPassant = Square(
          move.from.file,
          (move.from.rank + move.to.rank) ~/ 2,
        );
      case MoveFlag.normal:
        newBoard[move.to.rank][move.to.file] = move.piece;
    }

    if (move.piece.type == PieceType.pawn || move.isCapture) {
      newHalfmove = 0;
    }

    var wk = whiteKingside,
        wq = whiteQueenside,
        bk = blackKingside,
        bq = blackQueenside;
    if (move.piece.type == PieceType.king) {
      if (move.piece.color == PieceColor.white) {
        wk = false;
        wq = false;
      } else {
        bk = false;
        bq = false;
      }
    }
    // Losing a rook (moved or captured) revokes that side's castling right.
    void revokeIfRook(Square s) {
      if (s == const Square(0, 0)) wq = false;
      if (s == const Square(7, 0)) wk = false;
      if (s == const Square(0, 7)) bq = false;
      if (s == const Square(7, 7)) bk = false;
    }

    revokeIfRook(move.from);
    revokeIfRook(move.to);

    return ChessPosition(
      board: newBoard,
      sideToMove: sideToMove.opponent,
      whiteKingside: wk,
      whiteQueenside: wq,
      blackKingside: bk,
      blackQueenside: bq,
      enPassantTarget: newEnPassant,
      halfmoveClock: newHalfmove,
      fullmoveNumber: sideToMove == PieceColor.black
          ? fullmoveNumber + 1
          : fullmoveNumber,
    );
  }
}
