// Seeds the recipe catalogue into Firestore.
//
// Usage:
//   dart run tool/seed_firestore.dart --emulator
//   dart run tool/seed_firestore.dart --project flameup-78d15
//
// Reads assets/seed/recipes.json -- the same catalogue the app bundles -- and
// writes each recipe as a published document. Idempotent: documents are keyed
// by recipe id and merged, so re-running updates rather than duplicating.
//
// This is a standalone script, not part of the app. It talks to the Firestore
// REST API rather than the Flutter SDK so it can run under plain `dart run`
// with no Flutter binding.

import 'dart:convert';
import 'dart:io';

const String _seedPath = 'assets/seed/recipes.json';

Future<void> main(List<String> args) async {
  final useEmulator = args.contains('--emulator');
  final projectIndex = args.indexOf('--project');
  final project = projectIndex >= 0 && projectIndex + 1 < args.length
      ? args[projectIndex + 1]
      : 'flameup-78d15';

  final seedFile = File(_seedPath);
  if (!seedFile.existsSync()) {
    stderr.writeln('$_seedPath not found. Run: python3 tool/build_seed.py');
    exit(1);
  }

  final payload =
      jsonDecode(seedFile.readAsStringSync()) as Map<String, dynamic>;
  final recipes = payload['recipes'] as Map<String, dynamic>;
  final regions = payload['regions'] as List<dynamic>;

  final host = useEmulator
      ? 'http://localhost:8080/v1/projects/$project/databases/(default)/documents'
      : 'https://firestore.googleapis.com/v1/projects/$project/databases/(default)/documents';

  stdout.writeln('Seeding ${recipes.length} recipes and ${regions.length} '
      'regions into $project${useEmulator ? ' (emulator)' : ''}');

  if (!useEmulator) {
    stdout.writeln(
      '\nWriting to the live project needs an access token:\n'
      '  gcloud auth print-access-token\n'
      'or run against the emulator with --emulator.\n',
    );
  }

  final client = HttpClient();
  var written = 0;

  try {
    for (final entry in recipes.entries) {
      final ok = await _put(
        client,
        '$host/recipes/${entry.key}',
        _toFirestoreDocument(entry.value as Map<String, dynamic>),
      );
      if (ok) written++;
    }

    for (final region in regions) {
      final data = region as Map<String, dynamic>;
      await _put(
        client,
        '$host/regions/${data['id']}',
        _toFirestoreDocument(data),
      );
    }
  } finally {
    client.close();
  }

  stdout.writeln('Wrote $written/${recipes.length} recipes.');
  if (written < recipes.length) {
    stdout.writeln(
      'Some writes failed. Against the live project this usually means the '
      'security rules reject unauthenticated writes, which is correct -- seed '
      'the emulator instead, or use an admin credential.',
    );
    exit(1);
  }
}

Future<bool> _put(
  HttpClient client,
  String url,
  Map<String, dynamic> doc,
) async {
  try {
    final request = await client.patchUrl(Uri.parse(url));
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(doc));
    final response = await request.close();
    await response.drain<void>();

    if (response.statusCode >= 400) {
      stderr.writeln('  ${response.statusCode} $url');
      return false;
    }
    return true;
  } catch (error) {
    stderr.writeln('  failed $url: $error');
    return false;
  }
}

/// Converts plain JSON into Firestore's typed-value REST format.
Map<String, dynamic> _toFirestoreDocument(Map<String, dynamic> data) => {
      'fields': {
        for (final entry in data.entries)
          if (entry.key != 'id') entry.key: _toValue(entry.value),
      },
    };

Map<String, dynamic> _toValue(Object? value) => switch (value) {
      null => {'nullValue': null},
      final bool v => {'booleanValue': v},
      final int v => {'integerValue': v.toString()},
      final double v => {'doubleValue': v},
      final String v => {'stringValue': v},
      final List<dynamic> v => {
          'arrayValue': {'values': v.map(_toValue).toList()},
        },
      final Map<dynamic, dynamic> v => {
          'mapValue': {
            'fields': {
              for (final e in v.entries) e.key.toString(): _toValue(e.value),
            },
          },
        },
      _ => {'stringValue': value.toString()},
    };
