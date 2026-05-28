import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/providers/auth/client_auth_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../models/intelligence_models.dart';
import '../../providers/ai_trading_provider.dart';
import '../widgets/agent_activation_sheet.dart';
import '../widgets/agent_config_sheet.dart';

class AITradingPage extends ConsumerWidget {
  const AITradingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(aiTradingProvider);
    final isAuthenticated = ref.watch(clientAuthProvider).walletAddress != null;

    if (!isAuthenticated) {
      return const _NotConnected();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AgentHeader(state: state),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              24.w,
              0,
              24.w,
              MediaQuery.paddingOf(context).bottom + 104.h,
            ),
            children: [
              SizedBox(height: 40.h),
              _HeroStatus(state: state),
              SizedBox(height: 20.h),
              _ConfigLine(config: state.config),
              SizedBox(height: 36.h),
              _ActivateCTA(state: state),
              if (state.error != null) ...[
                SizedBox(height: 10.h),
                _InlineError(message: state.error!),
              ],
              if (state.log.isNotEmpty) ...[
                SizedBox(height: 44.h),
                _FeedHeader(),
                SizedBox(height: 20.h),
                ...state.log.asMap().entries.map(
                  (e) => _SignalEntry(
                    entry: e.value,
                    isLast: e.key == state.log.length - 1,
                  ),
                ),
              ] else if (!state.isRunning) ...[
                SizedBox(height: 56.h),
                const _EmptyFeed(),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _AgentHeader extends ConsumerWidget {
  final AITradingState state;
  const _AgentHeader({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24.w, 8.h, 20.w, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Signal Agent',
              style: TextStyle(
                color: AppColors.textPrimaryDark,
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),
          // Credits — battery icon tappable to buy
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _showPurchaseSheet(context, ref);
            },
            child: _BatteryCredits(
              credits: state.aiCredits,
              isLoading: state.isLoadingCredits,
            ),
          ),
          SizedBox(width: 10.w),
          // Config
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              AgentConfigSheet.show(context, state.config);
            },
            child: Icon(
              PhosphorIcons.slidersHorizontal(PhosphorIconsStyle.bold),
              color: AppColors.textSecondaryDark,
              size: 20.r,
            ),
          ),
        ],
      ),
    );
  }

  void _showPurchaseSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PurchaseSheet(
        isBuying: ref.read(aiTradingProvider).isBuying,
        onTierSelected: (tier) {
          Navigator.of(context).pop();
          ref.read(aiTradingProvider.notifier).purchaseCredits(tier);
        },
      ),
    );
  }
}

// ── Hero ──────────────────────────────────────────────────────────────────────

class _HeroStatus extends StatelessWidget {
  final AITradingState state;
  const _HeroStatus({required this.state});

  @override
  Widget build(BuildContext context) {
    final isRunning = state.isRunning;
    final hasPnl = state.totalPnl != 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 2.h),
              Text(
                isRunning ? 'ACTIVE' : 'IDLE',
                style: GoogleFonts.vt323(
                  color: isRunning
                      ? AppColors.primary
                      : AppColors.textSecondaryDark,
                  fontSize: 44.sp,
                  height: 1.0,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                isRunning
                    ? 'Scanning ${state.config.market} · every 60s'
                    : 'Tap activate to start scanning',
                style: TextStyle(
                  color: AppColors.textMutedDark,
                  fontSize: 13.sp,
                  height: 1.4,
                ),
              ),
              if (hasPnl) ...[
                SizedBox(height: 14.h),
                Row(
                  children: [
                    Text(
                      'Session',
                      style: TextStyle(
                        color: AppColors.textMutedDark,
                        fontSize: 12.sp,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      '${state.totalPnl >= 0 ? '+' : ''}\$${state.totalPnl.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: state.totalPnl >= 0
                            ? AppColors.bullish
                            : AppColors.bearish,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── Config summary line ───────────────────────────────────────────────────────

class _ConfigLine extends StatelessWidget {
  final AIBotConfig config;
  const _ConfigLine({required this.config});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _InlineStat(
          icon: PhosphorIcons.chartLineUp(PhosphorIconsStyle.bold),
          label: config.market.replaceAll('-PERP', ''),
        ),
        _Separator(),
        _InlineStat(
          icon: PhosphorIcons.shieldWarning(PhosphorIconsStyle.bold),
          label: 'SL ${config.stopLossPercentage.toStringAsFixed(0)}%',
        ),
        _Separator(),
        _InlineStat(
          icon: PhosphorIcons.coins(PhosphorIconsStyle.bold),
          label: '\$${config.maxSizeUSDC.toStringAsFixed(0)}',
        ),
        _Separator(),
        _InlineStat(
          icon: PhosphorIcons.arrowsOutLineVertical(PhosphorIconsStyle.bold),
          label: '${config.maxLeverage.toStringAsFixed(0)}×',
        ),
      ],
    );
  }
}

class _InlineStat extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InlineStat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11.r, color: AppColors.textMutedDark),
        SizedBox(width: 4.w),
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondaryDark,
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _Separator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10.w),
      child: Container(
        width: 3.r,
        height: 3.r,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.borderDark,
        ),
      ),
    );
  }
}

