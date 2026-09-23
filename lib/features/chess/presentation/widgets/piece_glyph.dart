import '../../domain/chess_types.dart';

/// Unicode chess glyphs. Using the outline (white) glyph set for both
/// colors and tinting via [ChessPiece.color] elsewhere keeps a single
/// consistent line weight instead of mixing Unicode's filled black-piece
/// glyphs (which render heavier) with the outline white-piece glyphs.
String pieceGlyph(PieceType type) => switch (type) {
  PieceType.king => '♔',
  PieceType.queen => '♕',
  PieceType.rook => '♖',
  PieceType.bishop => '♗',
  PieceType.knight => '♘',
  PieceType.pawn => '♙',
};
