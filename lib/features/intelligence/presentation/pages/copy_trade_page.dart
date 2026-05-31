import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/providers/phoenix/phoenix_auth_provider.dart';
import '../../../../core/providers/solana/wallet_name_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../../models/intelligence_models.dart';
import '../../providers/copy_trading_provider.dart';
import '../widgets/copy_settings_sheet.dart';
import '../../../../core/theme/dream_colors.dart';

class CopyTradePage extends ConsumerStatefulWidget {
  const CopyTradePage({super.key});

  @override
  ConsumerState<CopyTradePage> createState() => _CopyTradePageState();
}

class _CopyTradePageState extends ConsumerState<CopyTradePage> {
  final _addressController = TextEditingController();

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _handleAddTrader() async {
    final phoenixAuth = ref.read(phoenixAuthProvider);
    if (phoenixAuth.isExternalWallet) {
      _showEmbeddedWalletRequirementSnackbar();
      return;
    }

    final address = _addressController.text.trim();
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Paste a Phoenix trader wallet address first.'),
          backgroundColor: context.dreamColors.surface,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final leader = await ref
        .read(copyTradingProvider.notifier)
        .findLeader(address);
    if (!mounted || leader == null) return;

    CopySettingsSheet.show(
      context,
      leader: leader,
      onConfirm: (settings) {
        ref.read(copyTradingProvider.notifier).followLeader(leader, settings);
        _addressController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Now watching ${leader.displayLabel}'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  void _showEmbeddedWalletRequirementSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Use Dream\'s embedded wallet to unlock copy trading automation.',
        ),
        backgroundColor: context.dreamColors.surfaceVariant,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(copyTradingProvider);
    final phoenixAuth = ref.watch(phoenixAuthProvider);
    final isExternalWallet = phoenixAuth.isExternalWallet;

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: context.dreamColors.surfaceVariant,
      onRefresh: () => ref.read(copyTradingProvider.notifier).refreshFollowed(),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          24.w,
          8.h,
          24.w,
          MediaQuery.paddingOf(context).bottom + 104.h,
        ),
        children: [
          SizedBox(height: 12.h),
          if (isExternalWallet) ...[
            const _WalletEligibilityBanner(),
            SizedBox(height: 20.h),
          ],
          // ── Path 1 — follow any Phoenix wallet you already know ──────────
          _AddressComposer(
            controller: _addressController,
            isLoading: state.isAddingLeader,
            isDisabled: isExternalWallet,
            onSubmit: _handleAddTrader,
          ),
          SizedBox(height: 20.h),
          // ── Path 2 — discover registered broadcasters ───────────────────
          _BrowseBroadcastersCard(
            isDisabled: isExternalWallet,
            onTap: isExternalWallet
                ? _showEmbeddedWalletRequirementSnackbar
                : () => context.push('/broadcasters'),
          ),
          if (state.error != null) ...[
            SizedBox(height: 12.h),
            _InlineError(message: state.error!),
          ],
          SizedBox(height: 34.h),
          _SectionLabel(
            title: 'Following',
            trailing: state.following.isEmpty
                ? 'none'
                : '${state.following.length} active',
          ),
          SizedBox(height: 14.h),
          if (state.following.isEmpty)
            const _EmptyFollowing()
          else
            ...state.following.asMap().entries.map(
              (entry) => _FollowedRow(
                followed: entry.value,
                isLast: entry.key == state.following.length - 1,
              ),
            ),
        ],
      ),
    );
  }
}

