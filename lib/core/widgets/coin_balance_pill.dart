import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/coins/presentation/providers/coin_balance_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';
import 'pop_card.dart';

/// Pill-shaped coin balance display bound to live Supabase data. Renders
/// explicit loading/error states rather than silently showing a stale or
/// hardcoded number. Styled as a small gold-tinted glass bubble.
class CoinBalancePill extends ConsumerWidget {
  const CoinBalancePill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(coinBalanceProvider);

    return PopCard(
      borderRadius: 999,
      blur: 12,
      tint: AppColors.accentSecondary,
      glow: AppColors.accentSecondary,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.monetization_on_rounded,
            color: AppColors.accentSecondary,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.xs),
          balance.when(
            data: (value) => Text(
              value.toString(),
              style: AppTextStyles.body(fontWeight: FontWeight.w700),
            ),
            loading: () => const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accentSecondary,
              ),
            ),
            error: (_, _) =>
                const Text('—', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
