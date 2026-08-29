import 'package:flameup/features/recipes/domain/review.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('a review is tied to a cooking session', () {
    test('always carries the session it rates', () {
      // The server requires this, which is how "you can only rate what you
      // actually cooked" is enforced rather than merely encouraged.
      final review = Review(
        recipeId: 'doro',
        sessionId: 'session-1',
        uid: 'user-1',
        taste: 5,
      );

      expect(review.sessionId, 'session-1');
      expect(review.toJson()['sessionId'], 'session-1');
    });

    test('cannot be decoded without one', () {
      expect(
        Review.fromJson(const {'recipeId': 'doro', 'uid': 'user-1'}),
        isNull,
      );
      expect(Review.fromJson(const {}), isNull);
      expect(Review.fromJson(null), isNull);
    });
  });

  group('dimensions', () {
    test('default to neutral so a quick rating is still valid', () {
      final review = Review(
        recipeId: 'doro',
        sessionId: 's1',
        uid: 'u1',
        taste: 5,
      );

      expect(review.taste, 5);
      expect(review.difficulty, 3);
      expect(review.instructions, 3);
      expect(review.authenticity, 3);
      expect(review.wouldCookAgain, isTrue);
    });

    test('round trip through JSON', () {
      final original = Review(
        recipeId: 'doro',
        sessionId: 's1',
        uid: 'u1',
        taste: 4,
        difficulty: 5,
        body: 'Four hours of onion patience.',
        shareToCommunity: true,
      );

      final restored = Review.fromJson(original.toJson())!;

      expect(restored.id, original.id);
      expect(restored.taste, 4);
      expect(restored.difficulty, 5);
      expect(restored.body, 'Four hours of onion patience.');
      expect(restored.shareToCommunity, isTrue);
    });

    test('an empty note is omitted rather than stored blank', () {
      final review = Review(
        recipeId: 'doro',
        sessionId: 's1',
        uid: 'u1',
        taste: 3,
        body: '   ',
      );

      expect(review.toJson().containsKey('body'), isFalse);
    });

    test('the id survives copyWith, so an edit is not a second review', () {
      final review = Review(
        recipeId: 'doro',
        sessionId: 's1',
        uid: 'u1',
        taste: 3,
      );

      expect(review.copyWith(taste: 5).id, review.id);
      expect(review.copyWith(taste: 5).sessionId, 's1');
    });
  });
}
