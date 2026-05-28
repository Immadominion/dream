import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import 'account_trade_order_tabs.dart';
import 'account_funding_collateral_tabs.dart';
import '../../../../core/theme/dream_colors.dart';

// ---------------------------------------------------------------------------
// History section — tabbed: Trades | Orders | Funding | Collateral
// ---------------------------------------------------------------------------

class AccountHistorySection extends ConsumerStatefulWidget {
  final String walletAddress;
  const AccountHistorySection({super.key, required this.walletAddress});

  @override
  ConsumerState<AccountHistorySection> createState() =>
      _AccountHistorySectionState();
}

class _AccountHistorySectionState extends ConsumerState<AccountHistorySection>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.primary,
            indicatorSize: TabBarIndicatorSize.label,
            indicatorWeight: 2.4,
            labelColor: context.dreamColors.onSurface,
            unselectedLabelColor: context.dreamColors.mutedSecondary,
            labelStyle: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
            unselectedLabelStyle: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
            ),
            dividerColor: Colors.transparent,
            labelPadding: EdgeInsets.only(right: 18.w),
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(text: 'Trades'),
              Tab(text: 'Orders'),
              Tab(text: 'Funding'),
              Tab(text: 'Collateral'),
            ],
          ),
        ),
        SizedBox(height: 10.h),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              AccountTradeHistoryTab(walletAddress: widget.walletAddress),
              AccountOrderHistoryTab(walletAddress: widget.walletAddress),
              AccountFundingHistoryTab(walletAddress: widget.walletAddress),
              AccountCollateralHistoryTab(walletAddress: widget.walletAddress),
            ],
          ),
        ),
      ],
    );
  }
}
