import 'chess_types.dart';

enum MoveFlag {
  normal,
  doublePawnPush,
  enPassant,
  castleKingside,
  castleQueenside,
  promotion,
}

/// A single legal move, already fully resolved (no ambiguity) — this is
/// what [ChessEngine.legalMoves] returns and what gets persisted to
/// `match_moves`.
class ChessMove {
  const ChessMove({
    required this.from,
    required this.to,
    required this.piece,
    this.captured,
    this.promotion,
    this.flag = MoveFlag.normal,
  });

  final Square from;
  final Square to;
  final ChessPiece piece;
  final ChessPiece? captured;
  final PieceType? promotion;
  final MoveFlag flag;

  bool get isCapture => captured != null || flag == MoveFlag.enPassant;
  bool get isCastle =>
      flag == MoveFlag.castleKingside || flag == MoveFlag.castleQueenside;

  @override
  String toString() =>
      '${from.algebraic}${to.algebraic}${promotion?.letter.toLowerCase() ?? ''}';
}
