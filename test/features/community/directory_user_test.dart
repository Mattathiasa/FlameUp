import 'package:flameup/features/community/domain/directory_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('friendCodeOf', () {
    test('is eight lowercase hex characters', () {
      final code = DirectoryUser.friendCodeOf('some-uid-123');
      expect(code, hasLength(8));
      expect(RegExp(r'^[0-9a-f]{8}$').hasMatch(code), isTrue);
    });

    test('is stable for the same uid', () {
      expect(
        DirectoryUser.friendCodeOf('abc'),
        DirectoryUser.friendCodeOf('abc'),
      );
    });

    test('differs across uids', () {
      expect(
        DirectoryUser.friendCodeOf('uid-a'),
        isNot(DirectoryUser.friendCodeOf('uid-b')),
      );
    });
  });

  group('searchableName', () {
    test('lowercases and collapses whitespace', () {
      expect(
        DirectoryUser.searchableName('  Abebe   Bikila '),
        'abebe bikila',
      );
    });

    test('handles a name of only spaces', () {
      expect(DirectoryUser.searchableName('   '), '');
    });
  });

  group('fromJson', () {
    test('parses a complete card', () {
      final user = DirectoryUser.fromJson('u1', {
        'displayName': 'Liya',
        'friendCode': 'deadbeef',
      });
      expect(user, isNotNull);
      expect(user!.uid, 'u1');
      expect(user.displayName, 'Liya');
      expect(user.friendCode, 'deadbeef');
    });

    test('returns null rather than throwing on a malformed card', () {
      expect(DirectoryUser.fromJson('u1', null), isNull);
      expect(
        DirectoryUser.fromJson('u1', {'displayName': '', 'friendCode': 'x'}),
        isNull,
      );
      expect(
        DirectoryUser.fromJson('u1', {'displayName': 'Liya'}),
        isNull,
      );
    });
  });

  group('toJson round trip', () {
    test('carries the searchable name', () {
      final json = const DirectoryUser(
        uid: 'u1',
        displayName: 'Abebe Bikila',
        friendCode: 'deadbeef',
      ).toJson();

      expect(json['nameSearch'], 'abebe bikila');
      expect(json['uid'], 'u1');
      expect(json['friendCode'], 'deadbeef');
    });
  });
}
