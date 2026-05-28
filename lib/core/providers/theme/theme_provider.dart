import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/services/storage_service.dart';

// ---------------------------------------------------------------------------
// Theme Mode Provider — persists dark / light choice across sessions
// ---------------------------------------------------------------------------

const _kThemeModeKey = 'app_theme_mode';

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final stored = StorageService.getString(_kThemeModeKey);
    return stored == 'light' ? ThemeMode.light : ThemeMode.dark;
  }

  bool get isDark => state == ThemeMode.dark;

  void setDark() => _set(ThemeMode.dark);
  void setLight() => _set(ThemeMode.light);

  void toggle() =>
      _set(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);

  Future<void> _set(ThemeMode mode) async {
    state = mode;
    await StorageService.setString(
      _kThemeModeKey,
      mode == ThemeMode.dark ? 'dark' : 'light',
    );
  }
}
