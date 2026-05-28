import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../widgets/account_leaderboard_card.dart';
import '../../../../core/theme/dream_colors.dart';

class LeaderboardPage extends ConsumerWidget {
  final String walletAddress;
  const LeaderboardPage({super.key, required this.walletAddress});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: context.dreamColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: EdgeInsets.all(8.r),
                      decoration: BoxDecoration(
                        color: context.dreamColors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: context.dreamColors.stroke),
                      ),
                      child: Icon(
                        PhosphorIcons.arrowLeft(PhosphorIconsStyle.bold),
                        color: context.dreamColors.onSurface,
                        size: 24.sp,
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Text(
                    'Trader Leaderboard',
                    style: TextStyle(
                      color: context.dreamColors.onSurface,
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 40.h),
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20.w),
                    decoration: BoxDecoration(
                      color: context.dreamColors.surface,
                      borderRadius: BorderRadius.circular(26.r),
                      border: Border.all(color: context.dreamColors.stroke),
                    ),
                    child: AccountLeaderboardCard(walletAddress: walletAddress),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
