import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/providers/phoenix/phoenix_auth_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/dream_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../../models/intelligence_models.dart';
import '../../providers/copy_trading_provider.dart';
import '../widgets/copy_settings_sheet.dart';

/// Full-screen directory of registered Phoenix broadcasters.
///
/// Reached from the copy-trade CTA. Lets copiers filter the live broadcaster
/// set by lifetime earnings, copier count or recent PnL, search by label /
/// address, and follow any broadcaster with copy settings.
class BroadcastersPage extends ConsumerStatefulWidget {
  const BroadcastersPage({super.key});

  @override
  ConsumerState<BroadcastersPage> createState() => _BroadcastersPageState();
}

class _BroadcastersPageState extends ConsumerState<BroadcastersPage> {
  final _searchController = TextEditingController();
  String _sort = 'earnings';
  String _query = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(copyTradingProvider.notifier).loadDiscover(sort: _sort),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applySort(String sort) {
    if (_sort == sort) return;
    setState(() => _sort = sort);
    ref.read(copyTradingProvider.notifier).loadDiscover(sort: sort);
  }

  List<LeaderProfile> _filtered(List<LeaderProfile> all) {
    if (_query.isEmpty) return all;
    final q = _query.toLowerCase();
    return all
        .where(
          (l) =>
              l.displayLabel.toLowerCase().contains(q) ||
              l.address.toLowerCase().contains(q) ||
              (l.twitter?.toLowerCase().contains(q) ?? false),
        )
        .toList();
  }

  void _follow(LeaderProfile leader) {
    final phoenixAuth = ref.read(phoenixAuthProvider);
    if (phoenixAuth.isExternalWallet) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Use Dream\'s embedded wallet to unlock copy trading automation.',
          ),
          backgroundColor: context.dreamColors.surfaceVariant,
        ),
      );
      return;
    }

    CopySettingsSheet.show(
      context,
      leader: leader,
      onConfirm: (settings) {
        ref.read(copyTradingProvider.notifier).followLeader(leader, settings);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Now copying ${leader.displayLabel}'),
              backgroundColor: context.dreamColors.surfaceVariant,
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.dreamColors;
    final state = ref.watch(copyTradingProvider);
    final phoenixAuth = ref.watch(phoenixAuthProvider);
    final isExternalWallet = phoenixAuth.isExternalWallet;
    final leaders = _filtered(state.discover);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            PhosphorIcons.caretLeft(PhosphorIconsStyle.bold),
            color: colors.onSurface,
            size: 20.r,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Live Broadcasters',
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 17.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 0),
            child: _SearchField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          SizedBox(height: 12.h),
          _SortBar(active: _sort, onSelect: _applySort),
          if (isExternalWallet) ...[
            SizedBox(height: 12.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: const _WalletEligibilityBanner(),
            ),
          ],
          SizedBox(height: 8.h),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: colors.surfaceVariant,
              onRefresh: () => ref
                  .read(copyTradingProvider.notifier)
                  .loadDiscover(sort: _sort),
              child: _buildBody(state, leaders, isExternalWallet),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    CopyTradingState state,
    List<LeaderProfile> leaders,
    bool isExternalWallet,
  ) {
    if (state.isLoadingDiscover && state.discover.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
      );
    }
    if (leaders.isEmpty) {
      return _EmptyDirectory(hasQuery: _query.isNotEmpty);
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        20.w,
        12.h,
        20.w,
        MediaQuery.paddingOf(context).bottom + 24.h,
      ),
      itemCount: leaders.length,
      separatorBuilder: (_, _) => SizedBox(height: 10.h),
      itemBuilder: (_, i) {
        final leader = leaders[i];
        final isFollowing = state.following.any(
          (f) => f.leader.address == leader.address,
        );
        return _BroadcasterCard(
          leader: leader,
          isFollowing: isFollowing,
          isDisabled: isExternalWallet,
          onFollow: isFollowing || isExternalWallet
              ? null
              : () => _follow(leader),
        );
      },
    );
  }
}

// ── Search ────────────────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = context.dreamColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: colors.stroke),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(color: colors.onSurface, fontSize: 13.sp),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 12.w,
            vertical: 12.h,
          ),
          border: InputBorder.none,
          hintText: 'Search by name, address or @handle',
          hintStyle: TextStyle(color: colors.mutedSecondary, fontSize: 13.sp),
          prefixIcon: Icon(
            PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.bold),
            size: 16.r,
            color: colors.mutedSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Sort bar ──────────────────────────────────────────────────────────────────

class _SortBar extends StatelessWidget {
  final String active;
  final ValueChanged<String> onSelect;

  const _SortBar({required this.active, required this.onSelect});

