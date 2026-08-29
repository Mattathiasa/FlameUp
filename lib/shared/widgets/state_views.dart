import 'package:flutter/material.dart';

import '../../core/errors/failure.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../l10n/generated/app_localizations.dart';
import 'flame_button.dart';
import 'flame_icon.dart';
import 'glass_panel.dart';

/// Resolves a [Failure]'s message key to localised copy.
///
/// Repositories never carry a user-facing string; they carry a key. This is
/// the single place that turns one into words, which is why a raw
/// `FirebaseException` can never reach a screen.
String failureMessage(BuildContext context, Failure failure) {
  final l = AppLocalizations.of(context);
  return switch (failure.messageKey) {
    'errorOffline' => l.errorOffline,
    'errorServer' => l.errorServer,
    'errorPermission' => l.errorPermission,
    'errorNotFound' => l.errorNotFound,
    'errorCache' => l.errorCache,
    'errorCancelled' => l.errorCancelled,
    'errorTimeout' => l.errorTimeout,
    'errorBadResponse' => l.errorBadResponse,
    'errorInvalidRequest' => l.errorInvalidRequest,
    'errorConflict' => l.errorConflict,
    'authErrorInvalidEmail' => l.authErrorInvalidEmail,
    'authErrorUserDisabled' => l.authErrorUserDisabled,
    'authErrorInvalidCredentials' => l.authErrorInvalidCredentials,
    'authErrorEmailInUse' => l.authErrorEmailInUse,
    'authErrorWeakPassword' => l.authErrorWeakPassword,
    'authErrorOperationNotAllowed' => l.authErrorOperationNotAllowed,
    'authErrorRequiresRecentLogin' => l.authErrorRequiresRecentLogin,
    'authErrorTooManyRequests' => l.authErrorTooManyRequests,
    'authErrorAccountExistsDifferentCredential' =>
      l.authErrorAccountExistsDifferentCredential,
    'authErrorCredentialInUse' => l.authErrorCredentialInUse,
    'authErrorProviderAlreadyLinked' => l.authErrorProviderAlreadyLinked,
    'authErrorGeneric' => l.authErrorGeneric,
    'authErrorSignedOut' => l.authErrorSignedOut,
    _ => l.errorUnknown,
  };
}

/// Shown when a read genuinely has nothing — no cache and no network.
///
/// Rare by design: the offline-first layer keeps showing cached data through a
/// failed refresh, so reaching this means there was never anything to show.
class ErrorView extends StatelessWidget {
  const ErrorView({required this.failure, this.onRetry, super.key});

  final Failure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FlameIcon(size: 44, color: Color(0xFF8E1B0F)),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              failure is NetworkFailure ? l.offH1 : l.errH1,
              style: AppTypography.headlineSmall
                  .copyWith(color: palette.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              failureMessage(context, failure),
              style: AppTypography.bodyMedium
                  .copyWith(color: palette.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null && failure.isRetryable) ...[
              const SizedBox(height: AppSpacing.xxxl),
              FlameButton(
                label: l.retry,
                onPressed: onRetry,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shown when a read succeeded but returned nothing.
class EmptyView extends StatelessWidget {
  const EmptyView({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: palette.fieldFill,
                borderRadius: BorderRadius.circular(AppRadii.xxl),
              ),
              child: Center(
                child: FlameIcon(size: 28, color: palette.textTertiary),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              title,
              style:
                  AppTypography.titleLarge.copyWith(color: palette.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: AppTypography.bodyMedium
                  .copyWith(color: palette.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: AppSpacing.xxxl),
              FlameButton(
                label: actionLabel!,
                onPressed: onAction,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A skeleton block, shown only when there is genuinely nothing cached.
///
/// The offline-first layer means most "loading" is really "showing cached
/// content while refreshing", which uses [StaleBanner] instead — a spinner over
/// content the user is already reading would be a regression, not a courtesy.
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({
    this.width,
    this.height = 16,
    this.borderRadius = AppRadii.smAll,
    super.key,
  });

  final double? width;
  final double height;
  final BorderRadius borderRadius;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(
              palette.fieldFill,
              palette.glassRaised,
              _controller.value,
            ),
            borderRadius: widget.borderRadius,
          ),
        ),
      ),
    );
  }
}

/// A quiet banner saying the content below is saved data, not live.
///
/// This is what makes offline-first honest: the user keeps their content and
/// is told plainly that it may be out of date, instead of being shown stale
/// data dressed up as current.
class StaleBanner extends StatelessWidget {
  const StaleBanner({
    required this.message,
    this.onRetry,
    this.pendingCount = 0,
    super.key,
  });

  final String message;
  final VoidCallback? onRetry;

  /// Writes queued while offline, surfaced as "N will sync".
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return GlassPanel(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.gutter,
        vertical: AppSpacing.sm,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      borderRadius: AppRadii.mdAll,
      blur: false,
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined, size: 16, color: palette.textTertiary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              pendingCount > 0 ? '$message · $pendingCount waiting' : message,
              style:
                  AppTypography.caption.copyWith(color: palette.textSecondary),
            ),
          ),
          if (onRetry != null)
            GestureDetector(
              onTap: onRetry,
              child: Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: Text(
                  AppLocalizations.of(context).retry,
                  style: AppTypography.label.copyWith(color: AppColors.accent),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
