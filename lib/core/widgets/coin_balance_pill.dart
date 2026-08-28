import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/coins/presentation/providers/coin_balance_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';

/// Pill-shaped coin balance display bound to live Supabase data. Renders
/// explicit loading/error states rather than silently showing a stale or
/// hardcoded number.
class CoinBalancePill extends ConsumerWidget {
  const CoinBalancePill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(coinBalanceProvider);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.accentSecondary.withValues(alpha: 0.4)),
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
            error: (_, _) => const Text(
              '—',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
