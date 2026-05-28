import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../providers/ai_trading_provider.dart';
import '../../providers/copy_trading_provider.dart';
import 'ai_trading_page.dart';
import 'copy_trade_page.dart';
import '../../../../core/theme/dream_colors.dart';

/// Intelligence tab: copy-trading controls and signal automation.
class IntelligenceTabPage extends ConsumerStatefulWidget {
  const IntelligenceTabPage({super.key});

  @override
  ConsumerState<IntelligenceTabPage> createState() =>
      _IntelligenceTabPageState();
}

class _IntelligenceTabPageState extends ConsumerState<IntelligenceTabPage> {
  int _mode = 0;

  @override
  Widget build(BuildContext context) {
    final copyState = ref.watch(copyTradingProvider);
    final aiState = ref.watch(aiTradingProvider);

    // Status indicator only for the active tab
    final copyIndicator = _mode == 0
        ? _CopyDot(
            isActive: copyState.following.isNotEmpty && copyState.isPolling,
          )
        : null;

    final signalIndicator = _mode == 1
        ? _SignalDot(isActive: aiState.isRunning)
        : null;

    return Scaffold(
      backgroundColor: context.dreamColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 6.h),
              child: _ModeSwitch(
                selected: _mode,
                copyIndicator: copyIndicator,
                signalIndicator: signalIndicator,
                onChanged: (value) => setState(() => _mode = value),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _mode,
                children: const [CopyTradePage(), AITradingPage()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  final Widget? copyIndicator;
  final Widget? signalIndicator;

  const _ModeSwitch({
    required this.selected,
    required this.onChanged,
    this.copyIndicator,
    this.signalIndicator,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42.h,
      padding: EdgeInsets.all(4.r),
      decoration: BoxDecoration(
        color: context.dreamColors.surface,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: context.dreamColors.stroke),
      ),
      child: Row(
        children: [
          _ModeButton(
            icon: PhosphorIcons.copy(PhosphorIconsStyle.bold),
            label: 'Copy',
            selected: selected == 0,
            indicator: copyIndicator,
            onTap: () => onChanged(0),
          ),
          SizedBox(width: 4.w),
          _ModeButton(
            icon: PhosphorIcons.sparkle(PhosphorIconsStyle.bold),
            label: 'Signal',
            selected: selected == 1,
            indicator: signalIndicator,
            onTap: () => onChanged(1),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? indicator;

  const _ModeButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.indicator,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(9.r),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: selected
                    ? context.dreamColors.onSurface
                    : context.dreamColors.muted,
                size: 15.r,
              ),
              SizedBox(width: 6.w),
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? context.dreamColors.onSurface
                      : context.dreamColors.muted,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (indicator != null) ...[SizedBox(width: 7.w), indicator!],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Status indicators ──────────────────────────────────────────────────────

class _CopyDot extends StatelessWidget {
  final bool isActive;
  const _CopyDot({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? AppColors.success
        : context.dreamColors.mutedSecondary.withValues(alpha: 0.45);
    return Container(
      width: 6.r,
      height: 6.r,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: isActive
            ? [BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 6.r)]
            : null,
      ),
    );
  }
}

class _SignalDot extends StatelessWidget {
  final bool isActive;
  const _SignalDot({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? AppColors.success
        : context.dreamColors.mutedSecondary.withValues(alpha: 0.45);
    return Container(
      width: 6.r,
      height: 6.r,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: isActive
            ? [BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 6.r)]
            : null,
      ),
    );
  }
}
