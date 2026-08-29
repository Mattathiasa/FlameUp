import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/cache/outbox.dart';
import '../../../core/cache/pending_mutation.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/services/local_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../../auth/domain/auth_providers.dart';
import '../../regions/presentation/taste_ethiopia_screen.dart';

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

  String? _regionId;
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

    _name.text = draft['title'] as String? ?? '';
    _nameAm.text = draft['titleAm'] as String? ?? '';
    _teacher.text = draft['teacherName'] as String? ?? '';
    _story.text = draft['story'] as String? ?? '';
    _steps.text = draft['stepsText'] as String? ?? '';
    setState(() => _regionId = draft['regionId'] as String?);
  }

  Future<void> _saveDraft() async {
    await ref.read(localStoreProvider).writeJson(
          LocalStore.boxMisc,
          _draftKey,
          _payload(status: 'draft'),
        );
  }

  Map<String, dynamic> _payload({required String status}) => {
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

    await ref.read(outboxProvider).enqueue(
          PendingMutation(
            kind: MutationKind.familyRecipe,
            path: FirestorePaths.familyRecipes,
            // Pending, not published: two cooks from the region review it
            // before it goes live.
            payload: _payload(status: 'pending'),
          ),
        );

    await ref.read(localStoreProvider).deleteKey(LocalStore.boxMisc, _draftKey);

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
                  value: _regionId,
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
