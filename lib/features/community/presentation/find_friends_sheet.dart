import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart' show Share;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../../auth/domain/auth_providers.dart';
import '../data/community_repository.dart';
import '../domain/directory_user.dart';

/// Finding a friend: by name in the directory, or by the code they shared.
///
/// A sheet rather than a screen: adding someone is a moment inside the friends
/// list, not a destination, and a sheet keeps the list you were reading one
/// swipe away.
class FindFriendsSheet extends ConsumerStatefulWidget {
  const FindFriendsSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const FindFriendsSheet(),
      );

  @override
  ConsumerState<FindFriendsSheet> createState() => _FindFriendsSheetState();
}

class _FindFriendsSheetState extends ConsumerState<FindFriendsSheet> {
  final _search = TextEditingController();
  final _code = TextEditingController();

  List<DirectoryUser> _results = const [];
  DirectoryUser? _codeMatch;
  String? _message;
  bool _busy = false;

  // The uid currently being sent a request to, so only that row shows its
  // spinner rather than the whole sheet going amber.
  String? _requestingUid;

  @override
  void dispose() {
    _search.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _doSearch() async {
    final query = _search.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _busy = true;
      _message = null;
      _codeMatch = null;
    });

    final result =
        await ref.read(communityRepositoryProvider).searchDirectory(query);

    if (!mounted) return;
    setState(() {
      _busy = false;
      _results = result.valueOrNull ?? const [];
      if (result.isErr) {
        _message = AppLocalizations.of(context).errorServer;
      }
    });
  }

  Future<void> _doCodeLookup() async {
    final code = _code.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _busy = true;
      _message = null;
      _results = const [];
    });

    final result =
        await ref.read(communityRepositoryProvider).findByFriendCode(code);

    if (!mounted) return;
    setState(() {
      _busy = false;
      _codeMatch = result.valueOrNull;
      if (result.isErr) {
        _message = AppLocalizations.of(context).errorServer;
      }
    });
  }

  Future<void> _sendRequest(DirectoryUser person) async {
    final user = ref.read(authUserProvider).valueOrNull;
    if (user == null || _requestingUid != null) return;

    setState(() => _requestingUid = person.uid);

    // Publish our card first: the recipient's accept flow reads the sender's
    // name from the request document, and the directory entry is what makes
    // this user findable in turn. Both sides of the loop need it.
    final repo = ref.read(communityRepositoryProvider);
    await repo.publishToDirectory(
      uid: user.uid,
      displayName: user.displayName ?? '',
    );

    final result = await repo.sendFriendRequest(
      fromUid: user.uid,
      fromName: user.displayName ?? '',
      toUid: person.uid,
    );

    if (!mounted) return;
    setState(() => _requestingUid = null);

    final l10n = AppLocalizations.of(context);
    if (result.isOk) {
      setState(() {
        _message = l10n.requestSent;
        _results = _results.where((r) => r.uid != person.uid).toList();
        if (_codeMatch?.uid == person.uid) _codeMatch = null;
      });
    } else {
      log('sendFriendRequest failed: ${result.failureOrNull}', name: 'friends');
      setState(() => _message = l10n.errorServer);
    }
  }

  Future<void> _shareMyCode() async {
    final user = ref.read(authUserProvider).valueOrNull;
    if (user == null) return;

    // Captured before the awaits: this context does not survive async gaps.
    final l10n = AppLocalizations.of(context);

    final repo = ref.read(communityRepositoryProvider);
    await repo.publishToDirectory(
      uid: user.uid,
      displayName: user.displayName ?? '',
    );

    final code = DirectoryUser.friendCodeOf(user.uid);
    await Share.share(l10n.inviteShareText(code));
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authUserProvider).valueOrNull;
    final myCode =
        user?.uid == null ? null : DirectoryUser.friendCodeOf(user!.uid);

    return Padding(
      // The view inset keeps the sheet above the keyboard when typing.
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        minChildSize: 0.5,
        builder: (context, controller) => Container(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadii.xl),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.lg,
            AppSpacing.gutter,
            AppSpacing.screenBottom,
          ),
          child: ListView(
            controller: controller,
            children: [
              Text(
                l10n.findFriendsTitle,
                style: AppTypography.headlineSmall
                    .copyWith(color: palette.textPrimary),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.findFriendsSub,
                style: AppTypography.bodyMedium
                    .copyWith(color: palette.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),

              // My code -----------------------------------------------------
              GlassPanel(
                blur: false,
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Eyebrow(l10n.myFriendCode),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            myCode ?? '--',
                            style: AppTypography.headlineSmall.copyWith(
                              color: palette.textPrimary,
                              letterSpacing: 4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.shareCode,
                      onPressed: _shareMyCode,
                      icon: const Icon(Icons.ios_share, size: 20),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // By code ------------------------------------------------------
              Eyebrow(l10n.addByCode),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _code,
                      textCapitalization: TextCapitalization.characters,
                      onSubmitted: (_) => _doCodeLookup(),
                      decoration: InputDecoration(hintText: l10n.codeHint),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FlameButton(
                    label: l10n.findLabel,
                    expand: false,
                    loading: _busy && _codeMatch == null && _results.isEmpty,
                    onPressed: _doCodeLookup,
                  ),
                ],
              ),
              if (_codeMatch != null) ...[
                const SizedBox(height: AppSpacing.sm),
                _PersonRow(
                  person: _codeMatch!,
                  requesting: _requestingUid == _codeMatch!.uid,
                  onAdd: () => _sendRequest(_codeMatch!),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),

              // By name -----------------------------------------------------
              Eyebrow(l10n.searchByName),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _search,
                onSubmitted: (_) => _doSearch(),
                decoration: InputDecoration(
                  hintText: l10n.searchPh,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search, size: 20),
                    onPressed: _doSearch,
                  ),
                ),
              ),
              if (_results.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                for (final person in _results)
                  _PersonRow(
                    person: person,
                    requesting: _requestingUid == person.uid,
                    onAdd: () => _sendRequest(person),
                  ),
              ],
              if (_results.isEmpty && _search.text.isNotEmpty && !_busy) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l10n.noPeopleFound,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium
                      .copyWith(color: palette.textTertiary),
                ),
              ],

              if (_message != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  _message!,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium
                      .copyWith(color: AppColors.accent),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.person,
    required this.requesting,
    required this.onAdd,
  });

  final DirectoryUser person;
  final bool requesting;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);

    return GlassPanel(
      blur: false,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: palette.glassRaised,
            child: Text(
              person.displayName.characters.first.toUpperCase(),
              style: AppTypography.label.copyWith(color: palette.textPrimary),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              person.displayName,
              style:
                  AppTypography.titleSmall.copyWith(color: palette.textPrimary),
            ),
          ),
          requesting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : TextButton(onPressed: onAdd, child: Text(l10n.add)),
        ],
      ),
    );
  }
}
