import 'package:flameup/features/community/domain/app_notification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppNotification.fromJson', () {
    test('parses a friend-request notification', () {
      final n = AppNotification.fromJson('friend_request_dawit', {
        'type': 'friendRequest',
        'otherUid': 'dawit',
        'otherName': 'Dawit',
        'readAt': null,
        'createdAt': '2026-09-14T10:00:00.000',
      });

      expect(n, isNotNull);
      expect(n!.type, AppNotificationType.friendRequest);
      expect(n.otherName, 'Dawit');
      expect(n.isUnread, isTrue);
      expect(n.createdAt, isNotNull);
    });

    test('parses a friend-added notification and its read state', () {
      final n = AppNotification.fromJson('friend_added_dawit', {
        'type': 'friendAdded',
        'otherUid': 'dawit',
        'otherName': 'Dawit',
        'readAt': '2026-09-14T11:00:00.000',
      });

      expect(n!.type, AppNotificationType.friendAdded);
      expect(n.isUnread, isFalse);
    });

    test('an unknown type is dropped, not thrown', () {
      // A future server version may write types this build does not know.
      // Dropping the one record beats crashing the whole list.
      expect(
        AppNotification.fromJson('x', {'type': 'recipeLiked'}),
        isNull,
      );
    });

    test('null or missing data is dropped', () {
      expect(AppNotification.fromJson('x', null), isNull);
      expect(AppNotification.fromJson('x', {'otherName': 'no type'}), isNull);
    });
  });
}
