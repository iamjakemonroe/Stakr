import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/profiles/profile_providers.dart';
import '../../../../core/supabase/supabase_providers.dart';
import '../../data/friend_repository.dart';

final friendRepositoryProvider = Provider<FriendRepository>((ref) {
  return FriendRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(profileRepositoryProvider),
  );
});

class FriendsPopupData {
  const FriendsPopupData({
    this.friends = const [],
    this.recents = const [],
    this.incomingRequests = const [],
    this.searchResults = const [],
    this.loading = true,
    this.searching = false,
  });

  final List<SocialProfile> friends;
  final List<SocialProfile> recents;
  final List<Map<String, dynamic>> incomingRequests;
  final List<Map<String, dynamic>> searchResults;
  final bool loading;
  final bool searching;

  List<SocialProfile> get all {
    final seen = <String>{};
    final combined = <SocialProfile>[];
    for (final person in [...friends, ...recents]) {
      if (seen.add(person.id)) combined.add(person);
    }
    return combined;
  }

  FriendsPopupData copyWith({
    List<SocialProfile>? friends,
    List<SocialProfile>? recents,
    List<Map<String, dynamic>>? incomingRequests,
    List<Map<String, dynamic>>? searchResults,
    bool? loading,
    bool? searching,
  }) {
    return FriendsPopupData(
      friends: friends ?? this.friends,
      recents: recents ?? this.recents,
      incomingRequests: incomingRequests ?? this.incomingRequests,
      searchResults: searchResults ?? this.searchResults,
      loading: loading ?? this.loading,
      searching: searching ?? this.searching,
    );
  }
}

class FriendsPopupController extends StateNotifier<FriendsPopupData> {
  FriendsPopupController(this._repository, this._userId)
    : super(const FriendsPopupData()) {
    refresh();
  }

  final FriendRepository _repository;
  final String _userId;
  int _searchGeneration = 0;

  Future<void> refresh() async {
    state = state.copyWith(loading: true);
    final results = await Future.wait([
      _repository.fetchFriends(_userId),
      _repository.fetchRecents(_userId),
      _repository.fetchIncomingFriendRequests(_userId),
    ]);
    state = state.copyWith(
      friends: results[0] as List<SocialProfile>,
      recents: results[1] as List<SocialProfile>,
      incomingRequests: results[2] as List<Map<String, dynamic>>,
      loading: false,
    );
  }

  Future<void> search(String query) async {
    final generation = ++_searchGeneration;
    if (query.trim().isEmpty) {
      state = state.copyWith(searchResults: const [], searching: false);
      return;
    }
    state = state.copyWith(searching: true);
    final results = await _repository.searchUsers(query, excludeId: _userId);
    if (generation != _searchGeneration)
      return; // a newer keystroke superseded this search
    state = state.copyWith(searchResults: results, searching: false);
  }

  Future<void> sendFriendRequest(String toUserId) async {
    await _repository.sendFriendRequest(toUserId);
    await refresh();
  }

  Future<void> respondFriendRequest({
    required String requestId,
    required bool accept,
  }) async {
    await _repository.respondFriendRequest(
      requestId: requestId,
      accept: accept,
    );
    await refresh();
  }
}

final friendsPopupControllerProvider =
    StateNotifierProvider.family<
      FriendsPopupController,
      FriendsPopupData,
      String
    >((ref, userId) {
      return FriendsPopupController(
        ref.watch(friendRepositoryProvider),
        userId,
      );
    });
