import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/analytics_service.dart';
import '../../../core/services/local_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../../auth/domain/auth_providers.dart';
import '../../regions/presentation/taste_ethiopia_screen.dart';
import '../data/family_recipe_repository.dart';
import '../domain/family_recipe.dart';

/// 19-upload — recording a family recipe.
///
/// Submitted as `pending`, never `published`: nothing user-written reaches the
/// public catalogue without review. The draft is saved locally as it is typed,
/// because these are long forms and losing one would be losing someone's
/// grandmother's recipe.
class FamilyRecipeForm extends ConsumerStatefulWidget {
  const FamilyRecipeForm({super.key});

  @override
  ConsumerState<FamilyRecipeForm> createState() => _FamilyRecipeFormState();
}

class _FamilyRecipeFormState extends ConsumerState<FamilyRecipeForm> {
  static const String _draftKey = 'family_recipe.draft';

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _nameAm = TextEditingController();
  final _teacher = TextEditingController();
  final _story = TextEditingController();
  final _steps = TextEditingController();

  /// Minted once and persisted with the draft. The submission path, the
  /// outbox idempotency key and the final document all derive from it.
  String _recipeId = FamilyRecipeRepository.newRecipeId();

  String? _regionId;
  String? _mediaPath;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _restoreDraft();
  }

  void _restoreDraft() {
    final draft =
        ref.read(localStoreProvider).readJson(LocalStore.boxMisc, _draftKey);
    if (draft == null) return;

    _recipeId = draft['id'] as String? ?? _recipeId;
    _name.text = draft['title'] as String? ?? '';
    _nameAm.text = draft['titleAm'] as String? ?? '';
    _teacher.text = draft['teacherName'] as String? ?? '';
    _story.text = draft['story'] as String? ?? '';
    _steps.text = draft['stepsText'] as String? ?? '';
    setState(() {
      _regionId = draft['regionId'] as String?;
      _mediaPath = draft['mediaPath'] as String?;
    });
  }

  Future<void> _saveDraft() async {
    await ref.read(localStoreProvider).writeJson(
          LocalStore.boxMisc,
          _draftKey,
          _payload(status: FamilyRecipeStatus.draft.name)
            ..['mediaPath'] = _mediaPath,
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

  Map<String, dynamic> _payload({required String status}) => {
        'id': _recipeId,
        'title': _name.text.trim(),
        'titleAm': _nameAm.text.trim(),
        'teacherName': _teacher.text.trim(),
        'regionId': _regionId,
        'story': _story.text.trim(),
        'stepsText': _steps.text.trim(),
        'authorId': ref.read(currentUidProvider),
        'status': status,
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
    context.pop();
  }

  @override
  void dispose() {
    _name.dispose();
    _nameAm.dispose();
    _teacher.dispose();
    _story.dispose();
    _steps.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final regions = ref.watch(regionsProvider).valueOrNull ?? const <Region>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.uploadH1),
        actions: [
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
                  controller: _name,
                  label: l10n.fName,
                  required: true,
                  l10n: l10n,
                ),
                _Field(controller: _nameAm, label: l10n.fNameAm, l10n: l10n),
                _Field(
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
                        child: Text(region.name),
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
                  controller: _story,
                  label: l10n.story,
                  lines: 4,
                  l10n: l10n,
                ),
                _Field(
                  controller: _steps,
                  label: l10n.fSteps,
                  hint: l10n.fStepsP,
                  lines: 8,
                  required: true,
                  l10n: l10n,
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
    this.hint,
    this.lines = 1,
    this.required = false,
  });

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
