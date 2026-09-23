import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/profiles/profile_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../../core/widgets/coin_buddy.dart';
import '../../../../core/widgets/pop_card.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/chess_engine.dart';
import '../../domain/chess_types.dart';
import '../controllers/chess_match_controller.dart';
import '../widgets/animated_chess_board.dart';
import '../widgets/promotion_sheet.dart';

class ChessMatchScreen extends ConsumerStatefulWidget {
  const ChessMatchScreen({super.key, required this.matchId});

  final String matchId;

  @override
  ConsumerState<ChessMatchScreen> createState() => _ChessMatchScreenState();
}

class _ChessMatchScreenState extends ConsumerState<ChessMatchScreen> {
  bool _promotionSheetOpen = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chessMatchControllerProvider(widget.matchId));
    final controller = ref.read(
      chessMatchControllerProvider(widget.matchId).notifier,
    );
    final myId = ref.watch(currentUserProvider)?.id;

    ref.listen(chessMatchControllerProvider(widget.matchId), (
      previous,
      next,
    ) async {
      if (next.pendingPromotion != null && !_promotionSheetOpen) {
        _promotionSheetOpen = true;
        final choice = await showPromotionSheet(
          context,
          next.pendingPromotion!.piece.color,
        );
        _promotionSheetOpen = false;
        if (!context.mounted) return;
        if (choice != null) {
          controller.choosePromotion(choice);
        } else {
          controller.cancelPromotion();
        }
      }
    });

    if (state.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (state.error != null && state.matchRow == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chess')),
        body: Center(
          child: Text(
            state.error!,
            style: AppTextStyles.body(color: AppColors.error),
          ),
        ),
      );
    }

    final row = state.matchRow!;
    final opponentId = row['player_white'] == myId
        ? row['player_black'] as String?
        : row['player_white'] as String?;
    final isDone =
        row['status'] == 'completed' ||
        row['status'] == 'disputed' ||
        row['status'] == 'aborted';

    return Scaffold(
      appBar: AppBar(
        title: Text('Stake ${state.stake} coins'),
        actions: [
          if (row['status'] == 'active')
            IconButton(
              icon: const Icon(Icons.flag_outlined),
              tooltip: 'Resign',
              onPressed: () => _confirmResign(context, controller),
            ),
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                _PlayerBar(
                  userId: opponentId,
                  fallbackLabel: 'Opponent',
                  isTurn: !state.isMyTurn && row['status'] == 'active',
                  colorLabel: state.myColor == PieceColor.white
                      ? 'Black'
                      : 'White',
                ),
                const SizedBox(height: AppSpacing.sm),
                _StatusBanner(
                  status: state.gameStatus,
                  isMyTurn: state.isMyTurn,
                  matchStatus: row['status'] as String,
                ),
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: Center(
                    child: PopCard(
                      borderRadius: 28,
                      blur: 10,
                      glow: state.gameStatus == GameStatus.check
                          ? AppColors.error
                          : AppColors.accent,
                      padding: const EdgeInsets.all(10),
                      child: AnimatedChessBoard(
                        position: state.position,
                        lastMove: state.lastMove,
                        legalDestinations: state.selectedSquare == null
                            ? const []
                            : state.legalDestinations,
                        selectedSquare: state.selectedSquare,
                        myColor: state.myColor,
                        interactive: state.isMyTurn && !isDone,
                        onSquareTap: controller.selectSquare,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _PlayerBar(
                  userId: myId,
                  fallbackLabel: 'You',
                  isTurn: state.isMyTurn,
                  colorLabel: state.myColor == PieceColor.white
                      ? 'White'
                      : 'Black',
                ),
              ],
            ),
          ),
        ),
      ),
      bottomSheet: isDone ? _GameOverPanel(state: state, myId: myId) : null,
    );
  }

  void _confirmResign(BuildContext context, ChessMatchController controller) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Resign this match?'),
        content: const Text(
          'Your opponent wins the pot. This can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Keep playing'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              controller.resign();
            },
            child: const Text(
              'Resign',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerBar extends ConsumerWidget {
  const _PlayerBar({
    required this.userId,
    required this.fallbackLabel,
    required this.isTurn,
    required this.colorLabel,
  });

  final String? userId;
  final String fallbackLabel;
  final bool isTurn;
  final String colorLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = userId == null
        ? null
        : ref.watch(profileByIdProvider(userId!)).valueOrNull;
    final name =
        profile?['display_name'] as String? ??
        profile?['username'] as String? ??
        fallbackLabel;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: PopCard(
        key: ValueKey(isTurn),
        borderRadius: 20,
        blur: 10,
        tint: isTurn ? AppColors.accentSecondary : null,
        glow: isTurn ? AppColors.accentSecondary : null,
        borderWidth: isTurn ? 1.8 : 1.2,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.accent.withValues(alpha: 0.3),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: AppTextStyles.body(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                name,
                style: AppTextStyles.body(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              colorLabel,
              style: AppTextStyles.body(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.status,
    required this.isMyTurn,
    required this.matchStatus,
  });

  final GameStatus status;
  final bool isMyTurn;
  final String matchStatus;

  @override
  Widget build(BuildContext context) {
    if (matchStatus != 'active') return const SizedBox.shrink();

    final text = switch (status) {
      GameStatus.check => 'Check!',
      _ => isMyTurn ? 'Your move' : 'Waiting for opponent…',
    };
    final color = status == GameStatus.check
        ? AppColors.error
        : AppColors.textSecondary;

    return Text(
      text,
      style: AppTextStyles.body(color: color, fontWeight: FontWeight.w600),
    );
  }
}

class _GameOverPanel extends StatelessWidget {
  const _GameOverPanel({required this.state, required this.myId});

  final ChessMatchState state;
  final String? myId;

  @override
  Widget build(BuildContext context) {
    final iWon = state.winnerId != null && state.winnerId == myId;
    final isDraw = state.winnerId == null;
    final title = isDraw ? "It's a draw" : (iWon ? 'You won! 🎉' : 'You lost');
    final subtitle = switch (state.result) {
      'checkmate' => 'Checkmate.',
      'resignation' => iWon ? 'Your opponent resigned.' : 'You resigned.',
      'stalemate' => 'Stalemate — no legal moves left.',
      'draw' => 'Draw by the 50-move rule or insufficient material.',
      'timeout' =>
        iWon
            ? 'Your opponent went quiet — you win by timeout.'
            : "You went quiet too long — timeout.",
      _ => '',
    };
    final commissionBps =
        (state.matchRow?['commission_bps'] as num?)?.toInt() ?? 500;
    final payout = isDraw
        ? state.stake
        : (state.stake * 2 * (1 - commissionBps / 10000)).floor();

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: PopCard(
        borderRadius: 28,
        blur: 20,
        tint: iWon ? AppColors.success : (isDraw ? null : AppColors.error),
        glow: iWon
            ? AppColors.success
            : (isDraw ? AppColors.accent : AppColors.error),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CoinBuddy(
              mood: isDraw
                  ? BuddyMood.idle
                  : (iWon ? BuddyMood.happy : BuddyMood.sad),
              size: 80,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(title, style: AppTextStyles.display(fontSize: 26)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              style: AppTextStyles.body(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (!isDraw)
              Text(
                iWon ? '+$payout coins' : '-${state.stake} coins',
                style: AppTextStyles.display(
                  fontSize: 20,
                  color: iWon ? AppColors.success : AppColors.error,
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Back to lobby',
              onPressed: () => context.go('/home'),
            ),
          ],
        ),
      ),
    );
  }
}
