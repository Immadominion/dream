import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import 'account_funding_collateral_tabs.dart';
import 'account_history_providers.dart';
import 'account_trade_order_tabs.dart';

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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'History',
              style: TextStyle(
                color: AppColors.textPrimaryDark,
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            GestureDetector(
              onTap: () {
                ref.invalidate(
                  accountTradeHistoryProvider(widget.walletAddress),
                );
                ref.invalidate(
                  accountOrderHistoryProvider(widget.walletAddress),
                );
                ref.invalidate(
                  accountFundingHistoryProvider(widget.walletAddress),
                );
                ref.invalidate(
                  accountCollateralHistoryProvider(widget.walletAddress),
                );
              },
              child: Icon(
                Icons.refresh,
                color: AppColors.textMutedDark,
                size: 18.sp,
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: AppColors.borderDark),
          ),
          child: Column(
            children: [
              // Tab bar
              TabBar(
                controller: _tabController,
                indicatorColor: AppColors.primary,
                indicatorSize: TabBarIndicatorSize.label,
                labelColor: AppColors.textPrimaryDark,
                unselectedLabelColor: AppColors.textMutedDark,
                labelStyle: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w400,
                ),
                dividerColor: AppColors.borderDark,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: const [
                  Tab(text: 'Trades'),
                  Tab(text: 'Orders'),
                  Tab(text: 'Funding'),
                  Tab(text: 'Collateral'),
                ],
              ),
              // Tab content — fixed height to avoid nested scroll conflict
              SizedBox(
                height: 280.h,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    AccountTradeHistoryTab(walletAddress: widget.walletAddress),
                    AccountOrderHistoryTab(walletAddress: widget.walletAddress),
                    AccountFundingHistoryTab(
                      walletAddress: widget.walletAddress,
                    ),
                    AccountCollateralHistoryTab(
                      walletAddress: widget.walletAddress,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
