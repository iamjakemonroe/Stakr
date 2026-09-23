import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum BuddyMood { idle, thinking, happy, sad }

/// "Chip" — the app's mascot: a small animated gold-coin character with a
/// face, drawn entirely in code (no image assets). Bobs gently, blinks
/// periodically, and changes expression/pose with [mood] — idle (content),
/// thinking (searching for a match), happy (won), sad (lost). Used on the
/// welcome screen, matchmaking search, and the game-over panel to give the
/// app a bit of personality instead of being just menus and a board.
class CoinBuddy extends StatefulWidget {
  const CoinBuddy({super.key, this.mood = BuddyMood.idle, this.size = 96});

  final BuddyMood mood;
  final double size;

  @override
  State<CoinBuddy> createState() => _CoinBuddyState();
}

class _CoinBuddyState extends State<CoinBuddy> with TickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 140),
  );
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
    value: 1,
  );
  Timer? _blinkTimer;

  @override
  void initState() {
    super.initState();
    _scheduleNextBlink();
  }

  void _scheduleNextBlink() {
    _blinkTimer = Timer(
      Duration(milliseconds: 2200 + math.Random().nextInt(2600)),
      () async {
        if (!mounted) return;
        await _blink.forward();
        if (!mounted) return;
        await _blink.reverse();
        _scheduleNextBlink();
      },
    );
  }

  @override
  void didUpdateWidget(covariant CoinBuddy oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood != widget.mood) {
      _pop.forward(from: 0.6);
    }
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _bob.dispose();
    _blink.dispose();
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_bob, _blink, _pop]),
      builder: (context, child) {
        final bobOffset = widget.mood == BuddyMood.sad
            ? 0.0
            : math.sin(_bob.value * math.pi) * (widget.size * 0.04);
        final popScale = Curves.elasticOut.transform(
          _pop.value.clamp(0.0, 1.0),
        );
        return Transform.translate(
          offset: Offset(0, -bobOffset),
          child: Transform.scale(
            scale: 0.85 + (popScale * 0.15),
            child: CustomPaint(
              size: Size.square(widget.size),
              painter: _CoinBuddyPainter(
                mood: widget.mood,
                eyeOpen: 1 - _blink.value,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CoinBuddyPainter extends CustomPainter {
  _CoinBuddyPainter({required this.mood, required this.eyeOpen});

  final BuddyMood mood;
  final double eyeOpen;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 * 0.86;

    _paintArms(canvas, center, r);
    _paintBody(canvas, center, r);
    _paintFace(canvas, center, r);
  }

  void _paintArms(Canvas canvas, Offset center, double r) {
    final paint = Paint()..color = AppColors.accentSecondary;
    final armUp = mood == BuddyMood.happy;
    final armDown = mood == BuddyMood.sad;
    final angle = armUp ? -0.9 : (armDown ? 0.35 : -0.15);

    for (final side in [-1.0, 1.0]) {
      canvas.save();
      final shoulder = center + Offset(side * r * 0.75, r * 0.15);
      canvas.translate(shoulder.dx, shoulder.dy);
      canvas.rotate(side * angle);
      final armRect = Rect.fromCenter(
        center: Offset(0, r * 0.42),
        width: r * 0.34,
        height: r * 0.8,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(armRect, Radius.circular(r * 0.18)),
        paint,
      );
      canvas.restore();
    }
  }

  void _paintBody(Canvas canvas, Offset center, double r) {
    final bodyPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.4),
        radius: 1.1,
        colors: [
          const Color(0xFFFFE79A),
          AppColors.accentSecondary,
          const Color(0xFFE08A00),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, bodyPaint);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.1
      ..color = const Color(0xFFE08A00).withValues(alpha: 0.55);
    canvas.drawCircle(center, r * 0.86, ringPaint);

    final outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.05
      ..color = AppColors.cardOutline.withValues(alpha: 0.25);
    canvas.drawCircle(center, r, outlinePaint);
  }

  void _paintFace(Canvas canvas, Offset center, double r) {
    final eyeDy = mood == BuddyMood.thinking ? -r * 0.08 : 0.0;
    final eyeCenterL = center + Offset(-r * 0.32, -r * 0.08 + eyeDy);
    final eyeCenterR = center + Offset(r * 0.32, -r * 0.08 + eyeDy);
    final eyeR = r * 0.16;

    // Blush cheeks, drawn first so they sit behind the eyes/mouth.
    final blushPaint = Paint()..color = AppColors.coral.withValues(alpha: 0.35);
    canvas.drawOval(
      Rect.fromCenter(
        center: center + Offset(-r * 0.55, r * 0.18),
        width: r * 0.32,
        height: r * 0.2,
      ),
      blushPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: center + Offset(r * 0.55, r * 0.18),
        width: r * 0.32,
        height: r * 0.2,
      ),
      blushPaint,
    );

    if (mood == BuddyMood.sad) {
      _paintSadEyes(canvas, eyeCenterL, eyeCenterR, eyeR);
    } else if (mood == BuddyMood.happy) {
      _paintHappyEyes(canvas, eyeCenterL, eyeCenterR, eyeR);
    } else {
      _paintNormalEyes(canvas, eyeCenterL, eyeCenterR, eyeR);
    }

    _paintMouth(canvas, center, r);
  }

  void _paintNormalEyes(Canvas canvas, Offset l, Offset r, double eyeR) {
    final whitePaint = Paint()..color = Colors.white;
    final pupilPaint = Paint()..color = AppColors.textPrimary;
    final openAmount = eyeOpen.clamp(0.05, 1.0);

    for (final eye in [l, r]) {
      final rect = Rect.fromCenter(
        center: eye,
        width: eyeR * 2,
        height: eyeR * 2 * openAmount,
      );
      canvas.drawOval(rect, whitePaint);
      if (openAmount > 0.3) {
        canvas.drawCircle(eye + const Offset(0.5, 0.5), eyeR * 0.5, pupilPaint);
      }
    }
  }

  void _paintHappyEyes(Canvas canvas, Offset l, Offset r, double eyeR) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = eyeR * 0.5
      ..strokeCap = StrokeCap.round
      ..color = AppColors.textPrimary;
    for (final eye in [l, r]) {
      final path = Path()
        ..addArc(
          Rect.fromCircle(center: eye, radius: eyeR),
          math.pi * 1.1,
          math.pi * 0.8,
        );
      canvas.drawPath(path, paint);
    }
  }

  void _paintSadEyes(Canvas canvas, Offset l, Offset r, double eyeR) {
    final whitePaint = Paint()..color = Colors.white;
    final pupilPaint = Paint()..color = AppColors.textPrimary;
    for (final eye in [l, r]) {
      canvas.drawOval(
        Rect.fromCenter(center: eye, width: eyeR * 1.7, height: eyeR * 1.7),
        whitePaint,
      );
      canvas.drawCircle(eye + Offset(0, eyeR * 0.25), eyeR * 0.45, pupilPaint);
    }
    // A single small teardrop under the right eye for extra charm.
    final tear = Paint()..color = AppColors.sky.withValues(alpha: 0.85);
    final tearPath = Path()
      ..moveTo(r.dx, r.dy + eyeR * 1.1)
      ..quadraticBezierTo(
        r.dx - eyeR * 0.35,
        r.dy + eyeR * 2.0,
        r.dx,
        r.dy + eyeR * 2.6,
      )
      ..quadraticBezierTo(
        r.dx + eyeR * 0.35,
        r.dy + eyeR * 2.0,
        r.dx,
        r.dy + eyeR * 1.1,
      );
    canvas.drawPath(tearPath, tear);
  }

  void _paintMouth(Canvas canvas, Offset center, double r) {
    final mouthCenter = center + Offset(0, r * 0.34);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.07
      ..strokeCap = StrokeCap.round
      ..color = AppColors.textPrimary;

    switch (mood) {
      case BuddyMood.happy:
        final fill = Paint()..color = AppColors.textPrimary;
        final path = Path()
          ..addArc(
            Rect.fromCenter(
              center: mouthCenter,
              width: r * 0.7,
              height: r * 0.5,
            ),
            0.15,
            math.pi - 0.3,
          );
        canvas.drawPath(
          path,
          fill
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.14
            ..strokeCap = StrokeCap.round,
        );
      case BuddyMood.sad:
        final path = Path()
          ..addArc(
            Rect.fromCenter(
              center: mouthCenter - Offset(0, r * 0.14),
              width: r * 0.5,
              height: r * 0.34,
            ),
            math.pi + 0.2,
            math.pi - 0.4,
          );
        canvas.drawPath(path, paint);
      case BuddyMood.thinking:
        canvas.drawCircle(
          mouthCenter,
          r * 0.08,
          Paint()..color = AppColors.textPrimary,
        );
      case BuddyMood.idle:
        final path = Path()
          ..addArc(
            Rect.fromCenter(
              center: mouthCenter,
              width: r * 0.5,
              height: r * 0.3,
            ),
            0.2,
            math.pi - 0.4,
          );
        canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CoinBuddyPainter oldDelegate) {
    return oldDelegate.mood != mood || oldDelegate.eyeOpen != eyeOpen;
  }
}
