import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Full-width primary action button, styled as a chunky "3D press" pill —
/// a bright fill sitting on a darker offset shadow of the same color
/// (like a real button standing off the page), which flattens down when
/// pressed for a satisfying tactile click. This is the signature button
/// style of games like Duolingo/Candy Crush, and reads as "fun game" far
/// more than a flat Material button does.
class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  /// Fill color. Defaults to the brand violet.
  final Color? color;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.isLoading;

  static const double _depth = 5;

  @override
  Widget build(BuildContext context) {
    final fill = widget.color ?? AppColors.accent;
    final shade = AppColors.depthShade(fill);

    return GestureDetector(
      onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
      onTap: widget.onPressed,
      child: AnimatedOpacity(
        opacity: _enabled ? 1.0 : 0.5,
        duration: const Duration(milliseconds: 150),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          margin: EdgeInsets.only(
            top: _pressed ? _depth : 0,
            bottom: _pressed ? 0 : _depth,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            boxShadow: _pressed
                ? null
                : [BoxShadow(color: shade, offset: const Offset(0, _depth))],
          ),
          child: Container(
            width: double.infinity,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(26),
            ),
            child: widget.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    widget.label,
                    style: AppTextStyles.body(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
