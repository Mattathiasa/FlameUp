import 'package:flameup/features/community/domain/weekly_competition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('weekIdFor — ISO 8601 week numbering', () {
    test('mid-year dates land in the obvious week', () {
      // Tuesday 15 Sep 2026 → Monday 14 Sep → ISO week 38.
      expect(weekIdFor(DateTime(2026, 9, 15)), 'w2026w38');
    });

    test('a week straddling the new year belongs to the Thursday year', () {
      // 1 Jan 2026 is a Thursday; its week's Monday is 29 Dec 2025.
      // The week belongs to 2026, not 2025.
      expect(weekIdFor(DateTime(2026, 1, 1)), 'w2026w1');
    });

    test('1 January can belong to the previous ISO year', () {
      // 1 Jan 2027 is a Friday: its week's Thursday is 31 Dec 2026, so the
      // whole week is ISO week 53 of 2026 — the classic edge that breaks
      // naive "week of year" math.
      expect(weekIdFor(DateTime(2027, 1, 1)), 'w2026w53');
    });

    test('year end is week 53 when the year has one', () {
      expect(weekIdFor(DateTime(2026, 12, 31)), 'w2026w53');
    });

    test('weeks advance in lockstep across a year boundary', () {
      final before = weekIdFor(DateTime(2027, 12, 30)); // Thursday, week 52
      final after = weekIdFor(DateTime(2028, 1, 5)); // next week's Thursday
      expect(before, 'w2027w52');
      expect(after, 'w2028w1');
    });

    test('every day of the same week maps to one id', () {
      final ids = <String>{
        for (var d = 14; d <= 20; d++) weekIdFor(DateTime(2026, 9, d)),
      };
      expect(ids, {'w2026w38'});
    });

    test('local-timezone input is normalised to the UTC week', () {
      // Late Sunday evening in a UTC+10 zone is already Monday in UTC —
      // weekStart buckets on UTC, so both readings of the wall clock must
      // produce the same id rather than two neighbouring weeks.
      final utcSunday = DateTime.utc(2026, 9, 20, 23, 30);
      expect(weekIdFor(utcSunday), 'w2026w38');
    });
  });

  group('WeeklyChallenge', () {
    test('fromJson returns null without a recipe', () {
      expect(WeeklyChallenge.fromJson('w2026w38', {'deadline': 'x'}), isNull);
      expect(WeeklyChallenge.fromJson('w2026w38', null), isNull);
    });

    test('survives a JSON roundtrip', () {
      final original = WeeklyChallenge(
        id: 'w2026w38',
        recipeId: 'doro-wat',
        recipeTitle: 'Doro Wat',
        recipeTitleAm: 'ዶሮ ወጥ',
        deadline: DateTime.utc(2026, 9, 20),
        note: 'Use berbere generously',
      );

      final restored = WeeklyChallenge.fromJson(
        'w2026w38',
        {
          ...original.toJson(),
          // The wire format holds Timestamps (encoded as their ISO string in
          // this map), which firestoreDate() parses back.
        },
      );

      expect(restored, isNotNull);
      expect(restored!.recipeId, 'doro-wat');
      // Same instant, whatever zone each side reads back in.
      expect(restored.deadline.isAtSameMomentAs(original.deadline), isTrue);
      expect(restored.note, 'Use berbere generously');
    });
  });

  group('WeeklyXpRow', () {
    test('docId is week then uid, underscore-joined', () {
      expect(WeeklyXpRow.docId('w2026w38', 'u1'), 'w2026w38_u1');
    });

    test('fromJson tolerates junk and recovers the week from the id', () {
      final row = WeeklyXpRow.fromJson('w2026w38_u7', {
        'uid': 'u7',
        'xp': 120,
        'cooks': 3,
      });
      expect(row, isNotNull);
      expect(row!.weekId, 'w2026w38');
      expect(row.xp, 120);
      expect(row.displayName, '');
    });

    test('fromJson returns null without a uid', () {
      expect(WeeklyXpRow.fromJson('x', {'xp': 1}), isNull);
      expect(WeeklyXpRow.fromJson('x', null), isNull);
    });
  });

  group('WeeklyChallengeEntry', () {
    test('fromJson returns null without a session', () {
      expect(
        WeeklyChallengeEntry.fromJson('u1', {'displayName': 'Liya'}),
        isNull,
      );
    });

    test('photoUrl survives the roundtrip only when present', () {
      const withPhoto = WeeklyChallengeEntry(
        uid: 'u1',
        sessionId: 's',
        displayName: 'Liya',
        xp: 40,
        photoUrl: 'https://example.invalid/a.jpg',
      );
      expect(
        WeeklyChallengeEntry.fromJson(
          'u1',
          withPhoto.toJson()..['completedAt'] = null,
        )!
            .photoUrl,
        'https://example.invalid/a.jpg',
      );

      const withoutPhoto = WeeklyChallengeEntry(
        uid: 'u1',
        sessionId: 's',
        displayName: 'Liya',
        xp: 40,
      );
      expect(withoutPhoto.toJson().containsKey('photoUrl'), isFalse);
    });
  });
}
