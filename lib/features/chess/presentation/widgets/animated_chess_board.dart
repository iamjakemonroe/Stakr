import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/chess_engine.dart';
import '../../domain/chess_move.dart';
import '../../domain/chess_position.dart';
import '../../domain/chess_types.dart';
import 'piece_glyph.dart';

const ChessEngine _engine = ChessEngine();

// Light lavender / vivid violet pair — matches the app's bright palette
// instead of the earlier dark theme's near-black squares, while keeping
// enough contrast for both piece colors to read clearly on either square.
const Color _lightSquare = Color(0xFFF6F0FF);
const Color _darkSquare = Color(0xFFB69CFF);
const Color _selectedGlow = Color(0xFF7C4DFF);
const Color _lastMoveGlow = Color(0xFFFFB300);
const Color _checkGlow = Color(0xFFFF5A5F);

/// The animated 8x8 board: static piece layer, move/selection highlights,
/// and a "flying piece" overlay that tweens position+scale for the most
/// recent move instead of pieces just teleporting to their new square.
///
/// Orientation follows [myColor] — a black player sees their own back rank
/// at the bottom, mirroring both axes, the same way physical boards are
/// turned around.
class AnimatedChessBoard extends StatefulWidget {
  const AnimatedChessBoard({
    super.key,
    required this.position,
    required this.lastMove,
    required this.legalDestinations,
    required this.selectedSquare,
    required this.myColor,
    required this.interactive,
    required this.onSquareTap,
  });

  final ChessPosition position;
  final ChessMove? lastMove;
  final List<ChessMove> legalDestinations;
  final Square? selectedSquare;
  final PieceColor? myColor;
  final bool interactive;
  final ValueChanged<Square> onSquareTap;

  @override
  State<AnimatedChessBoard> createState() => _AnimatedChessBoardState();
}

