import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flameup/core/cache/outbox.dart';
import 'package:flameup/core/services/connectivity_service.dart';
import 'package:flameup/core/services/local_store.dart';
import 'package:flameup/features/family_recipes/data/family_recipe_repository.dart';
import 'package:flameup/features/family_recipes/domain/family_recipe.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The client side of community verification, against a fake Firestore.
///
/// The security rules are proven separately (rules-tests/); what is proven
/// here is that the repository sends exactly the write the rules accept —
/// the full vouched array, plus the auto-publish flip on the threshold
/// vouch — and that a foreign recipe is reported as not-found, not as a
/// server error.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore firestore;
  late FamilyRecipeRepository repo;

  setUp(() async {
    // The outbox's LocalStore persists to the app documents directory, which
    // does not exist under the test binding — point path_provider at a
    // scratch directory for the run.
    final tempDir = await Directory.systemTemp.createTemp('flameup_test');
    addTearDown(() => tempDir.delete(recursive: true));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tempDir.path,
    );

    SharedPreferences.setMockInitialValues({});
    firestore = FakeFirebaseFirestore();
    repo = FamilyRecipeRepository(
      outbox: Outbox(await LocalStore.open(), _StubConnectivity()),
      firestore: firestore,
    );
  });

  Future<void> seedRecipe(
    String id, {
    String status = 'pending',
    List<String> verifiedBy = const [],
  }) async {
    await firestore.collection('family_recipes').doc(id).set({
      'authorId': 'liya',
      'status': status,
      'title': 'Berbere from scratch',
      if (verifiedBy.isNotEmpty) 'verifiedBy': verifiedBy,
    });
  }

  group('FamilyRecipeRepository.verify', () {
    test('the first vouch writes only the array', () async {
      await seedRecipe('r1');

      await repo.verify(recipeId: 'r1', uid: 'dawit');

      final doc = await firestore.collection('family_recipes').doc('r1').get();
      expect(doc.data()!['verifiedBy'], ['dawit']);
      expect(doc.data()!['status'], 'pending');
    });

    test('the threshold vouch publishes the recipe in the same write',
        () async {
      await seedRecipe('r2', verifiedBy: ['dawit', 'selam']);

      await repo.verify(recipeId: 'r2', uid: 'abeni');

      final doc = await firestore.collection('family_recipes').doc('r2').get();
      expect(doc.data()!['verifiedBy'], ['dawit', 'selam', 'abeni']);
      expect(doc.data()!['status'], 'published');
    });

    test('a vouch on an already-published recipe keeps it published',
        () async {
      await seedRecipe('r3', status: 'published', verifiedBy: ['dawit']);

      await repo.verify(recipeId: 'r3', uid: 'selam');

      final doc = await firestore.collection('family_recipes').doc('r3').get();
      expect(doc.data()!['verifiedBy'], ['dawit', 'selam']);
      expect(doc.data()!['status'], 'published');
    });

    test('verifying a missing recipe surfaces not-found', () async {
      final result = await repo.verify(recipeId: 'ghost', uid: 'dawit');

      expect(result.isErr, isTrue);
    });

    test('the domain parses vouches and variant fields', () async {
      final recipe = FamilyRecipe.fromJson('r4', {
        'authorId': 'liya',
        'status': 'pending',
        'title': 'Shiro',
        'verifiedBy': ['dawit', 'selam', 42, ''],
        'baseId': 'doro-wat',
        'variantLabel': 'Pressure cooker',
      });

      expect(recipe!.verificationCount, 2);
      expect(recipe.verifiedByUser('dawit'), isTrue);
      expect(recipe.verifiedByUser('abeni'), isFalse);
      expect(recipe.isVariant, isTrue);
      expect(recipe.baseId, 'doro-wat');
      expect(recipe.variantLabel, 'Pressure cooker');
    });
  });
}

/// The outbox wants a connectivity service; verification never touches it.
class _StubConnectivity extends ConnectivityService {
  _StubConnectivity() : super();
}
