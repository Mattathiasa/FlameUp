import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/auth_providers.dart';
import '../data/community_repository.dart';
import 'challenge.dart';
import 'post.dart';

/// The signed-in user's friends.
final friendsProvider = StreamProvider.autoDispose<List<Friend>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(communityRepositoryProvider).watchFriends(uid);
});

/// Pending friend requests, both directions.
final friendRequestsProvider =
    StreamProvider.autoDispose<List<FriendRequest>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(communityRepositoryProvider).watchRequests(uid);
});

/// Requests waiting on the user to answer.
final incomingRequestsProvider =
    Provider.autoDispose<List<FriendRequest>>((ref) {
  return ref
          .watch(friendRequestsProvider)
          .valueOrNull
          ?.where(
            (r) =>
                r.direction == RequestDirection.incoming &&
                r.status == RequestStatus.pending,
          )
          .toList() ??
      const [];
});

/// The user's challenges, newest first.
final challengesProvider = StreamProvider.autoDispose<List<Challenge>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(communityRepositoryProvider).watchChallenges(uid);
});

/// Challenges waiting on the user: an unanswered invitation, or one accepted
/// but not yet cooked.
final actionableChallengesProvider =
    Provider.autoDispose<List<Challenge>>((ref) {
  final uid = ref.watch(currentUidProvider);
  final all = ref.watch(challengesProvider).valueOrNull ?? const [];
  if (uid == null) return const [];

  final now = DateTime.now();
  return all
      .where((challenge) => !challenge.hasExpired(now))
      .where(
        (challenge) =>
            (challenge.status == ChallengeStatus.invited &&
                challenge.opponentId == uid) ||
            (challenge.status == ChallengeStatus.accepted &&
                !challenge.hasSubmitted(uid)),
      )
      .toList();
});

/// One page of the public feed.
///
/// A notifier rather than a stream, because paging is a user action: the next
/// page loads when they reach the end, not whenever the collection changes.
class FeedController extends AutoDisposeAsyncNotifier<List<Post>> {
  /// The last document of the page just loaded, used to start the next one.
  /// A cursor rather than an offset: an offset re-reads everything skipped.
  DocumentSnapshot<Map<String, dynamic>>? _cursor;
  bool _exhausted = false;

  @override
  Future<List<Post>> build() async {
    _cursor = null;
    _exhausted = false;
    return _load(const []);
  }

  bool get hasMore => !_exhausted;

  Future<void> loadMore() async {
    if (_exhausted) return;
    final current = state.valueOrNull ?? const <Post>[];
    state = AsyncData(await _load(current));
  }

  Future<List<Post>> _load(List<Post> existing) async {
    final result =
        await ref.read(communityRepositoryProvider).feedPage(after: _cursor);
    final page = result.valueOrNull;

    if (page == null) {
      _exhausted = true;
      return existing;
    }

    final (posts, cursor) = page;
    _cursor = cursor;
    if (cursor == null || posts.isEmpty) _exhausted = true;

    return [...existing, ...posts];
  }
}

final feedProvider =
    AutoDisposeAsyncNotifierProvider<FeedController, List<Post>>(
  FeedController.new,
);
