import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notifier for shell bottom navigation visibility.
class BottomNavVisibilityNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void setVisible(bool visible) => state = visible;

  void show() => state = true;

  void hide() => state = false;
}

final bottomNavVisibilityProvider =
    NotifierProvider<BottomNavVisibilityNotifier, bool>(
      BottomNavVisibilityNotifier.new,
    );

/// Notifier for bottom navigation index
class BottomNavIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) {
    state = index;
    ref.read(bottomNavVisibilityProvider.notifier).show();
  }

  void reset() => state = 0;
}

/// Provider for the current bottom navigation index
final bottomNavIndexProvider = NotifierProvider<BottomNavIndexNotifier, int>(
  BottomNavIndexNotifier.new,
);

/// Provider to reset navigation state when switching tabs
/// This can be watched/read in the shell to trigger side effects if needed
final navigationResetProvider = Provider<void>((ref) {
  // Logic to handle navigation resets if any
  // Currently a placeholder to satisfy MainShell initialization
});

/// Notifier for bottom search bar visibility
class BottomSearchBarVisibilityNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void setVisible(bool visible) => state = visible;

  void show() => state = true;

  void hide() => state = false;

  void toggle() => state = !state;
}

/// Controls the visibility of the global bottom search bar
/// Defaults to true (visible)
final bottomSearchBarVisibilityProvider =
    NotifierProvider<BottomSearchBarVisibilityNotifier, bool>(
      BottomSearchBarVisibilityNotifier.new,
    );