class _AddressComposer extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final bool isDisabled;
  final VoidCallback onSubmit;

  const _AddressComposer({
    required this.controller,
    required this.isLoading,
    required this.isDisabled,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Follow by wallet address',
          style: TextStyle(
            color: context.dreamColors.onSurface,
            fontSize: 22.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            height: 1.0,
          ),
        ),
        SizedBox(height: 7.h),
        Text(
          isDisabled
              ? 'Copy trading automation is reserved for Dream embedded wallets.'
              : 'Paste a Phoenix trader authority and set your copy-risk profile in the bottom sheet.',
          style: TextStyle(
            color: context.dreamColors.mutedSecondary,
            fontSize: 12.sp,
            height: 1.45,
          ),
        ),
        SizedBox(height: 14.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !isDisabled,
                style: TextStyle(
                  color: context.dreamColors.onSurface,
                  fontSize: 13.sp,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                decoration: InputDecoration(
                  hintText: isDisabled
                      ? 'Embedded wallet required'
                      : 'Trader wallet address',
                  hintStyle: TextStyle(
                    color: context.dreamColors.mutedSecondary,
                    fontSize: 12.sp,
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: context.dreamColors.stroke.withValues(alpha: 0.8),
                    ),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primary),
                  ),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 10.h),
                ),
              ),
            ),
            SizedBox(width: 14.w),
            GestureDetector(
              onTap: isLoading || isDisabled ? null : onSubmit,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: EdgeInsets.only(bottom: 6.h),
                child: isLoading
                    ? SizedBox(
                        width: 17.r,
                        height: 17.r,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isDisabled ? 'Embedded only' : 'Follow',
                            style: TextStyle(
                              color: isDisabled
                                  ? context.dreamColors.mutedSecondary
                                  : AppColors.primary,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(width: 5.w),
                          Icon(
                            isDisabled
                                ? PhosphorIcons.lock(PhosphorIconsStyle.bold)
                                : PhosphorIcons.arrowRight(
                                    PhosphorIconsStyle.bold,
                                  ),
                            color: isDisabled
                                ? context.dreamColors.mutedSecondary
                                : AppColors.primary,
                            size: 13.r,
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  final String trailing;

  const _SectionLabel({required this.title, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            color: context.dreamColors.mutedSecondary,
            fontSize: 11.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Container(
            height: 1,
            color: context.dreamColors.stroke.withValues(alpha: 0.4),
          ),
        ),
        SizedBox(width: 10.w),
        Text(
          trailing.toUpperCase(),
          style: TextStyle(
            color: context.dreamColors.mutedSecondary,
            fontSize: 9.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _FollowedRow extends ConsumerWidget {
  final FollowedLeader followed;
  final bool isLast;

  const _FollowedRow({required this.followed, required this.isLast});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leader = followed.leader;
    final isPaused = followed.isPaused;
    final statusColor = isPaused ? AppColors.warning : AppColors.success;
    final liveOpenCount = followed.lastKnownPositions.length;
    final resolvedDomain = ref.watch(walletNameProvider(leader.address)).asData?.value;
    final title = leader.label ?? resolvedDomain ?? leader.displayLabel;
    final secondaryIdentity = switch ((leader.label, resolvedDomain)) {
      (String _, String domain) => domain,
      (null, String _) => _short(leader.address),
      (String _, null) => _short(leader.address),
      (null, null) => null,
    };

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 18.h),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: EdgeInsets.only(top: 4.h),
                width: 2,
                height: 40.h,
                color: statusColor.withValues(alpha: 0.8),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.dreamColors.onSurface,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ),
                        Text(
                          isPaused ? 'PAUSED' : 'LIVE',
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.7,
                          ),
                        ),
                        SizedBox(width: 6.w),
                        _ActionMenu(followed: followed),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    SizedBox(height: 7.h),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (secondaryIdentity != null) ...[
                          Flexible(
                            child: Text(
                              secondaryIdentity,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.dreamColors.mutedSecondary,
                                fontSize: 11.sp,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                          SizedBox(width: 12.w),
                        ],
                        Expanded(
                          child: Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 10.w,
                            runSpacing: 4.h,
                            children: [
                              _InlineMeta(
                                label: 'size',
                                value: formatUsdc(followed.settings.copyUSDC),
                              ),
                              _InlineMeta(
                                label: 'slip',
                                value:
                                    '${(followed.settings.maxSlippage * 100).toStringAsFixed(1)}%',
                              ),
                              _InlineMeta(
                                label: 'open',
                                value: '$liveOpenCount',
                              ),
                              if (followed.gainSinceFollow != 0)
                                _InlineMeta(
                                  label: 'since',
                                  value: formatPnl(followed.gainSinceFollow),
                                  valueColor: followed.gainSinceFollow >= 0
                                      ? AppColors.bullish
                                      : AppColors.bearish,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isLast) ...[
            SizedBox(height: 16.h),
            Container(
              height: 1,
              color: context.dreamColors.stroke.withValues(alpha: 0.28),
            ),
          ],
        ],
      ),
    );
  }

  String _short(String address) {
    if (address.length <= 10) return address;
    return '${address.substring(0, 4)}…${address.substring(address.length - 4)}';
  }
}

class _InlineMeta extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InlineMeta({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: TextStyle(
            color: context.dreamColors.mutedSecondary,
            fontSize: 10.sp,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? context.dreamColors.muted,
            fontSize: 10.sp,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

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
            PhosphorIcons.warningCircle(PhosphorIconsStyle.fill),
            color: AppColors.error,
            size: 14.r,
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              color: AppColors.error.withValues(alpha: 0.88),
              fontSize: 12.sp,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyFollowing extends StatelessWidget {
  const _EmptyFollowing();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          PhosphorIcons.usersThree(PhosphorIconsStyle.duotone),
          size: 34.r,
          color: context.dreamColors.mutedSecondary.withValues(alpha: 0.45),
        ),
        SizedBox(height: 12.h),
        Text(
          'No leaders followed yet',
          style: TextStyle(
            color: context.dreamColors.muted,
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 6.h),
        Text(
          'Follow a trader address above to start mirroring\nnew position changes instantly over websocket.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.dreamColors.mutedSecondary,
            fontSize: 12.sp,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _BrowseBroadcastersCard extends StatelessWidget {
  final VoidCallback onTap;
  final bool isDisabled;

  const _BrowseBroadcastersCard({
    required this.onTap,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.dreamColors;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(14.r),
        decoration: BoxDecoration(
          color: colors.surfaceVariant,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: colors.stroke),
        ),
        child: Row(
          children: [
            Container(
              width: 34.r,
              height: 34.r,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDisabled
                    ? colors.stroke.withValues(alpha: 0.14)
                    : colors.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(9.r),
              ),
              child: Icon(
                isDisabled
                    ? PhosphorIcons.lock(PhosphorIconsStyle.bold)
                    : PhosphorIcons.broadcast(PhosphorIconsStyle.bold),
                size: 17.r,
                color: isDisabled ? colors.mutedSecondary : colors.primary,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isDisabled
                        ? 'Embedded wallet required'
                        : 'Browse live broadcasters',
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    isDisabled
                        ? 'Switch to Dream\'s embedded wallet to enable copy automation'
                        : 'Filter top earners, copiers & PnL',
                    style: TextStyle(
                      color: colors.muted,
                      fontSize: 11.sp,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            Icon(
              PhosphorIcons.caretRight(PhosphorIconsStyle.bold),
              size: 16.r,
              color: colors.mutedSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletEligibilityBanner extends StatelessWidget {
  const _WalletEligibilityBanner();

  @override
  Widget build(BuildContext context) {
    final colors = context.dreamColors;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: colors.stroke),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            PhosphorIcons.info(PhosphorIconsStyle.bold),
            size: 16.r,
            color: colors.primary,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              'Copy trading automation is only available on Dream embedded '
              'wallets. Sign in with email or social if you want the full '
              'copy-trading feature set.',
              style: TextStyle(
                color: colors.muted,
                fontSize: 11.sp,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionMenu extends ConsumerWidget {
  final FollowedLeader followed;
  const _ActionMenu({required this.followed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(copyTradingProvider.notifier);

    return PopupMenuButton<_Action>(
      icon: Icon(
        PhosphorIcons.dotsThreeVertical(PhosphorIconsStyle.bold),
        color: context.dreamColors.muted,
        size: 17.r,
      ),
      color: context.dreamColors.surfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.r),
        side: BorderSide(color: context.dreamColors.stroke),
      ),
      onSelected: (action) async {
        switch (action) {
          case _Action.pause:
            await notifier.pauseLeader(
              followed.leader.address,
              paused: !followed.isPaused,
            );
          case _Action.unfollow:
            await notifier.unfollowLeader(followed.leader.address);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: _Action.pause,
          child: _MenuRow(
            icon: followed.isPaused
                ? PhosphorIcons.play(PhosphorIconsStyle.bold)
                : PhosphorIcons.pause(PhosphorIconsStyle.bold),
            label: followed.isPaused ? 'Resume' : 'Pause',
          ),
        ),
        PopupMenuItem(
          value: _Action.unfollow,
          child: _MenuRow(
            icon: PhosphorIcons.userMinus(PhosphorIconsStyle.bold),
            label: 'Unfollow',
            color: AppColors.error,
          ),
        ),
      ],
    );
  }
}

enum _Action { pause, unfollow }

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _MenuRow({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.dreamColors.onSurface;
    return Row(
      children: [
        Icon(icon, color: c, size: 15.r),
        SizedBox(width: 8.w),
        Text(
          label,
          style: TextStyle(color: c, fontSize: 13.sp),
        ),
      ],
    );
  }
}
