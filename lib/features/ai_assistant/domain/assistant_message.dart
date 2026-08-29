/// What kind of claim a line of the assistant's answer is making.
///
/// The whole point of the feature's design: a model's inference about someone
/// else's food culture must never read with the same authority as something a
/// cook actually told us.
enum ClaimKind {
  /// What this app's own recipe says.
  recipe,

  /// How people commonly cook or eat it — practice, not asserted history.
  tradition,

  /// The model's own inference: a substitution, a fix, a tip.
  suggestion,

  /// Unlabelled prose.
  plain;

  static ClaimKind fromMarker(String marker) => switch (marker.toUpperCase()) {
        'RECIPE' => ClaimKind.recipe,
        'TRADITION' => ClaimKind.tradition,
        'SUGGESTION' => ClaimKind.suggestion,
        _ => ClaimKind.plain,
      };
}

/// One labelled segment of an answer.
class Claim {
  const Claim({required this.kind, required this.text});

  final ClaimKind kind;
  final String text;
}

/// A turn in the conversation.
class AssistantMessage {
  const AssistantMessage({
    required this.text,
    required this.fromUser,
    this.claims = const [],
    this.failed = false,
  });

  final String text;
  final bool fromUser;
  final List<Claim> claims;
  final bool failed;

  /// Splits a labelled answer into its claims.
  ///
  /// The model is asked to prefix each claim with `[RECIPE]`, `[TRADITION]` or
  /// `[SUGGESTION]`. If it does not comply the text is shown as [plain] —
  /// never silently relabelled as something more authoritative than it is.
  factory AssistantMessage.fromAnswer(String answer) {
    final pattern =
        RegExp(r'\[(RECIPE|TRADITION|SUGGESTION)\]', caseSensitive: false);
    final matches = pattern.allMatches(answer).toList();

    if (matches.isEmpty) {
      return AssistantMessage(
        text: answer,
        fromUser: false,
        claims: [Claim(kind: ClaimKind.plain, text: answer.trim())],
      );
    }

    final claims = <Claim>[];

    // Anything before the first marker is unlabelled prose.
    final preamble = answer.substring(0, matches.first.start).trim();
    if (preamble.isNotEmpty) {
      claims.add(Claim(kind: ClaimKind.plain, text: preamble));
    }

    for (var i = 0; i < matches.length; i++) {
      final match = matches[i];
      final end = i + 1 < matches.length ? matches[i + 1].start : answer.length;
      final body = answer.substring(match.end, end).trim();
      if (body.isEmpty) continue;

      claims.add(
        Claim(kind: ClaimKind.fromMarker(match.group(1)!), text: body),
      );
    }

    return AssistantMessage(text: answer, fromUser: false, claims: claims);
  }

  factory AssistantMessage.user(String text) =>
      AssistantMessage(text: text, fromUser: true);

  factory AssistantMessage.error(String message) => AssistantMessage(
        text: message,
        fromUser: false,
        failed: true,
        claims: [Claim(kind: ClaimKind.plain, text: message)],
      );
}