// ── Activate CTA ──────────────────────────────────────────────────────────────

class _ActivateCTA extends ConsumerWidget {
  final AITradingState state;
  const _ActivateCTA({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRunning = state.isRunning;

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        if (isRunning) {
          ref.read(aiTradingProvider.notifier).stopBot();
        } else {
          AgentActivationSheet.show(context, state.config);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 8.h),
        margin: EdgeInsets.symmetric(horizontal: 52.w),
        decoration: BoxDecoration(
          color: isRunning ? Colors.transparent : AppColors.primary,
          borderRadius: BorderRadius.circular(60.r),
          border: Border.all(
            color: isRunning
                ? AppColors.error.withValues(alpha: 0.55)
                : AppColors.primary,
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isRunning
                  ? PhosphorIcons.stop(PhosphorIconsStyle.fill)
                  : PhosphorIcons.play(PhosphorIconsStyle.fill),
              color: isRunning ? AppColors.error : Colors.white,
              size: 15.r,
            ),
            SizedBox(width: 10.w),
            Text(
              isRunning ? 'Stop Agent' : 'Activate Agent',
              style: TextStyle(
                color: isRunning ? AppColors.error : Colors.white,
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Signal feed ───────────────────────────────────────────────────────────────

class _FeedHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'SIGNALS',
          style: TextStyle(
            color: AppColors.textMutedDark,
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Container(
            height: 1,
            color: AppColors.borderDark.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }
}

class _SignalEntry extends StatelessWidget {
  final BotLogEntry entry;
  final bool isLast;
  const _SignalEntry({required this.entry, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final (barColor, label) = _meta(entry.action);
    final timeStr = _relativeTime(entry.timestamp);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left timeline accent bar
          Column(
            children: [
              Expanded(
                child: Container(
                  width: 2,
                  decoration: BoxDecoration(
                    color: barColor.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 14.h,
                  color: AppColors.borderDark.withValues(alpha: 0.3),
                ),
            ],
          ),
          SizedBox(width: 14.w),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: barColor,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        timeStr,
                        style: TextStyle(
                          color: AppColors.textMutedDark,
                          fontSize: 11.sp,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    entry.reason,
                    style: TextStyle(
                      color: AppColors.textSecondaryDark,
                      fontSize: 12.sp,
                      height: 1.45,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (entry.txSignature != null) ...[
                    SizedBox(height: 5.h),
                    Row(
                      children: [
                        Icon(
                          PhosphorIcons.arrowSquareOut(PhosphorIconsStyle.bold),
                          size: 10.r,
                          color: AppColors.primaryLight,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          '${entry.txSignature!.substring(0, 8)}…',
                          style: TextStyle(
                            color: AppColors.primaryLight,
                            fontSize: 10.sp,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  (Color, String) _meta(BotAction action) => switch (action) {
    BotAction.buy => (AppColors.bullish, 'BUY'),
    BotAction.sell => (AppColors.bearish, 'SELL'),
    BotAction.hold => (AppColors.textSecondaryDark, 'HOLD'),
  };

  String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          PhosphorIcons.waveform(PhosphorIconsStyle.duotone),
          size: 38.r,
          color: AppColors.textMutedDark.withValues(alpha: 0.5),
        ),
        SizedBox(height: 14.h),
        Text(
          'No signals yet',
          style: TextStyle(
            color: AppColors.textSecondaryDark,
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 6.h),
        Text(
          'Activate the agent to start scanning\nfor entry and exit opportunities.',
          style: TextStyle(
            color: AppColors.textMutedDark,
            fontSize: 12.sp,
            height: 1.55,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── Purchase sheet ────────────────────────────────────────────────────────────

class _PurchaseSheet extends StatelessWidget {
  final ValueChanged<CreditTier> onTierSelected;
  final bool isBuying;

  const _PurchaseSheet({required this.onTierSelected, required this.isBuying});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        border: Border(
          top: BorderSide(color: AppColors.borderDark.withValues(alpha: 0.6)),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        24.w,
        0,
        24.w,
        MediaQuery.of(context).viewInsets.bottom + 40.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Padding(
              padding: EdgeInsets.only(top: 12.h, bottom: 28.h),
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
          Text(
            'Signal Credits',
            style: TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 22.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'Each scan uses 1 credit. Credits never expire.',
            style: TextStyle(color: AppColors.textMutedDark, fontSize: 13.sp),
          ),
          SizedBox(height: 32.h),
          ...CreditTier.tiers.asMap().entries.map(
            (e) => _TierRow(
              tier: e.value,
              tierIndex: e.key,
              isBuying: isBuying,
              onSelect: () => onTierSelected(e.value),
            ),
          ),
        ],
      ),
    );
  }
}

class _TierRow extends StatelessWidget {
  final CreditTier tier;
  final bool isBuying;
  final VoidCallback onSelect;
  final int tierIndex;

  const _TierRow({
    required this.tier,
    required this.isBuying,
    required this.onSelect,
    required this.tierIndex,
  });

  static const _tierColors = [
    Color(0xFF94A3B8), // Starter — slate silver
    AppColors.primary, // Trader — indigo
    AppColors.warning, // Pro — amber
  ];

  static IconData _tierIcon(int i) => switch (i) {
    0 => PhosphorIcons.batteryLow(PhosphorIconsStyle.fill),
    1 => PhosphorIcons.batteryMedium(PhosphorIconsStyle.fill),
    _ => PhosphorIcons.batteryFull(PhosphorIconsStyle.fill),
  };

  @override
  Widget build(BuildContext context) {
    final color = _tierColors[tierIndex.clamp(0, 2)];
    final icon = _tierIcon(tierIndex.clamp(0, 2));

    return GestureDetector(
      onTap: isBuying ? null : onSelect,
      child: AnimatedOpacity(
        opacity: isBuying ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          margin: EdgeInsets.only(bottom: 12.h),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color.withValues(alpha: 0.14), AppColors.surfaceDark],
            ),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: color.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.10),
                blurRadius: 18.r,
                offset: Offset(0, 6.h),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 8.r,
                offset: Offset(0, 2.h),
              ),
            ],
          ),
          padding: EdgeInsets.all(16.r),
          child: Row(
            children: [
              // Tier icon bubble
              Container(
                width: 42.r,
                height: 42.r,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.15),
                ),
                child: Icon(icon, color: color, size: 20.r),
              ),
              SizedBox(width: 14.w),

              // Name + credits
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tier.label,
                      style: TextStyle(
                        color: AppColors.textPrimaryDark,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      '${tier.credits} scans',
                      style: TextStyle(
                        color: AppColors.textMutedDark,
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ),

              // Price
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${tier.solPrice} SOL',
                    style: TextStyle(
                      color: color,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    '~\$${(tier.solPrice * 150).toStringAsFixed(0)}',
                    style: TextStyle(
                      color: AppColors.textMutedDark,
                      fontSize: 11.sp,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// ── Battery credits indicator ─────────────────────────────────────────────────

class _BatteryCredits extends StatelessWidget {
  final int credits;
  final bool isLoading;
  const _BatteryCredits({required this.credits, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return SizedBox(
        width: 18.r,
        height: 18.r,
        child: const CircularProgressIndicator(
          strokeWidth: 1.5,
          color: AppColors.textMutedDark,
        ),
      );
    }
    final (icon, color) = switch (credits) {
      0 => (
        PhosphorIcons.batteryWarning(PhosphorIconsStyle.fill),
        AppColors.error,
      ),
      < 10 => (
        PhosphorIcons.batteryLow(PhosphorIconsStyle.fill),
        AppColors.warning,
      ),
      < 50 => (
        PhosphorIcons.batteryMedium(PhosphorIconsStyle.fill),
        AppColors.primaryLight,
      ),
      _ => (
        PhosphorIcons.batteryFull(PhosphorIconsStyle.fill),
        AppColors.success,
      ),
    };
    return Icon(icon, size: 22.r, color: color);
  }
}

// ── Misc helpers ──────────────────────────────────────────────────────────────

class _InlineError extends StatelessWidget {
  final String message;
  const _InlineError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 1.h),
          child: Icon(
            PhosphorIcons.warning(PhosphorIconsStyle.fill),
            color: AppColors.error,
            size: 13.r,
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              color: AppColors.error.withValues(alpha: 0.85),
              fontSize: 12.sp,
              height: 1.45,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _NotConnected extends StatelessWidget {
  const _NotConnected();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PhosphorIcons.wallet(PhosphorIconsStyle.duotone),
              size: 44.r,
              color: AppColors.textMutedDark.withValues(alpha: 0.5),
            ),
            SizedBox(height: 16.h),
            Text(
              'Connect a wallet',
              style: TextStyle(
                color: AppColors.textPrimaryDark,
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              'Sign in to use the Signal Agent.',
              style: TextStyle(color: AppColors.textMutedDark, fontSize: 13.sp),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