  static const _options = <(String, String)>[
    ('earnings', 'Top earners'),
    ('copiers', 'Most copied'),
    ('pnl', 'Best PnL'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        itemCount: _options.length,
        separatorBuilder: (_, _) => SizedBox(width: 8.w),
        itemBuilder: (_, i) {
          final (value, label) = _options[i];
          final selected = value == active;
          final colors = context.dreamColors;
          return GestureDetector(
            onTap: () => onSelect(value),
            child: Container(
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.14)
                    : colors.surfaceVariant,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: selected ? AppColors.primary : colors.stroke,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.primary : colors.muted,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Broadcaster card ──────────────────────────────────────────────────────────

class _BroadcasterCard extends StatelessWidget {
  final LeaderProfile leader;
  final bool isFollowing;
  final bool isDisabled;
  final VoidCallback? onFollow;

  const _BroadcasterCard({
    required this.leader,
    required this.isFollowing,
    required this.isDisabled,
    required this.onFollow,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.dreamColors;
    final pnlColor = leader.pnl7d >= 0 ? AppColors.bullish : AppColors.bearish;
    final marketSummary = leader.openPositions.isEmpty
        ? 'No open positions'
        : leader.openPositions
              .take(2)
              .map((p) => p.market.replaceAll('-PERP', ''))
              .join(' · ');

    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: colors.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(label: leader.displayLabel),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            leader.displayLabel,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.onSurface,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (leader.hasPnlHistory)
                          Text(
                            formatPnl(leader.pnl7d),
                            style: TextStyle(
                              color: pnlColor,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w800,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      leader.strategy?.isNotEmpty == true
                          ? leader.strategy!
                          : marketSummary,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.mutedSecondary,
                        fontSize: 11.sp,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10.w),
              _FollowButton(
                isFollowing: isFollowing,
                isDisabled: isDisabled,
                onTap: onFollow,
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Container(height: 1, color: colors.stroke.withValues(alpha: 0.5)),
          SizedBox(height: 12.h),
          Row(
            children: [
              _Stat(
                label: 'earned',
                value: formatUsdc(leader.lifetimeUsd),
                valueColor: colors.success,
              ),
              _Stat(label: 'copiers', value: '${leader.copierCount}'),
              _Stat(
                label: 'win',
                value: leader.hasTradeStats
                    ? '${(leader.winRate * 100).toStringAsFixed(0)}%'
                    : '--',
              ),
              _Stat(
                label: 'equity',
                value: leader.equity > 0 ? formatCompact(leader.equity) : '--',
                isLast: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FollowButton extends StatelessWidget {
  final bool isFollowing;
  final bool isDisabled;
  final VoidCallback? onTap;

  const _FollowButton({
    required this.isFollowing,
    required this.isDisabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.dreamColors;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
        decoration: BoxDecoration(
          color: isFollowing
              ? Colors.transparent
              : isDisabled
              ? colors.stroke.withValues(alpha: 0.12)
              : AppColors.primary.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isFollowing
                ? colors.stroke
                : isDisabled
                ? colors.stroke
                : AppColors.primary,
          ),
        ),
        child: Text(
          isFollowing
              ? 'Following'
              : isDisabled
              ? 'Embedded only'
              : 'Copy',
          style: TextStyle(
            color: isFollowing
                ? colors.mutedSecondary
                : isDisabled
                ? colors.mutedSecondary
                : AppColors.primary,
            fontSize: 12.sp,
            fontWeight: FontWeight.w800,
          ),
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

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isLast;

  const _Stat({
    required this.label,
    required this.value,
    this.valueColor,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.dreamColors;
    return Expanded(
      child: Column(
        crossAxisAlignment: isLast
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? colors.onSurface,
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: TextStyle(
              color: colors.mutedSecondary,
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String label;
  const _Avatar({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34.r,
      height: 34.r,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.14),
      ),
      child: Text(
        label.substring(0, 1).toUpperCase(),
        style: TextStyle(
          color: AppColors.primaryLight,
          fontSize: 13.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyDirectory extends StatelessWidget {
  final bool hasQuery;
  const _EmptyDirectory({required this.hasQuery});

  @override
  Widget build(BuildContext context) {
    final colors = context.dreamColors;
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 80.h),
      children: [
        Icon(
          PhosphorIcons.broadcast(PhosphorIconsStyle.duotone),
          size: 40.r,
          color: colors.mutedSecondary.withValues(alpha: 0.5),
        ),
        SizedBox(height: 14.h),
        Text(
          hasQuery ? 'No matching broadcasters' : 'No live broadcasters yet',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.muted,
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 6.h),
        Text(
          hasQuery
              ? 'Try a different name or wallet address.'
              : 'Traders can register from Settings → Broadcasting\nto appear here and start earning.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.mutedSecondary,
            fontSize: 12.sp,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
