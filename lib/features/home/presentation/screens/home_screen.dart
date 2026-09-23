import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/profiles/profile_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/coin_balance_pill.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../../core/widgets/pop_card.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../chess/presentation/controllers/chess_match_controller.dart';
import '../../../friends/presentation/widgets/friend_icon_button.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final Set<String> _navigatedInviteIds = {};

  @override
  Widget build(BuildContext context) {
    final isAnonymous = ref.watch(isAnonymousProvider);
    final myId = ref.watch(currentUserProvider)?.id;

    // The moment an invite we *sent* gets accepted, jump straight into the
    // match — the person who accepted already gets the match id back
    // directly from respond_match_invite, this is the other half for us.
    if (myId != null) {
      ref.listen(outgoingInvitesProvider(myId), (previous, next) {
        next.whenData((invites) {
          for (final invite in invites) {
            final matchId = invite['match_id'] as String?;
            if (invite['status'] == 'accepted' &&
                matchId != null &&
                _navigatedInviteIds.add(invite['id'] as String)) {
              context.push('/chess/$matchId');
            }
          }
        });
      });
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Stakr'),
        actions: [
          const FriendIconButton(),
          const Padding(
            padding: EdgeInsets.only(right: AppSpacing.md, left: AppSpacing.xs),
            child: CoinBalancePill(),
          ),
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              MediaQuery.of(context).padding.top > 0
                  ? AppSpacing.md
                  : AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            children: [
              if (isAnonymous) ...[
                _SaveAccountBanner(onTap: () => context.push('/auth/link')),
                const SizedBox(height: AppSpacing.lg),
              ],
              if (myId != null) _UsernameBanner(myId: myId),
              if (myId != null) _IncomingInvites(myId: myId),
              const _ChessCard(),
              const SizedBox(height: AppSpacing.xl),
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
    return PopCard(
      borderRadius: 22,
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
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
      ),
    );
  }
}

class _UsernameBanner extends ConsumerWidget {
  const _UsernameBanner({required this.myId});

  final String myId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileByIdProvider(myId)).valueOrNull;
    if (profile == null || profile['username'] != null)
      return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: PopCard(
        borderRadius: 22,
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showUsernameDialog(context, ref),
            borderRadius: BorderRadius.circular(22),
            child: const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Icon(Icons.badge_outlined, color: AppColors.accentSecondary),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Pick a username so friends can find and add you.',
                    ),
                  ),
                  Icon(Icons.chevron_right, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showUsernameDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final username = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Choose a username'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'lowercase, 3-20 characters',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (username == null || username.isEmpty || !context.mounted) return;

    try {
      await ref
          .read(profileRepositoryProvider)
          .setUsername(username.toLowerCase());
      ref.invalidate(profileByIdProvider(myId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not set username: $e')));
      }
    }
  }
}

class _IncomingInvites extends ConsumerWidget {
  const _IncomingInvites({required this.myId});

  final String myId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invites =
        ref.watch(incomingInvitesProvider(myId)).valueOrNull ?? const [];
    final pending = invites.where((i) => i['status'] == 'pending').toList();
    if (pending.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: pending.map((invite) => _InviteCard(invite: invite)).toList(),
      ),
    );
  }
}

class _InviteCard extends ConsumerWidget {
  const _InviteCard({required this.invite});

  final Map<String, dynamic> invite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fromId = invite['from_user'] as String;
    final profile = ref.watch(profileByIdProvider(fromId)).valueOrNull;
    final name =
        profile?['display_name'] as String? ??
        profile?['username'] as String? ??
        'Someone';
    final stake = (invite['stake'] as num).toInt();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PopCard(
        borderRadius: 20,
        tint: AppColors.accentSecondary,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            const Icon(Icons.sports_esports, color: AppColors.accentSecondary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '$name challenged you · $stake coins',
                style: AppTextStyles.body(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () async {
                final repository = ref.read(chessRepositoryProvider);
                final matchId = await repository.respondMatchInvite(
                  inviteId: invite['id'] as String,
                  accept: true,
                );
                if (matchId != null && context.mounted)
                  context.push('/chess/$matchId');
              },
              child: const Text('Accept'),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.textSecondary),
              onPressed: () => ref
                  .read(chessRepositoryProvider)
                  .respondMatchInvite(
                    inviteId: invite['id'] as String,
                    accept: false,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChessCard extends StatelessWidget {
  const _ChessCard();

  @override
  Widget build(BuildContext context) {
    return PopCard(
      borderRadius: 28,
      tint: AppColors.accent,
      glow: AppColors.accent,
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/chess'),
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      '♛',
                      style: TextStyle(
                        fontSize: 36,
                        color: AppColors.accentSecondary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Chess',
                        style: AppTextStyles.display(fontSize: 26),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Stake coins, play a random opponent or challenge a friend.',
                  style: AppTextStyles.body(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  onPressed: () => context.push('/chess'),
                  child: const SizedBox(
                    width: double.infinity,
                    child: Text('Play', textAlign: TextAlign.center),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
