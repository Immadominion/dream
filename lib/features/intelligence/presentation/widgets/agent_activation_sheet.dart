import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/intelligence_models.dart';
import '../../providers/ai_trading_provider.dart';

// ── Market groups ─────────────────────────────────────────────────────────────

// Valid group keys — used to normalise legacy single-market configs
const _kGroupKeys = {'blue_chips', 'solana_native', 'degen', 'all'};

// (key, label, tagline, market chips, color)
final _kGroups = [
  (
    'blue_chips',
    'Blue Chips',
    'Highest liquidity — most reliable signal quality.',
    <String>['BTC', 'ETH', 'SOL'],
    const Color(0xFF94A3B8),
  ),
  (
    'solana_native',
    'Solana Native',
    'Ecosystem governance and DeFi protocols.',
    <String>['JUP', 'JTO', 'PYTH', 'W'],
    AppColors.primary,
  ),
  (
    'degen',
    'Degen',
    'Volatile memecoins and speculative plays.',
    <String>['BONK', 'WIF', 'RNDR'],
    AppColors.warning,
  ),
  (
    'all',
    'Full Sweep',
    'All 10 perpetuals — maximum signal coverage.',
    <String>['All 10'],
    AppColors.success,
  ),
];

IconData _groupIcon(String key) => switch (key) {
  'blue_chips' => PhosphorIcons.star(PhosphorIconsStyle.fill),
  'solana_native' => PhosphorIcons.hexagon(PhosphorIconsStyle.fill),
  'degen' => PhosphorIcons.fire(PhosphorIconsStyle.fill),
  _ => PhosphorIcons.lightning(PhosphorIconsStyle.fill),
};

// ── Sheet ──────────────────────────────────────────────────────────────────

class AgentActivationSheet extends ConsumerStatefulWidget {
  final AIBotConfig initialConfig;

  const AgentActivationSheet({super.key, required this.initialConfig});

  static void show(BuildContext context, AIBotConfig config) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AgentActivationSheet(initialConfig: config),
    );
  }

  @override
  ConsumerState<AgentActivationSheet> createState() =>
      _AgentActivationSheetState();
}

class _AgentActivationSheetState extends ConsumerState<AgentActivationSheet> {
  int _step = 0;
  late AIBotConfig _config;

  @override
  void initState() {
    super.initState();
    _config = widget.initialConfig;
    // Normalise: if saved market is a legacy perp symbol, reset to default group
    if (!_kGroupKeys.contains(_config.market)) {
      _config = _config.copyWith(market: 'blue_chips');
    }
  }