class _AnimatedChessBoardState extends State<AnimatedChessBoard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _moveController;
  ChessPosition? _priorPosition;
  ChessMove? _animatingMove;

  bool get _flipped => widget.myColor == PieceColor.black;

  @override
  void initState() {
    super.initState();
    _moveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
  }

  @override
  void didUpdateWidget(covariant AnimatedChessBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lastMove != null &&
        !identical(widget.lastMove, oldWidget.lastMove)) {
      _priorPosition = oldWidget.position;
      _animatingMove = widget.lastMove;
      _moveController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _moveController.dispose();
    super.dispose();
  }

  int _screenRow(int rank) => _flipped ? rank : 7 - rank;
  int _screenCol(int file) => _flipped ? 7 - file : file;

  Offset _squareOffset(Square s, double size) =>
      Offset(_screenCol(s.file) * size, _screenRow(s.rank) * size);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        final squareSize = size / 8;
        final kingInCheckSquare = _kingInCheckSquare();

        return SizedBox(
          width: size,
          height: size,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                _boardSquares(squareSize),
                _highlights(squareSize, kingInCheckSquare),
                _staticPieces(squareSize),
                if (_animatingMove != null) _capturedPieceFade(squareSize),
                if (_animatingMove != null) _flyingPiece(squareSize),
                _tapTargets(squareSize),
              ],
            ),
          ),
        );
      },
    );
  }

  Square? _kingInCheckSquare() {
    final color = widget.position.sideToMove;
    if (!_engine.isInCheck(widget.position, color)) return null;
    for (var rank = 0; rank < 8; rank++) {
      for (var file = 0; file < 8; file++) {
        final piece = widget.position.board[rank][file];
        if (piece != null &&
            piece.type == PieceType.king &&
            piece.color == color) {
          return Square(file, rank);
        }
      }
    }
    return null;
  }

  Widget _boardSquares(double squareSize) {
    return Column(
      children: List.generate(8, (screenRow) {
        return Row(
          children: List.generate(8, (screenCol) {
            final isLight = (screenRow + screenCol) % 2 == 0;
            return Container(
              width: squareSize,
              height: squareSize,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isLight
                      ? [_lightSquare, _lightSquare.withValues(alpha: 0.85)]
                      : [_darkSquare, _darkSquare.withValues(alpha: 0.95)],
                ),
              ),
            );
          }),
        );
      }),
    );
  }

  Widget _highlights(double squareSize, Square? kingInCheckSquare) {
    final children = <Widget>[];

    void glow(Square s, Color color, {double opacity = 0.55}) {
      final offset = _squareOffset(s, squareSize);
      children.add(
        Positioned(
          left: offset.dx,
          top: offset.dy,
          width: squareSize,
          height: squareSize,
          child: DecoratedBox(
            decoration: BoxDecoration(color: color.withValues(alpha: opacity)),
          ),
        ),
      );
    }

    final lastMove = widget.lastMove;
    if (lastMove != null) {
      glow(lastMove.from, _lastMoveGlow, opacity: 0.22);
      glow(lastMove.to, _lastMoveGlow, opacity: 0.22);
    }

    if (widget.selectedSquare != null) {
      glow(widget.selectedSquare!, _selectedGlow, opacity: 0.45);
    }

    if (kingInCheckSquare != null) {
      children.add(
        _PulsingCheckRing(
          square: kingInCheckSquare,
          squareSize: squareSize,
          offset: _squareOffset(kingInCheckSquare, squareSize),
        ),
      );
    }

    for (final move in widget.legalDestinations) {
      final offset = _squareOffset(move.to, squareSize);
      final isCapture = move.isCapture;
      children.add(
        Positioned(
          left: offset.dx,
          top: offset.dy,
          width: squareSize,
          height: squareSize,
          child: Center(
            child: isCapture
                ? Container(
                    width: squareSize * 0.82,
                    height: squareSize * 0.82,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.accentSecondary.withValues(
                          alpha: 0.85,
                        ),
                        width: 3,
                      ),
                    ),
                  )
                : Container(
                    width: squareSize * 0.28,
                    height: squareSize * 0.28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accentSecondary.withValues(alpha: 0.75),
                    ),
                  ),
          ),
        ),
      );
    }

    return Stack(children: children);
  }

  Widget _staticPieces(double squareSize) {
    final children = <Widget>[];
    for (var rank = 0; rank < 8; rank++) {
      for (var file = 0; file < 8; file++) {
        final square = Square(file, rank);
        if (_animatingMove != null && square == _animatingMove!.to) continue;
        final piece = widget.position.board[rank][file];
        if (piece == null) continue;
        final offset = _squareOffset(square, squareSize);
        children.add(
          Positioned(
            left: offset.dx,
            top: offset.dy,
            width: squareSize,
            height: squareSize,
            child: _PieceGlyph(
              type: piece.type,
              color: piece.color,
              size: squareSize,
            ),
          ),
        );
      }
    }
    return Stack(children: children);
  }

  Widget _capturedPieceFade(double squareSize) {
    final move = _animatingMove!;
    final priorPiece = _priorPosition?.at(move.to);
    if (priorPiece == null || priorPiece.color == move.piece.color)
      return const SizedBox.shrink();

    final offset = _squareOffset(move.to, squareSize);
    return AnimatedBuilder(
      animation: _moveController,
      builder: (context, child) {
        final t = _moveController.value.clamp(0.0, 1.0);
        return Positioned(
          left: offset.dx,
          top: offset.dy,
          width: squareSize,
          height: squareSize,
          child: Opacity(
            opacity: (1 - t).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 1 - (t * 0.5),
              child: _PieceGlyph(
                type: priorPiece.type,
                color: priorPiece.color,
                size: squareSize,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _flyingPiece(double squareSize) {
    final move = _animatingMove!;
    final start = _squareOffset(move.from, squareSize);
    final end = _squareOffset(move.to, squareSize);
    final curved = CurvedAnimation(
      parent: _moveController,
      curve: Curves.easeOutCubic,
    );

    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) {
        final t = curved.value;
        final pos = Offset.lerp(start, end, t)!;
        // Scale pulses up mid-flight and settles back down on landing —
        // reads as a little "hop" rather than a flat slide.
        final scale = 1.0 + (math.sin(t * math.pi) * 0.18);
        return Positioned(
          left: pos.dx,
          top: pos.dy,
          width: squareSize,
          height: squareSize,
          child: Transform.scale(
            scale: scale,
            child: _PieceGlyph(
              type: move.piece.type,
              color: move.piece.color,
              size: squareSize,
              glowing: true,
            ),
          ),
        );
      },
    );
  }

  Widget _tapTargets(double squareSize) {
    final children = <Widget>[];
    for (var rank = 0; rank < 8; rank++) {
      for (var file = 0; file < 8; file++) {
        final square = Square(file, rank);
        final offset = _squareOffset(square, squareSize);
        children.add(
          Positioned(
            left: offset.dx,
            top: offset.dy,
            width: squareSize,
            height: squareSize,
            child: widget.interactive
                ? GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => widget.onSquareTap(square),
                  )
                : const SizedBox.shrink(),
          ),
        );
      }
    }
    return Stack(children: children);
  }
}

class _PieceGlyph extends StatelessWidget {
  const _PieceGlyph({
    required this.type,
    required this.color,
    required this.size,
    this.glowing = false,
  });

  final PieceType type;
  final PieceColor color;
  final double size;
  final bool glowing;

  @override
  Widget build(BuildContext context) {
    final isWhite = color == PieceColor.white;
    return Center(
      child: Text(
        pieceGlyph(type),
        style: TextStyle(
          fontSize: size * 0.72,
          height: 1,
          color: isWhite ? Colors.white : AppColors.textPrimary,
          shadows: [
            if (isWhite)
              Shadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 3,
                offset: const Offset(0, 1),
              )
            else
              Shadow(
                color: AppColors.accentSecondary.withValues(alpha: 0.9),
                blurRadius: 1.5,
                offset: Offset.zero,
              ),
            if (glowing)
              Shadow(
                color: AppColors.accent.withValues(alpha: 0.9),
                blurRadius: 18,
              ),
          ],
        ),
      ),
    );
  }
}

class _PulsingCheckRing extends StatefulWidget {
  const _PulsingCheckRing({
    required this.square,
    required this.squareSize,
    required this.offset,
  });

  final Square square;
  final double squareSize;
  final Offset offset;

  @override
  State<_PulsingCheckRing> createState() => _PulsingCheckRingState();
}

class _PulsingCheckRingState extends State<_PulsingCheckRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.offset.dx,
      top: widget.offset.dy,
      width: widget.squareSize,
      height: widget.squareSize,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  _checkGlow.withValues(
                    alpha: 0.15 + (_controller.value * 0.35),
                  ),
                  _checkGlow.withValues(alpha: 0.0),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
