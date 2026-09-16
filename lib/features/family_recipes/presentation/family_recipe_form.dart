import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/analytics_service.dart';
import '../../../core/services/local_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../../auth/domain/auth_providers.dart';
import '../../recipes/domain/recipe_providers.dart';
import '../../regions/presentation/taste_ethiopia_screen.dart';
import '../data/family_recipe_repository.dart';
import '../domain/family_recipe.dart';
import '../domain/family_recipe_providers.dart';

/// 19-upload — recording a family recipe.
///
/// Submitted as `pending`, never `published`: nothing user-written reaches the
/// public catalogue without review. The draft is saved locally as it is typed,
/// because these are long forms and losing one would be losing someone's
/// grandmother's recipe.
///
/// The same form edits an existing [editId] recipe (own drafts and pending
/// submissions; the rules gate the write). When editing, the local draft
/// restore is skipped so an unfinished new recipe cannot clobber the one
/// actually being edited.
class FamilyRecipeForm extends ConsumerStatefulWidget {
  const FamilyRecipeForm({super.key, this.editId});

  final String? editId;

  @override
  ConsumerState<FamilyRecipeForm> createState() => _FamilyRecipeFormState();
}

class _FamilyRecipeFormState extends ConsumerState<FamilyRecipeForm> {
  static const String _draftKey = 'family_recipe.draft';

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _nameAm = TextEditingController();
  final _teacher = TextEditingController();
  final _ingredients = TextEditingController();
  final _story = TextEditingController();

  /// One controller per step, matching the prototype's repeatable `addStep`
  /// rows. Joined with newlines into the stored `stepsText`.
  final List<TextEditingController> _steps = [TextEditingController()];

  /// Minted once and persisted with the draft. The submission path, the
  /// outbox idempotency key and the final document all derive from it.
  String _recipeId = FamilyRecipeRepository.newRecipeId();

  String? _regionId;
  String? _mediaPath;

