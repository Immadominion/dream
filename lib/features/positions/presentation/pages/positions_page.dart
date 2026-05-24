import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../navigation/providers/bottom_nav_providers.dart';
import '../../providers/positions_provider.dart';
import '../widgets/order_tile.dart';
import '../widgets/position_card.dart';

class PositionsPage extends ConsumerWidget {
  const PositionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(positionsProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(bottom: false, child: _Body(state: state)),
    );
  }
}

class _Body extends ConsumerWidget {
  final PositionsState state;
  const _Body({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoading && state.positions.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (state.error != null && state.positions.isEmpty) {
      return _ErrorView(
        error: state.error!,
        onRetry: () => ref.read(positionsProvider.notifier).refresh(),
      );
    }

    if (state.isNotRegistered) {
      return _NotRegisteredView(
        onRegisterTap: () =>
            ref.read(bottomNavIndexProvider.notifier).setIndex(3),
      );
    }

    final positions = state.positions;
    final orders = state.openOrders;

    if (positions.isEmpty && orders.isEmpty) {
      return _EmptyView();
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surfaceDark,
      onRefresh: () => ref.read(positionsProvider.notifier).refresh(),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16.w,
          16.h,
          16.w,
          MediaQuery.paddingOf(context).bottom + 24.h,
        ),
        children: [
          if (positions.isNotEmpty) ...[
            _SectionLabel(label: 'Open Positions (${positions.length})'),
            SizedBox(height: 8.h),
            ...positions.map((p) => PositionCard(position: p)),
            SizedBox(height: 16.h),
          ],
          if (orders.isNotEmpty) ...[
            _SectionLabel(label: 'Open Orders (${orders.length})'),
            SizedBox(height: 8.h),
            ...orders.map((o) => OrderTile(order: o)),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: AppColors.textSecondaryDark,
        fontSize: 12.sp,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _NotRegisteredView extends StatelessWidget {
  final VoidCallback onRegisterTap;
  const _NotRegisteredView({required this.onRegisterTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_add_outlined,
              color: AppColors.primary,
              size: 48.sp,
            ),
            SizedBox(height: 16.h),
            Text(
              'Account Not Registered',
              style: TextStyle(
                color: AppColors.textPrimaryDark,
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'You need a Phoenix account to trade.\nGo to Account to activate with an invite code.',
              style: TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 13.sp,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20.h),
            SizedBox(
              width: double.infinity,
              height: 44.h,
              child: ElevatedButton(
                onPressed: onRegisterTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: Text(
                  'Activate Account',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bar_chart,
            color: AppColors.textSecondaryDark,
            size: 48.sp,
          ),
          SizedBox(height: 12.h),
          Text(
            'No open positions',
            style: TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'Your positions will appear here\nonce you open a trade.',
            style: TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 13.sp,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20.h),
          TextButton(
            onPressed: () =>
                ref.read(bottomNavIndexProvider.notifier).setIndex(1),
            child: Text(
              'Start Trading →',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off,
              color: AppColors.textSecondaryDark,
              size: 40.sp,
            ),
            SizedBox(height: 12.h),
            Text(
              error,
              style: TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 14.sp,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.h),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
