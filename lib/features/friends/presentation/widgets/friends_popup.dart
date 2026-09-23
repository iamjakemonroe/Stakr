import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/profiles/profile_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/pop_card.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../chess/presentation/controllers/chess_match_controller.dart';
import '../../data/friend_repository.dart';
import '../providers/friends_providers.dart';
import 'invite_stake_sheet.dart';

/// Opens the friends popup: Friends / Recents / All, with search and an
/// "invite to play" action on every row. Triggered from the person-icon in
/// the home app bar.
void showFriendsPopup(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _FriendsPopup(),
  );
}

class _FriendsPopup extends ConsumerStatefulWidget {
  const _FriendsPopup();

  @override
  ConsumerState<_FriendsPopup> createState() => _FriendsPopupState();
}

class _FriendsPopupState extends ConsumerState<_FriendsPopup> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myId = ref.watch(currentUserProvider)?.id;
    if (myId == null) return const SizedBox.shrink();

    final data = ref.watch(friendsPopupControllerProvider(myId));
    final controller = ref.read(friendsPopupControllerProvider(myId).notifier);
    final friendIds = data.friends.map((f) => f.id).toSet();
    final isSearching = _searchController.text.trim().isNotEmpty;

    return DefaultTabController(
      length: 3,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: PopCard(
          borderRadius: 28,
          blur: 20,
          padding: EdgeInsets.zero,
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.82,
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Friends',
                          style: AppTextStyles.display(fontSize: 24),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: controller.search,
                    style: AppTextStyles.body(),
                    decoration: InputDecoration(
                      hintText: 'Search by username',
                      hintStyle: AppTextStyles.body(
                        color: AppColors.textSecondary,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppColors.textSecondary,
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                if (data.incomingRequests.isNotEmpty && !isSearching) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _IncomingRequests(
                    requests: data.incomingRequests,
                    controller: controller,
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: isSearching
                      ? _SearchResults(
                          results: data.searchResults,
                          searching: data.searching,
                          friendIds: friendIds,
                          onAdd: controller.sendFriendRequest,
                        )
                      : Column(
                          children: [
                            const TabBar(
                              labelColor: AppColors.textPrimary,
                              unselectedLabelColor: AppColors.textSecondary,
                              indicatorColor: AppColors.accent,
                              tabs: [
                                Tab(text: 'Friends'),
                                Tab(text: 'Recents'),
                                Tab(text: 'All'),
                              ],
                            ),
                            Expanded(
                              child: data.loading
                                  ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  : TabBarView(
                                      children: [
                                        _PeopleList(
                                          people: data.friends,
                                          isFriend: (_) => true,
                                          onAdd: null,
                                          emptyLabel:
                                              'No friends yet — search a username above.',
                                        ),
                                        _PeopleList(
                                          people: data.recents,
                                          isFriend: (_) => false,
                                          onAdd: controller.sendFriendRequest,
                                          emptyLabel:
                                              "People you've played who aren't friends yet will show up here.",
                                        ),
                                        _PeopleList(
                                          people: data.all,
                                          isFriend: (p) =>
                                              friendIds.contains(p.id),
                                          onAdd: controller.sendFriendRequest,
                                          emptyLabel:
                                              'Play a match or add a friend to get started.',
                                        ),
                                      ],
                                    ),
                            ),
                          ],
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

class _IncomingRequests extends ConsumerWidget {
  const _IncomingRequests({required this.requests, required this.controller});

  final List<Map<String, dynamic>> requests;
  final FriendsPopupController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: requests.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final request = requests[index];
          final fromId = request['from_user'] as String;
          final profile = ref.watch(profileByIdProvider(fromId)).valueOrNull;
          final name =
              profile?['display_name'] as String? ??
              profile?['username'] as String? ??
              'Someone';

          return Container(
            width: 200,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$name wants to be friends',
                    style: AppTextStyles.body(fontSize: 13),
                    maxLines: 2,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.check_circle,
                    color: AppColors.success,
                    size: 22,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: () => controller.respondFriendRequest(
                    requestId: request['id'] as String,
                    accept: true,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.cancel,
                    color: AppColors.textSecondary,
                    size: 22,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: () => controller.respondFriendRequest(
                    requestId: request['id'] as String,
                    accept: false,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.results,
    required this.searching,
    required this.friendIds,
    required this.onAdd,
  });

  final List<Map<String, dynamic>> results;
  final bool searching;
  final Set<String> friendIds;
  final ValueChanged<String> onAdd;

  @override
  Widget build(BuildContext context) {
    if (searching) return const Center(child: CircularProgressIndicator());
    if (results.isEmpty) {
      return Center(
        child: Text(
          'No one found.',
          style: AppTextStyles.body(color: AppColors.textSecondary),
        ),
      );
    }
    return _PeopleList(
      people: results.map(SocialProfile.fromProfileRow).toList(),
      isFriend: (p) => friendIds.contains(p.id),
      onAdd: onAdd,
      emptyLabel: '',
    );
  }
}

class _PeopleList extends StatelessWidget {
  const _PeopleList({
    required this.people,
    required this.isFriend,
    required this.onAdd,
    required this.emptyLabel,
  });

  final List<SocialProfile> people;
  final bool Function(SocialProfile) isFriend;
  final ValueChanged<String>? onAdd;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (people.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Text(
            emptyLabel,
            textAlign: TextAlign.center,
            style: AppTextStyles.body(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: people.length,
      itemBuilder: (context, index) {
        final person = people[index];
        return _PersonRow(
          person: person,
          isFriend: isFriend(person),
          onAdd: onAdd,
        );
      },
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.person,
    required this.isFriend,
    required this.onAdd,
  });

  final SocialProfile person;
  final bool isFriend;
  final ValueChanged<String>? onAdd;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.accent.withValues(alpha: 0.3),
        child: Text(
          person.name.isNotEmpty ? person.name[0].toUpperCase() : '?',
          style: AppTextStyles.body(fontWeight: FontWeight.w700),
        ),
      ),
      title: Text(
        person.name,
        style: AppTextStyles.body(fontWeight: FontWeight.w600),
      ),
      subtitle: person.username != null
          ? Text(
              '@${person.username}',
              style: AppTextStyles.body(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isFriend && onAdd != null)
            IconButton(
              icon: const Icon(
                Icons.person_add_alt_1,
                color: AppColors.textSecondary,
              ),
              tooltip: 'Add friend',
              onPressed: () => onAdd!(person.id),
            ),
          FilledButton.tonalIcon(
            onPressed: () => _invite(context),
            icon: const Icon(Icons.sports_esports_outlined, size: 18),
            label: const Text('Play'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent.withValues(alpha: 0.2),
              foregroundColor: AppColors.accentSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _invite(BuildContext context) async {
    final stake = await showInviteStakeSheet(
      context,
      opponentName: person.name,
    );
    if (stake == null || !context.mounted) return;

    final container = ProviderScope.containerOf(context);
    final repository = container.read(chessRepositoryProvider);
    try {
      await repository.sendMatchInvite(toUserId: person.id, stake: stake);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Challenge sent to ${person.name}!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not send challenge: $e')));
      }
    }
  }
}