  void _next() {
    if (_step < 2) {
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

  void _activate() {
    HapticFeedback.mediumImpact();
    ref.read(aiTradingProvider.notifier).updateConfig(_config);
    ref.read(aiTradingProvider.notifier).startBot();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Container(
      constraints: BoxConstraints(maxHeight: size.height * 0.88),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        border: Border(
          top: BorderSide(color: AppColors.borderDark.withValues(alpha: 0.6)),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Padding(
              padding: EdgeInsets.only(top: 12.h, bottom: 4.h),
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.borderDark,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
          ),

          // Nav row
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _step > 0 ? _prev : null,
                  child: AnimatedOpacity(
                    opacity: _step > 0 ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      PhosphorIcons.arrowLeft(PhosphorIconsStyle.bold),
                      color: AppColors.textSecondaryDark,
                      size: 20.r,
                    ),
                  ),
                ),
                const Spacer(),
                _StepPills(current: _step),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Icon(
                    PhosphorIcons.x(PhosphorIconsStyle.bold),
                    color: AppColors.textSecondaryDark,
                    size: 18.r,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 20.h),

          // Title + subtitle
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    key: ValueKey('title$_step'),
                    child: Text(
                      _stepTitle,
                      style: TextStyle(
                        color: AppColors.textPrimaryDark,
                        fontSize: 26.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.0,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 5.h),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    key: ValueKey('sub$_step'),
                    child: Text(
                      _stepSubtitle,
                      style: TextStyle(
                        color: AppColors.textMutedDark,
                        fontSize: 12.sp,
                        height: 1.45,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 22.h),

          // Step content
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: KeyedSubtree(key: ValueKey(_step), child: _buildStep()),
            ),
          ),

          // CTA
          Padding(
            padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, safeBottom + 24.h),
            child: GestureDetector(
              onTap: _step < 2 ? _next : _activate,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(40.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _step < 2 ? 'Continue' : 'Activate Agent',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Icon(
                      _step < 2
                          ? PhosphorIcons.arrowRight(PhosphorIconsStyle.bold)
                          : PhosphorIcons.lightning(PhosphorIconsStyle.fill),
                      color: Colors.white,
                      size: 14.r,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _stepTitle => switch (_step) {
    0 => 'Market group',
    1 => 'Risk profile',
    _ => 'Parameters',
  };

  String get _stepSubtitle => switch (_step) {
    0 => 'Which markets should the agent scan for signals?',
    1 => 'How aggressively should the agent trade?',
    _ => 'Fine-tune position sizing and protection.',
  };

  Widget _buildStep() => switch (_step) {
    0 => _GroupStep(
      selectedGroup: _config.market,
      onSelect: (g) => setState(() => _config = _config.copyWith(market: g)),
    ),
    1 => _RiskStep(
      selected: _config.riskMode,
      onSelect: (r) => setState(() => _config = _config.copyWith(riskMode: r)),
    ),
    _ => _ParamsStep(
      config: _config,
      onChanged: (updated) => setState(() => _config = updated),
    ),
  };
}

// ── Step pills ─────────────────────────────────────────────────────────────

class _StepPills extends StatelessWidget {
  final int current;
  const _StepPills({required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final isActive = i == current;
        final isDone = i < current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: EdgeInsets.symmetric(horizontal: 3.w),
          width: isActive ? 20.w : 6.w,
          height: 6.h,
          decoration: BoxDecoration(
            color: isDone || isActive
                ? AppColors.primary
                : AppColors.borderDark,
            borderRadius: BorderRadius.circular(3.r),
          ),
        );
      }),
    );
  }
}

// ── Step 1: Market group picker ────────────────────────────────────────────

class _GroupStep extends StatelessWidget {
  final String selectedGroup;
  final ValueChanged<String> onSelect;

  const _GroupStep({required this.selectedGroup, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        children: _kGroups.map((g) {
          final isSelected = selectedGroup == g.$1;
          final color = g.$5;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onSelect(g.$1);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: EdgeInsets.only(bottom: 12.h),
              padding: EdgeInsets.all(16.r),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.10)
                    : AppColors.cardDark,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: isSelected
                      ? color.withValues(alpha: 0.45)
                      : AppColors.borderDark,
                ),
              ),
              child: Row(
                children: [
                  // Icon bubble
                  Container(
                    width: 40.r,
                    height: 40.r,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.15),
                    ),
                    child: Icon(_groupIcon(g.$1), color: color, size: 18.r),
                  ),
                  SizedBox(width: 14.w),
                  // Label + chips + tagline
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          g.$2,
                          style: TextStyle(
                            color: AppColors.textPrimaryDark,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 5.h),
                        Wrap(
                          spacing: 5.w,
                          runSpacing: 4.h,
                          children: g.$4
                              .map(
                                (m) => Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 7.w,
                                    vertical: 2.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.13),
                                    borderRadius: BorderRadius.circular(5.r),
                                  ),
                                  child: Text(
                                    m,
                                    style: TextStyle(
                                      color: color,
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        SizedBox(height: 5.h),
                        Text(
                          g.$3,
                          style: TextStyle(
                            color: AppColors.textMutedDark,
                            fontSize: 11.sp,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected) ...[
                    SizedBox(width: 10.w),
                    Icon(
                      PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                      color: color,
                      size: 20.r,
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

// ── Step 2: Risk profile ───────────────────────────────────────────────────

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
          final (icon, label, desc, color) = switch (r) {
            RiskMode.conservative => (
              PhosphorIcons.shieldWarning(PhosphorIconsStyle.fill),
              'Conservative',
              'Tight stops, smaller sizes.\nCapital preservation first.',
              AppColors.success,
            ),
            RiskMode.balanced => (
              PhosphorIcons.chartLineUp(PhosphorIconsStyle.fill),
              'Balanced',
              'Optimal risk/reward mix\nfor trending markets.',
              AppColors.primary,
            ),
            RiskMode.aggressive => (
              PhosphorIcons.lightning(PhosphorIconsStyle.fill),
              'Aggressive',
              'Wider stops for outsized gains.\nHigher drawdown tolerance.',
              AppColors.error,
            ),
          };

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onSelect(r);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: EdgeInsets.only(bottom: 10.h),
              padding: EdgeInsets.all(16.r),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: isSelected
                      ? color.withValues(alpha: 0.45)
                      : AppColors.borderDark.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38.r,
                    height: 38.r,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (isSelected ? color : AppColors.textMutedDark)
                          .withValues(alpha: 0.12),
                    ),
                    child: Icon(
                      icon,
                      color: isSelected ? color : AppColors.textMutedDark,
                      size: 18.r,
                    ),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            color: AppColors.textPrimaryDark,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          desc,
                          style: TextStyle(
                            color: AppColors.textSecondaryDark,
                            fontSize: 11.sp,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                      color: color,
                      size: 18.r,
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Step 3: Parameters ─────────────────────────────────────────────────────

class _ParamsStep extends StatelessWidget {
  final AIBotConfig config;
  final ValueChanged<AIBotConfig> onChanged;

  const _ParamsStep({required this.config, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AuraSlider(
            label: 'STOP LOSS',
            value: config.stopLossPercentage,
            min: 1.0,
            max: 20.0,
            divisions: 19,
            format: (v) => '${v.toStringAsFixed(0)}%',
            onChanged: (v) => onChanged(config.copyWith(stopLossPercentage: v)),
          ),
          SizedBox(height: 24.h),
          _AuraSlider(
            label: 'MAX POSITION',
            value: config.maxSizeUSDC,
            min: 10.0,
            max: 500.0,
            divisions: 49,
            format: (v) => '\$${v.toStringAsFixed(0)}',
            onChanged: (v) => onChanged(config.copyWith(maxSizeUSDC: v)),
          ),
          SizedBox(height: 24.h),
          _AuraSlider(
            label: 'LEVERAGE',
            value: config.maxLeverage,
            min: 1.0,
            max: 10.0,
            divisions: 9,
            format: (v) => '${v.toStringAsFixed(0)}×',
            onChanged: (v) => onChanged(config.copyWith(maxLeverage: v)),
          ),
        ],
      ),
    );
  }
}

// ── Aura-style slider ──────────────────────────────────────────────────────

class _AuraSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double) format;
  final ValueChanged<double> onChanged;

  const _AuraSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.format,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textMutedDark,
            fontSize: 10.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.primary,
                  inactiveTrackColor: AppColors.borderDark,
                  thumbColor: Colors.white,
                  overlayColor: AppColors.primary.withValues(alpha: 0.15),
                  trackHeight: 3.h,
                  thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8.r),
                  overlayShape: SliderComponentShape.noOverlay,
                ),
                child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  divisions: divisions,
                  onChanged: onChanged,
                ),
              ),
            ),
            SizedBox(width: 10.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Text(
                format(value),
                style: TextStyle(
                  color: AppColors.textPrimaryDark,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
