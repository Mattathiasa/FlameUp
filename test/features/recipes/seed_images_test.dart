import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The seed catalogue's dish photos.
///
/// The honesty rule from the image hunt: only a verified, dish-accurate photo
/// earns an `imageUrl`. Everything else stays on gradients — so any URL that
/// ships must be https (hotlinkable per Commons policy) and unique (two dishes
/// showing the same photo is a lie).
void main() {
  final seedFile = File('assets/seed/recipes.json');
  final seed = jsonDecode(seedFile.readAsStringSync()) as Map<String, dynamic>;
  final recipes = seed['recipes'] as Map<String, dynamic>;

  test('seeded imageUrls are https, unique, and from trusted hosts', () {
    final seen = <String, String>{};

    recipes.forEach((id, raw) {
      final url = (raw as Map<String, dynamic>)['imageUrl'] as String?;
      if (url == null || url.isEmpty) return;

      expect(
        url.startsWith('https://'),
        isTrue,
        reason: '$id: images must be https to hotlink ($url)',
      );
      expect(
        Uri.tryParse(url)?.host ?? '',
        anyOf(contains('wikimedia'), contains('wikipedia')),
        reason: '$id: only verified hosts ship ($url)',
      );
      expect(
        seen.containsKey(url),
        isFalse,
        reason: '$id reuses the photo already shown for ${seen[url]}',
      );
      seen[url] = id;
    });

    expect(seen, isNotEmpty, reason: 'the catalogue should have some photos');
  });

  test('photos are the norm — but a minority may stay on gradients', () {
    var withPhoto = 0;
    for (final raw in recipes.values) {
      final url = (raw as Map<String, dynamic>)['imageUrl'] as String?;
      if (url != null && url.isNotEmpty) withPhoto++;
    }

    expect(withPhoto, greaterThanOrEqualTo(10));
    // Not every dish has a verified photo; gradients cover the rest.
    expect(withPhoto, lessThan(recipes.length));
  });
}
