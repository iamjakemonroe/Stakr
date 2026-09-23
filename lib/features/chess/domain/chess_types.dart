/// Core chess vocabulary shared by the engine, the repository, and the UI.
library;

enum PieceColor {
  white,
  black;

  PieceColor get opponent => this == white ? black : white;
}

enum PieceType {
  pawn,
  knight,
  bishop,
  rook,
  queen,
  king;

  /// FEN/SAN letter, uppercase (color-agnostic; callers lowercase for black).
  String get letter => switch (this) {
    PieceType.pawn => 'P',
    PieceType.knight => 'N',
    PieceType.bishop => 'B',
    PieceType.rook => 'R',
    PieceType.queen => 'Q',
    PieceType.king => 'K',
  };

  static PieceType fromLetter(String letter) => switch (letter.toUpperCase()) {
    'P' => PieceType.pawn,
    'N' => PieceType.knight,
    'B' => PieceType.bishop,
    'R' => PieceType.rook,
    'Q' => PieceType.queen,
    'K' => PieceType.king,
    _ => throw ArgumentError('Unknown piece letter: $letter'),
  };
}

class ChessPiece {
  const ChessPiece(this.type, this.color);

  final PieceType type;
  final PieceColor color;

  String get fenChar {
    final letter = type.letter;
    return color == PieceColor.white ? letter : letter.toLowerCase();
  }

  @override
  bool operator ==(Object other) =>
      other is ChessPiece && other.type == type && other.color == color;

  @override
  int get hashCode => Object.hash(type, color);

  @override
  String toString() => fenChar;
}

/// A board square as (file, rank) with file/rank both 0-7, file 0 = 'a',
/// rank 0 = the first rank ('1'). This is the opposite of screen/array row
/// order, which runs top (rank 8) to bottom (rank 1) — [ChessPosition]
/// handles that translation, so the rest of the engine only deals in
/// algebraic squares.
class Square {
  const Square(this.file, this.rank);

  final int file;
  final int rank;

  bool get isOnBoard => file >= 0 && file <= 7 && rank >= 0 && rank <= 7;

  /// Parses algebraic notation, e.g. "e4".
  factory Square.fromAlgebraic(String s) {
    final file = s.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = int.parse(s[1]) - 1;
    return Square(file, rank);
  }

  String get algebraic =>
      '${String.fromCharCode('a'.codeUnitAt(0) + file)}${rank + 1}';

  Square operator +(Square delta) =>
      Square(file + delta.file, rank + delta.rank);

  @override
  bool operator ==(Object other) =>
      other is Square && other.file == file && other.rank == rank;

  @override
  int get hashCode => Object.hash(file, rank);

  @override
  String toString() => algebraic;
}
