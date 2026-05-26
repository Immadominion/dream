import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/intelligence_models.dart';
import '../../providers/copy_trading_provider.dart';
import '../widgets/copy_settings_sheet.dart';
import '../widgets/leader_card.dart';

class CopyTradePage extends ConsumerStatefulWidget {
  const CopyTradePage({super.key});

  @override
  ConsumerState<CopyTradePage> createState() => _CopyTradePageState();
}

class _CopyTradePageState extends ConsumerState<CopyTradePage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    // Load leaders once when page first appears
    Future.microtask(
      () => ref.read(copyTradingProvider.notifier).loadDiscover(),
    );
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(copyTradingProvider);

    return Column(
      children: [
        // Tab bar
        Container(
          margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          height: 36.h,
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: AppColors.borderDark),
          ),
          child: TabBar(
            controller: _tab,
            indicator: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8.r),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.textSecondaryDark,
            labelStyle: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600),
            tabs: [
              Tab(text: 'Discover (${state.discover.length})'),
              Tab(text: 'Following (${state.following.length})'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _DiscoverTab(state: state),
              _FollowingTab(state: state),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Discover tab ───────────────────────────────────────────────────────────

class _DiscoverTab extends ConsumerWidget {
  final CopyTradingState state;
  const _DiscoverTab({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoadingDiscover) {
      return Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 2,
        ),
      );
    }

    if (state.discover.isEmpty) {
      return _EmptyDiscover(
        onRefresh: () => ref.read(copyTradingProvider.notifier).loadDiscover(),
      );
    }

    final followingAddresses =
        state.following.map((f) => f.leader.address).toSet();

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.cardDark,
      onRefresh: () => ref.read(copyTradingProvider.notifier).loadDiscover(),
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 100.h),
        itemCount: state.discover.length,
        itemBuilder: (_, i) {
          final leader = state.discover[i];
          final isFollowing = followingAddresses.contains(leader.address);
          return LeaderCard(
            leader: leader,
            isFollowing: isFollowing,
            onFollow: isFollowing
                ? null
                : () => _handleFollow(context, ref, leader),
          );
        },
      ),
    );
  }

  void _handleFollow(
    BuildContext context,
    WidgetRef ref,
    LeaderProfile leader,
  ) {
    CopySettingsSheet.show(
      context,
      leader: leader,
      onConfirm: (settings) {
        ref.read(copyTradingProvider.notifier).followLeader(leader, settings);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Now copying ${leader.displayLabel}'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }
}

class _EmptyDiscover extends StatelessWidget {
  final VoidCallback onRefresh;
  const _EmptyDiscover({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            PhosphorIcons.users(PhosphorIconsStyle.duotone),
            size: 48.r,
            color: AppColors.textMutedDark,
          ),
          SizedBox(height: 16.h),
          Text(
            'No leaders found',
            style: TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Pull to refresh or check your connection.',
            style: TextStyle(
              color: AppColors.textMutedDark,
              fontSize: 12.sp,
            ),
          ),
          SizedBox(height: 20.h),
          TextButton(
            onPressed: onRefresh,
            child: Text(
              'Refresh',
              style: TextStyle(color: AppColors.primary, fontSize: 13.sp),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Following tab ──────────────────────────────────────────────────────────

class _FollowingTab extends ConsumerWidget {
  final CopyTradingState state;
  const _FollowingTab({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.following.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PhosphorIcons.copy(PhosphorIconsStyle.duotone),
              size: 48.r,
              color: AppColors.textMutedDark,
            ),
            SizedBox(height: 16.h),
            Text(
              'Not following anyone',
              style: TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Discover top traders and follow them to mirror their trades.',
              style: TextStyle(
                color: AppColors.textMutedDark,
                fontSize: 12.sp,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 100.h),
      itemCount: state.following.length,
      itemBuilder: (_, i) {
        final followed = state.following[i];
        return _FollowedCard(followed: followed);
      },
    );
  }
}

class _FollowedCard extends ConsumerWidget {
  final FollowedLeader followed;
  const _FollowedCard({required this.followed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPaused = followed.isPaused;

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isPaused
              ? AppColors.borderDark
              : AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _StatusDot(active: !isPaused),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      followed.leader.displayLabel,
                      style: TextStyle(
                        color: AppColors.textPrimaryDark,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '\$${followed.settings.copyUSDC.toStringAsFixed(0)} USDC / trade',
                      style: TextStyle(
                        color: AppColors.textSecondaryDark,
                        fontSize: 11.sp,
                      ),
                    ),
                  ],
                ),
              ),
              _ActionMenu(followed: followed),
            ],
          ),
          if (followed.gainSinceFollow != 0) ...[
            SizedBox(height: 8.h),
            Row(
              children: [
                Text(
                  'Since follow: ',
                  style: TextStyle(
                    color: AppColors.textMutedDark,
                    fontSize: 11.sp,
                  ),
                ),
                Text(
                  '${followed.gainSinceFollow >= 0 ? '+' : ''}'
                  '\$${followed.gainSinceFollow.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: followed.gainSinceFollow >= 0
                        ? AppColors.bullish
                        : AppColors.bearish,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final bool active;
  const _StatusDot({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8.r,
      height: 8.r,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? AppColors.success : AppColors.textMutedDark,
        boxShadow: active
            ? [
                BoxShadow(
                  color: AppColors.success.withValues(alpha: 0.5),
                  blurRadius: 6,
                ),
              ]
            : null,
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
        color: AppColors.textSecondaryDark,
        size: 18.r,
      ),
      color: AppColors.cardDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.r),
        side: BorderSide(color: AppColors.borderDark),
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
    final c = color ?? AppColors.textPrimaryDark;
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
