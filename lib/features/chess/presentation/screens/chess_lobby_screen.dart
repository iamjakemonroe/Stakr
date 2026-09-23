import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/coin_balance_pill.dart';
import '../../../../core/widgets/coin_buddy.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../../core/widgets/pop_card.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../friends/presentation/widgets/friends_popup.dart';
import '../controllers/chess_match_controller.dart';

const List<int> _stakePresets = [25, 50, 100, 250, 500];

/// "Play random" (matchmaking queue) or "play a friend" (opens the friends
/// popup, which handles the challenge itself) for chess.
class ChessLobbyScreen extends ConsumerStatefulWidget {
  const ChessLobbyScreen({super.key});

  @override
  ConsumerState<ChessLobbyScreen> createState() => _ChessLobbyScreenState();
}

class _ChessLobbyScreenState extends ConsumerState<ChessLobbyScreen>
    with SingleTickerProviderStateMixin {
  int _stake = _stakePresets[1];
  bool _searching = false;
  DateTime? _queuedAt;
  StreamSubscription<List<Map<String, dynamic>>>? _matchesSub;
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _matchesSub?.cancel();
    _pulseController.dispose();
    if (_searching) {
      ref.read(chessRepositoryProvider).leaveMatchmakingQueue();
    }
    super.dispose();
  }

  Future<void> _playRandom() async {
    final myId = ref.read(currentUserProvider)?.id;
    if (myId == null) return;

    setState(() {
      _searching = true;
      _queuedAt = DateTime.now();
    });

    final repository = ref.read(chessRepositoryProvider);
    final immediateMatchId = await repository.joinMatchmakingQueue(_stake);
    if (!mounted) return;

    if (immediateMatchId != null) {
      _goToMatch(immediateMatchId);
      return;
    }

    _matchesSub = repository.watchMyMatches(myId).listen((matches) {
      final queuedAt = _queuedAt;
      if (queuedAt == null) return;
      for (final match in matches) {
        if (match['status'] != 'active') continue;
        if (match['stake'] != _stake) continue;
        final createdAt = DateTime.tryParse(
          match['created_at'] as String? ?? '',
        );
        if (createdAt == null ||
            createdAt.isBefore(queuedAt.subtract(const Duration(seconds: 2))))
          continue;
        _goToMatch(match['id'] as String);
        return;
      }
    });
  }

  void _goToMatch(String matchId) {
    _matchesSub?.cancel();
    _matchesSub = null;
    setState(() => _searching = false);
    if (mounted) context.push('/chess/$matchId');
  }

  Future<void> _cancelSearch() async {
    await ref.read(chessRepositoryProvider).leaveMatchmakingQueue();
    _matchesSub?.cancel();
    _matchesSub = null;
    if (mounted) setState(() => _searching = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chess'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: AppSpacing.md),
            child: CoinBalancePill(),
          ),
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: _searching
                ? _SearchingView(
                    stake: _stake,
                    pulse: _pulseController,
                    onCancel: _cancelSearch,
                  )
                : _SetupView(
                    stake: _stake,
                    onStakeChanged: (v) => setState(() => _stake = v),
                    onPlayRandom: _playRandom,
                    onPlayFriend: () => showFriendsPopup(context),
                  ),
          ),
        ),
      ),
    );
  }
}

class _SetupView extends StatelessWidget {
  const _SetupView({
    required this.stake,
    required this.onStakeChanged,
    required this.onPlayRandom,
    required this.onPlayFriend,
  });

  final int stake;
  final ValueChanged<int> onStakeChanged;
  final VoidCallback onPlayRandom;
  final VoidCallback onPlayFriend;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Stake', style: AppTextStyles.display(fontSize: 20)),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: _stakePresets.map((amount) {
            final selected = amount == stake;
            return ChoiceChip(
              label: Text('$amount coins'),
              selected: selected,
              onSelected: (_) => onStakeChanged(amount),
              selectedColor: AppColors.accent,
              backgroundColor: AppColors.surface,
              labelStyle: TextStyle(
                color: selected ? Colors.white : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.xxl),
        PopCard(
          borderRadius: 26,
          tint: AppColors.accent,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.shuffle,
                color: AppColors.accentSecondary,
                size: 28,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('Play Random', style: AppTextStyles.display(fontSize: 18)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Get matched with the next player waiting at this stake.',
                style: AppTextStyles.body(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              PrimaryButton(label: 'Find a match', onPressed: onPlayRandom),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PopCard(
          borderRadius: 26,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.people_alt,
                color: AppColors.accentSecondary,
                size: 28,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('Play a Friend', style: AppTextStyles.display(fontSize: 18)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Challenge a friend, or someone you\'ve played before.',
                style: AppTextStyles.body(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                onPressed: onPlayFriend,
                child: const SizedBox(
                  width: double.infinity,
                  child: Text('Choose a friend', textAlign: TextAlign.center),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SearchingView extends StatelessWidget {
  const _SearchingView({
    required this.stake,
    required this.pulse,
    required this.onCancel,
  });

  final int stake;
  final AnimationController pulse;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: pulse,
            builder: (context, child) {
              final scale = 1.0 + (pulse.value * 0.12);
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 140,
                  height: 140,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.accent.withValues(alpha: 0.16),
                        AppColors.accent.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                  child: const CoinBuddy(mood: BuddyMood.thinking, size: 96),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Finding you an opponent…',
            style: AppTextStyles.display(fontSize: 20),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$stake coin stake',
            style: AppTextStyles.body(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          TextButton(onPressed: onCancel, child: const Text('Cancel')),
        ],
      ),
    );
  }
}
