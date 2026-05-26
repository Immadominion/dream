import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import 'ai_trading_page.dart';
import 'copy_trade_page.dart';

/// Top-level Intelligence tab — hosts Copy Trading and AI Bot sub-tabs.
class IntelligenceTabPage extends ConsumerStatefulWidget {
  const IntelligenceTabPage({super.key});

  @override
  ConsumerState<IntelligenceTabPage> createState() =>
      _IntelligenceTabPageState();
}

class _IntelligenceTabPageState extends ConsumerState<IntelligenceTabPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            _Header(tab: _tab),
            // Content
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: const [
                  CopyTradePage(),
                  AITradingPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final TabController tab;
  const _Header({required this.tab});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                PhosphorIcons.brain(PhosphorIconsStyle.duotone),
                color: AppColors.primary,
                size: 22.r,
              ),
              SizedBox(width: 8.w),
              Text(
                'Intelligence',
                style: TextStyle(
                  color: AppColors.textPrimaryDark,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          // Tab selector
          Container(
            height: 38.h,
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: TabBar(
              controller: tab,
              indicator: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8.r),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textSecondaryDark,
              labelStyle: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        PhosphorIcons.copy(PhosphorIconsStyle.bold),
                        size: 14.r,
                      ),
                      SizedBox(width: 5.w),
                      const Text('Copy Trade'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        PhosphorIcons.robot(PhosphorIconsStyle.bold),
                        size: 14.r,
                      ),
                      SizedBox(width: 5.w),
                      const Text('AI Bot'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10.h),
        ],
      ),
    );
  }
}
