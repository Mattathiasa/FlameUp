// A social notification, written only by Cloud Functions.
//
// The server stores no display copy: [type] plus the actor's name are the
// facts, and the client renders the localized sentence. One more type means
// one more client case -- no function redeploy to fix wording.
import '../../../core/utils/firestore_date.dart';

enum AppNotificationType {
  friendRequest,
  friendAdded,
  recipePublished,
  recipeVouched,
  recipeVerified,
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.otherUid,
    required this.otherName,
    this.readAt,
    this.createdAt,
  });

  /// Null for a malformed document rather than throwing: one bad record must
  /// not blank the whole list.
  static AppNotification? fromJson(String id, Map<String, dynamic>? json) {
    if (json == null) return null;
    final type = AppNotificationType.values
        .where((t) => t.name == json['type'])
        .firstOrNull;
    if (type == null) return null;
    return AppNotification(
      id: id,
      type: type,
      otherUid: json['otherUid'] as String? ?? '',
      otherName: json['otherName'] as String? ?? '',
      readAt: firestoreDate(json['readAt']),
      createdAt: firestoreDate(json['createdAt']),
    );
  }

  final String id;
  final AppNotificationType type;
  final String otherUid;
  final String otherName;
  final DateTime? readAt;
  final DateTime? createdAt;

  bool get isUnread => readAt == null;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
