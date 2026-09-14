import 'dart:convert';

import 'package:crypto/crypto.dart';

/// A person findable in the user directory.
///
/// Deliberately minimal: the [uid] is the key everything else resolves
/// through, the name is what search displays, and the code is what a friend
/// can read out loud. Nothing else about a user is public here.
class DirectoryUser {
  const DirectoryUser({
    required this.uid,
    required this.displayName,
    required this.friendCode,
  });

  /// Null for a malformed card rather than throwing: one bad document must
  /// not take down a whole result page.
  static DirectoryUser? fromJson(String uid, Map<String, dynamic>? json) {
    if (json == null) return null;
    final name = json['displayName'] as String?;
    final code = json['friendCode'] as String?;
    if (name == null || name.isEmpty || code == null || code.isEmpty) {
      return null;
    }
    return DirectoryUser(uid: uid, displayName: name, friendCode: code);
  }

  final String uid;
  final String displayName;
  final String friendCode;

  /// Lowercased, whitespace-collapsed name used for prefix search.
  static String searchableName(String displayName) => displayName
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ');

  /// The shareable friend code: the first eight hex characters of the SHA-256
  /// of the uid.
  ///
  /// A hash rather than per-user random storage means the code is stable,
  /// needs no extra write to exist, and cannot be confused with another user
  /// while staying short enough to read aloud. Eight hex characters is 4.3
  /// billion values -- collisions are a non-issue at any realistic size.
  static String friendCodeOf(String uid) =>
      sha256.convert(utf8.encode(uid)).toString().substring(0, 8);

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'displayName': displayName,
        'nameSearch': searchableName(displayName),
        'friendCode': friendCode,
      };
}
