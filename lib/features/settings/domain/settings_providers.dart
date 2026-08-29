import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/local_store.dart';

/// The two languages the design ships copy for. Amharic is left-to-right —
/// nothing here should ever set an RTL text direction.
enum AppLanguage {
  english('en'),
  amharic('am');

  const AppLanguage(this.code);
  final String code;

  Locale get locale => Locale(code);

  static AppLanguage fromCode(String? code) => switch (code) {
        'am' => AppLanguage.amharic,
        _ => AppLanguage.english,
      };
}

/// Theme choice, persisted locally so the very first frame is already correct.
/// The design is dark-first; [ThemeMode.system] is the default so the device
/// decides, and the settings screen can pin either.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final stored = ref.watch(localStoreProvider).getString(PrefKeys.themeMode);
    return switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> set(ThemeMode mode) async {
    await ref.read(localStoreProvider).setString(PrefKeys.themeMode, mode.name);
    state = mode;
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

class LanguageController extends Notifier<AppLanguage> {
  @override
  AppLanguage build() {
    return AppLanguage.fromCode(
      ref.watch(localStoreProvider).getString(PrefKeys.locale),
    );
  }

  Future<void> set(AppLanguage language) async {
    await ref
        .read(localStoreProvider)
        .setString(PrefKeys.locale, language.code);
    state = language;
  }
}

final languageProvider =
    NotifierProvider<LanguageController, AppLanguage>(LanguageController.new);
