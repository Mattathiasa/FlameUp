// One recipe in Grandma's Kitchen, as stored in `family_recipes/{id}`.
//
// Deliberately tolerant: these documents are written by phones (sometimes
// offline, sometimes mid-migration) and read years later. A missing field is
// rendered as absent, never a crash.
import '../../../core/utils/firestore_date.dart';

class FamilyRecipe {
  const FamilyRecipe({
    required this.id,
    required this.authorId,
    required this.status,
    this.title = '',
    this.titleAm = '',
    this.teacherName = '',
    this.regionId,
    this.story = '',
    this.stepsText = '',
    this.ingredientsText = '',
    this.verifiedBy = const [],
    this.baseId,
    this.variantLabel,
    this.mediaUrl,
    this.createdAt,
    this.updatedAt,
  });

  /// Null for a malformed document rather than throwing: one bad record must
  /// not blank the whole list.
  static FamilyRecipe? fromJson(String id, Map<String, dynamic>? json) {
    if (json == null) return null;
    final status = FamilyRecipeStatus.values
        .where((s) => s.name == json['status'])
        .firstOrNull;
    if (status == null) return null;

    return FamilyRecipe(
      id: id,
      authorId: json['authorId'] as String? ?? '',
      status: status,
      title: json['title'] as String? ?? '',
      titleAm: json['titleAm'] as String? ?? '',
      teacherName: json['teacherName'] as String? ?? '',
      regionId: json['regionId'] as String?,
      story: json['story'] as String? ?? '',
      stepsText: json['stepsText'] as String? ?? '',
      ingredientsText: json['ingredientsText'] as String? ?? '',
      verifiedBy: [
        for (final uid in (json['verifiedBy'] as List? ?? const []))
          if (uid is String && uid.isNotEmpty) uid,
      ],
      baseId: json['baseId'] as String?,
      variantLabel: json['variantLabel'] as String?,
      mediaUrl: json['mediaUrl'] as String?,
      createdAt: firestoreDate(json['createdAt']),
      updatedAt: firestoreDate(json['updatedAt']),
    );
  }

  final String id;
  final String authorId;
  final FamilyRecipeStatus status;
  final String title;
  final String titleAm;
  final String teacherName;
  final String? regionId;
  final String story;
  final String stepsText;

  /// Free-form ingredient list, one ingredient per line or comma-separated —
  /// family recipes are dictated, not measured. Rendered verbatim.
  final String ingredientsText;

  /// The uids of the cooks who vouched for this recipe — who made it
  /// themselves and can say it works. The rules guarantee the array only ever
  /// grows, one append per person, never by the author; at three the recipe
  /// is trusted enough to publish itself.
  final List<String> verifiedBy;

  /// For a variant: the id of the recipe this is a version of — either a
  /// catalogue dish or another family recipe. Null for originals.
  final String? baseId;

  /// For a variant: what is different about this one, in the author's words.
  final String? variantLabel;

  /// True when this recipe is a version of another recipe rather than an
  /// original submission.
  bool get isVariant => baseId != null && baseId!.isNotEmpty;

  /// How many independent cooks back this recipe.
  int get verificationCount => verifiedBy.length;

  /// Whether [uid] has already vouched — one vouch per person, ever.
  bool verifiedByUser(String? uid) => uid != null && verifiedBy.contains(uid);

  /// The steps as they were entered: one line per step. Older submissions
  /// (before the form had per-step fields) typed them into one blob and
  /// newline joins still round-trip through it.
  List<String> get stepLines => stepsText
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);

  /// The ingredient lines as entered: one per line, blanks dropped. The
  /// detail screen inlines this same parse; having it here means cook mode
  /// and the bridge read the same list rather than a second copy.
  List<String> get ingredientLines => ingredientsText
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);

  /// Download URL of the uploaded photo/video, if any. Media lives in
  /// Storage under the author's path; Firestore stores only the URL.
  final String? mediaUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// The name shown in lists: the Amharic title when present, since the
  /// archive is primarily for an Ethiopian audience.
  String get displayName => titleAm.isNotEmpty ? titleAm : title;
}

enum FamilyRecipeStatus { draft, pending, published }

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
