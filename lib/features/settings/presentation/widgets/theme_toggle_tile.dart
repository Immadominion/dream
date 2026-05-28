import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rive/rive.dart';

import '../../../../core/providers/theme/theme_provider.dart';
import '../../../../core/theme/dream_colors.dart';

// ---------------------------------------------------------------------------
// Rive-animated Dark / Light mode toggle tile for Settings
// ---------------------------------------------------------------------------

class ThemeToggleTile extends ConsumerStatefulWidget {
  const ThemeToggleTile({super.key});

  @override
  ConsumerState<ThemeToggleTile> createState() => _ThemeToggleTileState();
}

class _ThemeToggleTileState extends ConsumerState<ThemeToggleTile> {
  /// Boolean input "isDark" from the Rive state machine.
  BooleanInput? _isDarkInput;

  // ── Called when the Rive file finishes loading ────────────────────────────

  void _onRiveLoaded(RiveLoaded state) {
    _isDarkInput = state.controller.stateMachine.boolean('isDark');
    final isDark = ref.read(themeModeProvider) == ThemeMode.dark;
    _isDarkInput?.value = isDark;
  }

  // ── Tap handler ───────────────────────────────────────────────────────────

  void _onTap() {
    ref.read(themeModeProvider.notifier).toggle();
    // Mirror new state into Rive after toggle
    final isDark = ref.read(themeModeProvider) == ThemeMode.dark;
    _isDarkInput?.value = isDark;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dreamColors;
    final themeMode = ref.watch(themeModeProvider);

    // Keep Rive in sync when provider changes from outside.
    ref.listen<ThemeMode>(themeModeProvider, (_, next) {
      _isDarkInput?.value = next == ThemeMode.dark;
    });

    return GestureDetector(
      onTap: _onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: EdgeInsets.only(bottom: 1.h),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: c.surfaceVariant,
          border: Border.all(color: c.stroke, width: 0.5),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          children: [
            // Rive animation as the toggle icon
            SizedBox(
              width: 36.w,
              height: 36.w,
              child: RiveWidgetBuilder(
                fileLoader: FileLoader.fromAsset(
                  'assets/animations/theme-switch.riv',
                  riveFactory: Factory.rive,
                ),
                stateMachineSelector: const StateMachineNamed(
                  'State Machine 1',
                ),
                onLoaded: _onRiveLoaded,
                builder: (context, riveState) {
                  if (riveState is RiveLoaded) {
                    return RiveWidget(
                      controller: riveState.controller,
                      fit: Fit.contain,
                    );
                  }
                  // Show a small icon while loading
                  return Icon(
                    Icons.dark_mode_rounded,
                    color: c.muted,
                    size: 22.sp,
                  );
                },
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Appearance',
                    style: TextStyle(
                      color: c.onSurface,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 1.h),
                  Text(
                    themeMode == ThemeMode.dark ? 'Dark mode' : 'Light mode',
                    style: TextStyle(color: c.muted, fontSize: 11.sp),
                  ),
                ],
              ),
            ),
            // Subtle chevron hint
            Icon(Icons.chevron_right_rounded, color: c.muted, size: 18.sp),
          ],
        ),
      ),
    );
  }
}
