import 'package:uuid/uuid.dart';

/// Who can see a post.
enum PostVisibility {
  public,
  friends;

  static PostVisibility fromName(String? name) =>
      PostVisibility.values.where((v) => v.name == name).firstOrNull ??
      PostVisibility.public;
}

/// A community post — someone showing what they cooked.
class Post {
  Post({
    required this.authorId,
    required this.authorName,
    required this.recipeId,
    required this.recipeTitle,
    required this.sessionId,
    this.body = '',
    this.photoUrl,
    this.authorPhotoUrl,
    this.likeCount = 0,
    this.commentCount = 0,
    this.visibility = PostVisibility.public,
    String? id,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  final String id;
  final String authorId;

  /// Denormalised so a feed row renders without a second read per post.
  final String authorName;
  final String? authorPhotoUrl;

  final String recipeId;
  final String recipeTitle;

  /// The cook this post is about. Required, so a post is always a record of
  /// something that actually happened rather than a free-standing status.
  final String sessionId;

  final String body;
  final String? photoUrl;

  /// Maintained by a Firestore trigger; the rules forbid a client writing it,
  /// so an author cannot inflate their own post.
  final int likeCount;
  final int commentCount;

  final PostVisibility visibility;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'authorId': authorId,
        'authorName': authorName,
        if (authorPhotoUrl != null) 'authorPhotoUrl': authorPhotoUrl,
        'recipeId': recipeId,
        'recipeTitle': recipeTitle,
        'sessionId': sessionId,
        'body': body,
        if (photoUrl != null) 'photoUrl': photoUrl,
        'likeCount': likeCount,
        'commentCount': commentCount,
        'visibility': visibility.name,
        'createdAt': createdAt.toIso8601String(),
      };

  static Post? fromJson(String id, Map<String, dynamic>? json) {
    if (json == null) return null;
    final authorId = json['authorId'] as String?;
    final sessionId = json['sessionId'] as String?;
    if (authorId == null || sessionId == null) return null;

    return Post(
      id: id,
      authorId: authorId,
      authorName: json['authorName'] as String? ?? '',
      authorPhotoUrl: json['authorPhotoUrl'] as String?,
      recipeId: json['recipeId'] as String? ?? '',
      recipeTitle: json['recipeTitle'] as String? ?? '',
      sessionId: sessionId,
      body: json['body'] as String? ?? '',
      photoUrl: json['photoUrl'] as String?,
      likeCount: json['likeCount'] as int? ?? 0,
      commentCount: json['commentCount'] as int? ?? 0,
      visibility: PostVisibility.fromName(json['visibility'] as String?),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    );
  }
}

/// A friendship, from one side.
class Friend {
  const Friend({
    required this.uid,
    required this.displayName,
    this.photoUrl,
    this.streak = 0,
    this.since,
  });

  final String uid;
  final String displayName;
  final String? photoUrl;
  final int streak;
  final DateTime? since;

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'displayName': displayName,
        if (photoUrl != null) 'photoUrl': photoUrl,
        'streak': streak,
        'since': (since ?? DateTime.now()).toIso8601String(),
      };

  static Friend? fromJson(String uid, Map<String, dynamic>? json) {
    if (json == null) return null;
    return Friend(
      uid: uid,
      displayName: json['displayName'] as String? ?? '',
      photoUrl: json['photoUrl'] as String?,
      streak: json['streak'] as int? ?? 0,
      since: DateTime.tryParse(json['since'] as String? ?? ''),
    );
  }
}

/// Which way a friend request points.
enum RequestDirection { incoming, outgoing }

enum RequestStatus { pending, accepted, declined }

class FriendRequest {
  const FriendRequest({
    required this.otherUid,
    required this.direction,
    required this.status,
    this.displayName = '',
    this.createdAt,
  });

  final String otherUid;
  final RequestDirection direction;
  final RequestStatus status;
  final String displayName;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
        'otherUid': otherUid,
        'direction': direction.name,
        'status': status.name,
        'displayName': displayName,
        'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
      };

  static FriendRequest? fromJson(String otherUid, Map<String, dynamic>? json) {
    if (json == null) return null;
    return FriendRequest(
      otherUid: otherUid,
      direction: RequestDirection.values
              .where((d) => d.name == json['direction'])
              .firstOrNull ??
          RequestDirection.incoming,
      status: RequestStatus.values
              .where((s) => s.name == json['status'])
              .firstOrNull ??
          RequestStatus.pending,
      displayName: json['displayName'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
