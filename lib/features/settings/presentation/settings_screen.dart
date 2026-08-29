import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/cache/sync_status.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../../auth/domain/auth_controller.dart';
import '../../auth/domain/auth_providers.dart';
import '../domain/settings_providers.dart';

/// 27-settings.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authUserProvider).valueOrNull;
    final isGuest = ref.watch(isGuestProvider);
    final themeMode = ref.watch(themeModeProvider);
    final language = ref.watch(languageProvider);
    final sync = ref.watch(syncStatusProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.setH1)),
      body: Stack(
        children: [
          const AmbientBackground(),
          ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.md,
              AppSpacing.gutter,
              AppSpacing.screenBottom,
            ),
            children: [
              Eyebrow(l10n.setAccount),
              const SizedBox(height: AppSpacing.sm),
              GlassPanel(
                blur: false,
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.displayName ?? l10n.guestBadge,
                      style: AppTypography.titleMedium
                          .copyWith(color: palette.textPrimary),
                    ),
                    if (user?.email != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        user!.email!,
                        style: AppTypography.caption
                            .copyWith(color: palette.textSecondary),
                      ),
                    ],
                    if (isGuest) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        l10n.upgradeSubtitle,
                        style: AppTypography.caption
                            .copyWith(color: palette.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      FlameButton(
                        label: l10n.upgradeCta,
                        height: 46,
                        sheen: false,
                        onPressed: () => context.push(Routes.upgradeAccount),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Eyebrow(l10n.setApp),
              const SizedBox(height: AppSpacing.sm),
              GlassPanel(
                blur: false,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.sm,
                ),
                child: Column(
                  children: [
                    _Segmented<ThemeMode>(
                      label: l10n.setTheme,
                      value: themeMode,
                      options: {
                        ThemeMode.dark: l10n.setDarkL,
                        ThemeMode.light: l10n.setLightL,
                        ThemeMode.system: l10n.actionOk,
                      },
                      onChanged: (mode) =>
                          ref.read(themeModeProvider.notifier).set(mode),
                    ),
                    Divider(color: palette.divider, height: 1),
                    _Segmented<AppLanguage>(
                      label: l10n.setLang,
                      value: language,
                      options: const {
                        AppLanguage.english: 'English',
                        AppLanguage.amharic: 'አማርኛ',
                      },
                      onChanged: (lang) =>
                          ref.read(languageProvider.notifier).set(lang),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Eyebrow(l10n.setKitchen),
              const SizedBox(height: AppSpacing.sm),
              GlassPanel(
                blur: false,
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Row(
                  children: [
                    Icon(
                      sync.isOffline ? Icons.cloud_off : Icons.cloud_done,
                      size: 18,
                      color: sync.isOffline
                          ? palette.textTertiary
                          : AppColors.green,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        // Said plainly, because "N changes waiting" is what a
                        // user needs to know before uninstalling or switching
                        // devices.
                        sync.hasPendingWork
                            ? '${sync.pendingCount} · ${l10n.offBanner}'
                            : l10n.setOffline,
                        style: AppTypography.bodySmall
                            .copyWith(color: palette.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Eyebrow(l10n.setAbout),
              const SizedBox(height: AppSpacing.sm),
              GlassPanel(
                blur: false,
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  l10n.setVersion,
                  style: AppTypography.bodySmall
                      .copyWith(color: palette.textSecondary),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              SizedBox(
                height: 50,
                child: OutlinedButton(
                  onPressed: () =>
                      ref.read(authControllerProvider.notifier).signOut(),
                  child: Text(l10n.signOut),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style:
                  AppTypography.bodyMedium.copyWith(color: palette.textPrimary),
            ),
          ),
          for (final entry in options.entries)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.xs),
              child: PillChip(
                label: entry.value,
                selected: entry.key == value,
                onTap: () => onChanged(entry.key),
              ),
            ),
        ],
      ),
    );
  }
}
