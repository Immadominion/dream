import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/intelligence_models.dart';
import '../../providers/ai_trading_provider.dart';

class AgentConfigSheet extends ConsumerStatefulWidget {
  final AIBotConfig initialConfig;

  const AgentConfigSheet({super.key, required this.initialConfig});

  static Future<void> show(BuildContext context, AIBotConfig config) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AgentConfigSheet(initialConfig: config),
    );
  }

  @override
  ConsumerState<AgentConfigSheet> createState() => _AgentConfigSheetState();
}

class _AgentConfigSheetState extends ConsumerState<AgentConfigSheet> {
  int _step = 0;
  late AIBotConfig _config;

  @override
  void initState() {
    super.initState();
    _config = widget.initialConfig;
  }

  void _next() {
    if (_step < 1) {
      HapticFeedback.lightImpact();
      setState(() => _step++);
    }
  }

  void _prev() {
    if (_step > 0) {
      HapticFeedback.lightImpact();
      setState(() => _step--);
    }
  }

  void _save() {
    HapticFeedback.mediumImpact();
    ref.read(aiTradingProvider.notifier).updateConfig(_config);
    Navigator.of(context).pop();
  }

  String get _stepTitle => _step == 0 ? 'Risk profile' : 'Parameters';

  String get _stepSubtitle => _step == 0
      ? 'How aggressively should the agent trade?'
      : 'Fine-tune position sizing and protection.';