  /// Already-uploaded media URL carried over from an edit; re-submitting must
  /// not re-upload or drop it.
  String? _existingMediaUrl;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.editId == null) {
      _restoreDraft();
    } else {
      _loadForEdit(widget.editId!);
    }
  }

  Future<void> _loadForEdit(String recipeId) async {
    final mine = await ref.read(myFamilyRecipesProvider.future);
    if (!mounted) return;
    final recipe = mine.where((r) => r.id == recipeId).firstOrNull;
    if (recipe == null) {
      // Not ours (or gone): fall back to a blank form rather than dying.
      return;
    }
    _recipeId = recipe.id;
    _name.text = recipe.title;
    _nameAm.text = recipe.titleAm;
    _teacher.text = recipe.teacherName;
    _ingredients.text = recipe.ingredientsText;
    _story.text = recipe.story;
    _existingMediaUrl = recipe.mediaUrl;
    setState(() {
      _regionId = recipe.regionId;
      _mediaPath = null;
      _steps
        ..clear()
        ..addAll([
          for (final line in recipe.stepLines)
            TextEditingController(text: line),
          if (recipe.stepLines.isEmpty) TextEditingController(),
        ]);
    });
  }

  void _restoreDraft() {
    final draft =
        ref.read(localStoreProvider).readJson(LocalStore.boxMisc, _draftKey);
    if (draft == null) return;

    _recipeId = draft['id'] as String? ?? _recipeId;
    _name.text = draft['title'] as String? ?? '';
    _nameAm.text = draft['titleAm'] as String? ?? '';
    _teacher.text = draft['teacherName'] as String? ?? '';
    _ingredients.text = draft['ingredientsText'] as String? ?? '';
    _story.text = draft['story'] as String? ?? '';
    setState(() {
      _regionId = draft['regionId'] as String?;
      _mediaPath = draft['mediaPath'] as String?;
      _steps
        ..clear()
        ..addAll([
          for (final line in draft['stepLines'] as List? ?? const <String>[])
            TextEditingController(text: line as String),
          if ((draft['stepLines'] as List? ?? const []).isEmpty)
            TextEditingController(),
        ]);
    });
  }

  Future<void> _saveDraft() async {
    if (widget.editId != null) return;
    await ref.read(localStoreProvider).writeJson(
          LocalStore.boxMisc,
          _draftKey,
          _payload(status: FamilyRecipeStatus.draft.name)
            ..['mediaPath'] = _mediaPath
            ..remove('stepsText'),
        );
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _mediaPath = picked.path);
    await _saveDraft();
  }

  void _addStep() {
    setState(() => _steps.add(TextEditingController()));
    _saveDraft();
  }

  void _removeStep(int index) {
    setState(() {
      _steps[index].dispose();
      _steps.removeAt(index);
      if (_steps.isEmpty) _steps.add(TextEditingController());
    });
    _saveDraft();
  }

  Map<String, dynamic> _payload({required String status}) => {
        'id': _recipeId,
        'title': _name.text.trim(),
        'titleAm': _nameAm.text.trim(),
        'teacherName': _teacher.text.trim(),
        'ingredientsText': _ingredients.text.trim(),
        // The stored shape stays line-per-step: published-recipe rendering and
        // the moderation view both read `stepsText`, and old submissions keep
        // working unchanged.
        'stepsText': [
          for (final controller in _steps) controller.text.trim(),
        ].where((line) => line.isNotEmpty).join('\n'),
        'teacherNote': '',
        'regionId': _regionId,
        'story': _story.text.trim(),
        'authorId': ref.read(currentUidProvider),
        'status': status,
        if (_existingMediaUrl != null) 'mediaUrl': _existingMediaUrl,
      };

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final uid = ref.read(currentUidProvider);
    if (uid == null) return;

    setState(() => _submitting = true);

    final repo = ref.read(familyRecipeRepositoryProvider);
    final payload = _payload(status: FamilyRecipeStatus.pending.name);

    // Media first, when there is any: the URL is part of the document, and
    // an upload failure should stop the submission rather than strand a
    // recipe pointing at nothing.
    final mediaPath = _mediaPath;
    if (mediaPath != null) {
      final upload = await repo.uploadMedia(
        uid: uid,
        file: File(mediaPath),
      );
      final url = upload.valueOrNull;
      if (url == null) {
        if (!mounted) return;
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).uploadMediaFailed,
            ),
          ),
        );
        return;
      }
      payload['mediaUrl'] = url;
    }

    final result = await repo.submit(payload: payload);

    if (result.isErr) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).errorServer),
        ),
      );
      return;
    }

    await ref.read(localStoreProvider).deleteKey(LocalStore.boxMisc, _draftKey);
    unawaited(
      ref.read(analyticsServiceProvider).logFamilyRecipeCreated(),
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).uploadNote)),
    );
    unawaited(maybePop(context));
  }

  /// Pops whatever pushed this form without reaching for the router: the form
  /// is always entered through a push, so the root navigator's pop is the
  /// same transition — and it keeps this testable without a GoRouter.
  Future<void> maybePop(BuildContext context) async {
    if (context.mounted) Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _name.dispose();
    _nameAm.dispose();
    _teacher.dispose();
    _ingredients.dispose();
    _story.dispose();
    for (final controller in _steps) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final regions = ref.watch(regionsProvider).valueOrNull ?? const <Region>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.editId == null ? l10n.uploadH1 : l10n.fEditRecipe,
        ),
        actions: [
          if (widget.editId == null)
            TextButton(
              onPressed: _saveDraft,
              child: Text(l10n.actionSave),
            ),
        ],
      ),
      body: Stack(
        children: [
          const AmbientBackground(),
          Form(
            key: _formKey,
            onChanged: _saveDraft,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.md,
                AppSpacing.gutter,
                AppSpacing.screenBottom,
              ),
              children: [
                Text(
                  l10n.uploadSub,
                  style: AppTypography.bodyMedium
                      .copyWith(color: palette.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xxl),
                _Field(
                  fieldKey: const Key('fr-name'),
                  controller: _name,
                  label: l10n.fName,
                  required: true,
                  l10n: l10n,
                ),
                _Field(
                  fieldKey: const Key('fr-name-am'),
                  controller: _nameAm,
                  label: l10n.fNameAm,
                  l10n: l10n,
                ),
                _Field(
                  fieldKey: const Key('fr-teacher'),
                  controller: _teacher,
                  label: l10n.fWho,
                  hint: l10n.fWhoP,
                  required: true,
                  l10n: l10n,
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  initialValue: _regionId,
                  decoration: InputDecoration(hintText: l10n.regionTitle),
                  items: [
                    for (final region in regions)
                      DropdownMenuItem(
                        value: region.id,
                        child: Text(
                          region.localisedName(
                            amharic: ref.read(isAmharicProvider),
                          ),
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _regionId = value),
                ),
                const SizedBox(height: AppSpacing.md),
                _PhotoPicker(
                  mediaPath: _mediaPath,
                  onPick: _pickPhoto,
                  l10n: l10n,
                  palette: palette,
                ),
                _Field(
                  fieldKey: const Key('fr-ingredients'),
                  controller: _ingredients,
                  label: l10n.fIngredients,
                  hint: l10n.fIngredientsP,
                  lines: 3,
                  l10n: l10n,
                ),
                _Field(
                  fieldKey: const Key('fr-story'),
                  controller: _story,
                  label: l10n.story,
                  lines: 4,
                  l10n: l10n,
                ),

                // --- steps: one field per step, add/remove ---------------
                Eyebrow(l10n.fSteps),
                const SizedBox(height: AppSpacing.xs),
                for (var i = 0; i < _steps.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            key: ValueKey('fr-step-$i'),
                            controller: _steps[i],
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: '${i + 1}.',
                            ),
                            validator: i == 0
                                ? (value) =>
                                    (value == null || value.trim().isEmpty)
                                        ? l10n.validationNameRequired
                                        : null
                                : null,
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.fRemoveStep,
                          onPressed: _steps.length > 1 || i > 0
                              ? () => _removeStep(i)
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                      ],
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _addStep,
                    icon: const Icon(Icons.add),
                    label: Text(l10n.fAddStep),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                FlameButton(
                  label: l10n.uploadCta,
                  loading: _submitting,
                  onPressed: _submitting ? null : _submit,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.uploadNote,
                  textAlign: TextAlign.center,
                  style: AppTypography.caption
                      .copyWith(color: palette.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.mediaPath,
    required this.onPick,
    required this.l10n,
    required this.palette,
  });

  final String? mediaPath;
  final VoidCallback onPick;
  final AppLocalizations l10n;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final path = mediaPath;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(l10n.fPhoto),
          const SizedBox(height: AppSpacing.xs),
          GestureDetector(
            onTap: onPick,
            child: Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: palette.glassRaised,
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: palette.divider),
              ),
              child: path != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      child: Image.file(
                        File(path),
                        fit: BoxFit.cover,
                      ),
                    )
                  : Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_a_photo_outlined),
                          const SizedBox(width: AppSpacing.sm),
                          Text(l10n.fPhotoHint),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.l10n,
    this.fieldKey,
    this.hint,
    this.lines = 1,
    this.required = false,
  });

  /// Stable handle for tests; hint text is not a findable Text widget.
  final Key? fieldKey;
  final TextEditingController controller;
  final String label;
  final AppLocalizations l10n;
  final String? hint;
  final int lines;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(label),
          const SizedBox(height: AppSpacing.xs),
          TextFormField(
            key: fieldKey,
            controller: controller,
            maxLines: lines,
            decoration: InputDecoration(hintText: hint ?? label),
            validator: required
                ? (value) => (value == null || value.trim().isEmpty)
                    ? l10n.validationNameRequired
                    : null
                : null,
          ),
        ],
      ),
    );
  }
}
