import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/dream_colors.dart';
import '../../models/intelligence_models.dart';
import '../../providers/copy_trading_provider.dart';
import 'copy_trade_page.dart';

/// Copy-trading home: mirror Phoenix traders onto your own wallet.
class IntelligenceTabPage extends ConsumerWidget {
  const IntelligenceTabPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(copyTradingProvider);

    return Scaffold(
      backgroundColor: context.dreamColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(24.w, 8.h, 16.w, 4.h),
              child: Row(
                children: [
                  Text(
                    'Copy Trading',
                    style: TextStyle(
                      color: context.dreamColors.onSurface,
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const Spacer(),
                  // Credits — battery icon tappable to top up
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _showPurchaseSheet(context, ref);
                    },
                    child: _BatteryCredits(
                      credits: state.points,
                      isLoading: state.isLoadingCredits,
                    ),
                  ),
                  SizedBox(width: 16.w),
                ],
              ),
            ),
            const Expanded(child: CopyTradePage()),
          ],
        ),
      ),
    );
  }

  void _showPurchaseSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PurchaseSheet(
        isBuying: ref.read(copyTradingProvider).isBuying,
        onTierSelected: (tier) {
          Navigator.of(context).pop();
          ref.read(copyTradingProvider.notifier).purchaseCredits(tier);
        },
      ),
    );
  }
}

// ── Purchase sheet ───────────────────────────────────────────────────────────

class _PurchaseSheet extends StatelessWidget {
  final ValueChanged<CreditTier> onTierSelected;
  final bool isBuying;

  const _PurchaseSheet({required this.onTierSelected, required this.isBuying});

  @override
  Widget build(BuildContext context) {
    final dc = context.dreamColors;
    return Container(
      decoration: BoxDecoration(
        color: dc.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        border: Border(
          top: BorderSide(color: dc.stroke.withValues(alpha: 0.6)),
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
                  color: dc.stroke,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
          ),
          Text(
            'Copy Credits',
            style: TextStyle(
              color: dc.onSurface,
              fontSize: 22.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'Each mirrored trade open uses 1 credit. Credits never expire.',
            style: TextStyle(color: dc.muted, fontSize: 13.sp),
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

  Color _tierColor(BuildContext context, int i) => switch (i) {
    0 => const Color(0xFF94A3B8),
    1 => context.dreamColors.primary,
    _ => context.dreamColors.warning,
  };

  static IconData _tierIcon(int i) => switch (i) {
    0 => PhosphorIcons.batteryLow(PhosphorIconsStyle.fill),
    1 => PhosphorIcons.batteryMedium(PhosphorIconsStyle.fill),
    _ => PhosphorIcons.batteryFull(PhosphorIconsStyle.fill),
  };

  @override
  Widget build(BuildContext context) {
    final color = _tierColor(context, tierIndex.clamp(0, 2));
    final icon = _tierIcon(tierIndex.clamp(0, 2));
    final dc = context.dreamColors;

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
              colors: [color.withValues(alpha: 0.14), dc.surface],
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
                        color: dc.onSurface,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      '${tier.credits} trades',
                      style: TextStyle(color: dc.muted, fontSize: 12.sp),
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
                    style: TextStyle(color: dc.muted, fontSize: 11.sp),
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
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: context.dreamColors.muted,
        ),
      );
    }
    final dc = context.dreamColors;
    final (icon, color) = switch (credits) {
      0 => (PhosphorIcons.batteryWarning(PhosphorIconsStyle.fill), dc.error),
      < 10 => (PhosphorIcons.batteryLow(PhosphorIconsStyle.fill), dc.warning),
      < 50 => (
        PhosphorIcons.batteryMedium(PhosphorIconsStyle.fill),
        dc.primaryContainer,
      ),
      _ => (PhosphorIcons.batteryFull(PhosphorIconsStyle.fill), dc.success),
    };
    return Icon(icon, size: 22.r, color: color);
  }
}
