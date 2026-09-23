import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/pop_card.dart';
import '../../../../core/widgets/primary_button.dart';

const List<int> _stakePresets = [25, 50, 100, 250, 500];

/// Bottom sheet for picking how many coins to put up before an invite goes
/// out. Returns the chosen stake, or null if the user backed out.
Future<int?> showInviteStakeSheet(
  BuildContext context, {
  required String opponentName,
}) {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: PopCard(
        borderRadius: 28,
        blur: 20,
        glow: AppColors.accent,
        child: _InviteStakeSheet(opponentName: opponentName),
      ),
    ),
  );
}

class _InviteStakeSheet extends StatefulWidget {
  const _InviteStakeSheet({required this.opponentName});

  final String opponentName;

  @override
  State<_InviteStakeSheet> createState() => _InviteStakeSheetState();
}

class _InviteStakeSheetState extends State<_InviteStakeSheet> {
  int _selected = _stakePresets[1];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Challenge ${widget.opponentName}',
              style: AppTextStyles.display(fontSize: 20),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Pick a stake — winner takes the pot.',
              style: AppTextStyles.body(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: _stakePresets.map((amount) {
                final selected = amount == _selected;
                return ChoiceChip(
                  label: Text('$amount'),
                  selected: selected,
                  onSelected: (_) => setState(() => _selected = amount),
                  selectedColor: AppColors.accent,
                  backgroundColor: AppColors.surface,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  side: BorderSide(
                    color: selected
                        ? AppColors.accent
                        : AppColors.textSecondary.withValues(alpha: 0.3),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Send challenge · $_selected coins',
              onPressed: () => Navigator.of(context).pop(_selected),
            ),
          ],
        ),
      ),
    );
  }
}
