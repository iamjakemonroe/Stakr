import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/coin_balance_pill.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// Lobby placeholder. Games land here in later steps; for Step 1 this proves
/// out live balance data and the guest-upgrade prompt.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAnonymous = ref.watch(isAnonymousProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stakr'),
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: AppSpacing.md),
            child: CoinBalancePill(),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isAnonymous) ...[
                _SaveAccountBanner(onTap: () => context.push('/auth/link')),
                const SizedBox(height: AppSpacing.lg),
              ],
              const _LudoComingSoonCard(),
              const Spacer(),
              OutlinedButton(
                onPressed: () => ref.read(authRepositoryProvider).signOut(),
                child: const SizedBox(
                  width: double.infinity,
                  child: Text('Sign Out', textAlign: TextAlign.center),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SaveAccountBanner extends StatelessWidget {
  const _SaveAccountBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: const Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(Icons.shield_outlined, color: AppColors.accentSecondary),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Save your account to keep your coins safe across devices.',
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _LudoComingSoonCard extends StatelessWidget {
  const _LudoComingSoonCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ludo', style: AppTextStyles.display(fontSize: 24)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Coming soon — stake coins and play 2-4 players online.',
              style: AppTextStyles.body(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            const OutlinedButton(
              onPressed: null,
              child: SizedBox(
                width: double.infinity,
                child: Text('Play', textAlign: TextAlign.center),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