  Widget _buildStep() => _step == 0
      ? _RiskStep(
          selected: _config.riskMode,
          onSelect: (r) =>
              setState(() => _config = _config.copyWith(riskMode: r)),
        )
      : _ParamsStep(
          config: _config,
          onChanged: (c) => setState(() => _config = c),
        );

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Container(
      constraints: BoxConstraints(maxHeight: size.height * 0.88),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            child: Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: AppColors.borderDark,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 20.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_step > 0) ...[
                  GestureDetector(
                    onTap: _prev,
                    child: Container(
                      width: 36.r,
                      height: 36.r,
                      margin: EdgeInsets.only(top: 2.h, right: 12.w),
                      decoration: BoxDecoration(
                        color: AppColors.cardDark,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.borderDark),
                      ),
                      child: Icon(
                        PhosphorIcons.arrowLeft(PhosphorIconsStyle.bold),
                        color: AppColors.textSecondaryDark,
                        size: 16.r,
                      ),
                    ),
                  ),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _stepTitle,
                            style: TextStyle(
                              color: AppColors.textPrimaryDark,
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          _StepPills(current: _step),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        _stepSubtitle,
                        style: TextStyle(
                          color: AppColors.textMutedDark,
                          fontSize: 13.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_step == 0) ...[
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Padding(
                      padding: EdgeInsets.only(left: 12.w, top: 2.h),
                      child: Icon(
                        PhosphorIcons.x(PhosphorIconsStyle.bold),
                        color: AppColors.textSecondaryDark,
                        size: 20.r,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Step content
          Flexible(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position:
                      Tween<Offset>(
                        begin: const Offset(0.06, 0),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(parent: anim, curve: Curves.easeOut),
                      ),
                  child: child,
                ),
              ),
              child: KeyedSubtree(key: ValueKey(_step), child: _buildStep()),
            ),
          ),

          // Footer CTA
          Padding(
            padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, safeBottom + 24.h),
            child: GestureDetector(
              onTap: _step == 1 ? _save : _next,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(40.r),
                ),
                alignment: Alignment.center,
                child: Text(
                  _step == 1 ? 'Save Settings' : 'Next',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step pills ─────────────────────────────────────────────────────────────

class _StepPills extends StatelessWidget {
  final int current;
  const _StepPills({required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(2, (i) {
        final isActive = i == current;
        final isDone = i < current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: EdgeInsets.only(left: 4.w),
          width: isActive ? 20.w : 6.w,
          height: 6.h,
          decoration: BoxDecoration(
            color: isDone
                ? AppColors.primary.withValues(alpha: 0.45)
                : isActive
                ? AppColors.primary
                : AppColors.borderDark,
            borderRadius: BorderRadius.circular(3.r),
          ),
        );
      }),
    );
  }
}

// ── Step 1: Risk profile ───────────────────────────────────────────────────

class _RiskStep extends StatelessWidget {
  final RiskMode selected;
  final ValueChanged<RiskMode> onSelect;

  const _RiskStep({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        children: RiskMode.values.map((r) {
          final isSelected = r == selected;
          final (icon, label, desc) = switch (r) {
            RiskMode.conservative => (
              PhosphorIcons.shieldWarning(PhosphorIconsStyle.fill),
              'Conservative',
              'Tight stops, smaller sizes. Capital preservation first.',
            ),
            RiskMode.balanced => (
              PhosphorIcons.chartLineUp(PhosphorIconsStyle.fill),
              'Balanced',
              'Optimal risk/reward mix for trending markets.',
            ),
            RiskMode.aggressive => (
              PhosphorIcons.lightning(PhosphorIconsStyle.fill),
              'Aggressive',
              'Higher drawdowns for outsized potential gains.',
            ),
          };
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onSelect(r);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: EdgeInsets.only(bottom: 8.h),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.10)
                    : AppColors.cardDark,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.45)
                      : AppColors.borderDark,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34.r,
                    height: 34.r,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : AppColors.backgroundDark.withValues(alpha: 0.6),
                    ),
                    child: Icon(
                      icon,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textSecondaryDark,
                      size: 15.r,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            color: AppColors.textPrimaryDark,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          desc,
                          style: TextStyle(
                            color: AppColors.textMutedDark,
                            fontSize: 11.sp,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected) ...[
                    SizedBox(width: 8.w),
                    Icon(
                      PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                      color: AppColors.primary,
                      size: 17.r,
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Step 2: Parameters ─────────────────────────────────────────────────────

class _ParamsStep extends StatelessWidget {
  final AIBotConfig config;
  final ValueChanged<AIBotConfig> onChanged;

  const _ParamsStep({required this.config, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(32.w, 0, 32.w, 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TickSlider(
            label: 'Stop Loss',
            value: config.stopLossPercentage,
            min: 1.0,
            max: 20.0,
            suffix: '%',
            color: AppColors.error,
            majorLabels: const ['1%', '5%', '10%', '15%', '20%'],
            onChanged: (v) => onChanged(config.copyWith(stopLossPercentage: v)),
          ),
          SizedBox(height: 36.h),
          _TickSlider(
            label: 'Max Position',
            value: config.maxSizeUSDC,
            min: 10.0,
            max: 500.0,
            suffix: ' USDC',
            color: AppColors.primary,
            majorLabels: const ['10', '150', '300', '500'],
            onChanged: (v) => onChanged(config.copyWith(maxSizeUSDC: v)),
          ),
          SizedBox(height: 36.h),
          _TickSlider(
            label: 'Leverage',
            value: config.maxLeverage,
            min: 1.0,
            max: 10.0,
            suffix: 'x',
            color: AppColors.primaryLight,
            majorLabels: const ['1x', '3x', '5x', '7x', '10x'],
            onChanged: (v) => onChanged(config.copyWith(maxLeverage: v)),
          ),
        ],
      ),
    );
  }
}

// ── Tick-mark slider ───────────────────────────────────────────────────────
//
// Anatomy (aura design system):
//
//     [█badge█capsule█]         ← floats above current thumb position
//          |  stem
//   ┊   |    ┊   |    ┊   |  ← tick marks; taller at every 8th interval
//   1        5       10  20   ← major labels below
//
// Color semantics:
//   stop loss → AppColors.error (red ticks = loss territory)
//   position  → AppColors.primary (indigo)
//   leverage  → AppColors.primaryLight
// ──────────────────────────────────────────────────────────────────────────

class _TickSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String suffix;
  final Color color;
  final List<String> majorLabels;
  final ValueChanged<double> onChanged;

  const _TickSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.suffix,
    required this.color,
    required this.majorLabels,
    required this.onChanged,
  });

  String get _display {
    final fmt = value.truncateToDouble() == value
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
    return '$fmt$suffix';
  }

  @override
  Widget build(BuildContext context) {
    // Compute responsive heights here (with ScreenUtil context) so the
    // CustomPainter can draw correctly without needing BuildContext.
    final majorTickH = 14.h;
    final minorTickH = 8.h;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: AppColors.textMutedDark,
            fontSize: 10.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
        // Visual gap that the floating badge occupies (badge + stem = ~38h).
        SizedBox(height: 38.h),
        LayoutBuilder(
          builder: (context, constraints) {
            final trackWidth = constraints.maxWidth;
            final fraction = ((value - min) / (max - min)).clamp(0.0, 1.0);
            final thumbX = fraction * trackWidth;
            // Half-width estimate for badge clamping. Covers "500 USDC".
            final badgeHW = 36.w;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (d) {
                final f = (d.localPosition.dx / trackWidth).clamp(0.0, 1.0);
                onChanged(min + f * (max - min));
              },
              onTapDown: (d) {
                final f = (d.localPosition.dx / trackWidth).clamp(0.0, 1.0);
                onChanged(min + f * (max - min));
              },
              child: SizedBox(
                width: trackWidth,
                // tick area (28h) + label row (14h)
                height: 42.h,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // ── Floating badge + stem ──────────────────────────────
                    Positioned(
                      left: (thumbX - badgeHW).clamp(
                        0.0,
                        trackWidth - badgeHW * 2,
                      ),
                      top: -38.h,
                      child: SizedBox(
                        width: badgeHW * 2,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10.w,
                                vertical: 4.h,
                              ),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(20.r),
                              ),
                              child: Text(
                                _display,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w800,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                            Center(
                              child: Container(
                                width: 1.5.w,
                                height: 10.h,
                                color: color.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Tick marks ─────────────────────────────────────────
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: CustomPaint(
                        painter: _TickPainter(
                          fraction: fraction,
                          color: color,
                          majorTickH: majorTickH,
                          minorTickH: minorTickH,
                        ),
                        child: SizedBox(width: trackWidth, height: 28.h),
                      ),
                    ),

                    // ── Major labels ───────────────────────────────────────
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: majorLabels
                            .map(
                              (l) => Text(
                                l,
                                style: TextStyle(
                                  color: AppColors.textMutedDark.withValues(
                                    alpha: 0.6,
                                  ),
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ── Tick painter ───────────────────────────────────────────────────────────

class _TickPainter extends CustomPainter {
  final double fraction;
  final Color color;
  final double majorTickH;
  final double minorTickH;

  const _TickPainter({
    required this.fraction,
    required this.color,
    required this.majorTickH,
    required this.minorTickH,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const tickCount = 48;
    final spacing = size.width / (tickCount - 1);
    final thumbX = fraction * size.width;
    final centerY = size.height / 2;

    for (int i = 0; i < tickCount; i++) {
      final x = i * spacing;
      final isMajor = i % 8 == 0;
      final tickH = isMajor ? majorTickH : minorTickH;
      final selected = x <= thumbX;

      final paint = Paint()
        ..color = selected
            ? (isMajor ? color : color.withValues(alpha: 0.70))
            : (isMajor ? const Color(0xFF454550) : const Color(0xFF2D2D35))
        ..strokeWidth = isMajor ? 1.8 : 1.2
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(x, centerY - tickH / 2),
        Offset(x, centerY + tickH / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_TickPainter old) =>
      old.fraction != fraction || old.color != color;
}
