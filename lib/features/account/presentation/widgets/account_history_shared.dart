import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lottie/lottie.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../navigation/providers/bottom_nav_providers.dart';
import '../../../../core/theme/dream_colors.dart';

const accountHistoryScrollPhysics = AlwaysScrollableScrollPhysics(
  parent: BouncingScrollPhysics(),
);

Widget buildAccountHistoryFallbackScrollView({required Widget child}) {
  return CustomScrollView(
    physics: accountHistoryScrollPhysics,
    slivers: [
      SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 40.h),
          child: Center(child: child),
        ),
      ),
    ],
  );
}

class AccountHistoryEmptyState extends ConsumerWidget {
  final String title;
  final String description;
  final String ctaLabel;
  final int targetTabIndex;

  const AccountHistoryEmptyState({
    super.key,
    required this.title,
    required this.description,
    this.ctaLabel = 'Start Trading →',
    this.targetTabIndex = 1,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Lottie.asset(
          'assets/images/empty.json',
          width: 132.r,
          height: 132.r,
          fit: BoxFit.contain,
          repeat: true,
        ),
        SizedBox(height: 2.h),
        Text(
          title,
          style: TextStyle(
            color: context.dreamColors.onSurface,
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 6.h),
        Text(
          description,
          style: TextStyle(color: context.dreamColors.muted, fontSize: 13.sp),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 20.h),
        TextButton(
          onPressed: () {
            ref.read(bottomNavIndexProvider.notifier).setIndex(targetTabIndex);
            Navigator.of(context).maybePop();
          },
          child: Text(
            ctaLabel,
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class AccountHistoryErrorState extends StatelessWidget {
  final String title;
  final String description;

  const AccountHistoryErrorState({
    super.key,
    this.title = 'Unable to load history',
    this.description = 'Pull down to try again.',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          PhosphorIcons.warningCircle(PhosphorIconsStyle.bold),
          color: context.dreamColors.muted,
          size: 34.sp,
        ),
        SizedBox(height: 12.h),
        Text(
          title,
          style: TextStyle(
            color: context.dreamColors.onSurface,
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 6.h),
        Text(
          description,
          style: TextStyle(color: context.dreamColors.muted, fontSize: 13.sp),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

DateTime? parseAccountHistoryDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is int) {
    final milliseconds = value > 9999999999 ? value : value * 1000;
    return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
  }
  if (value is String) {
    final parsedInt = int.tryParse(value);
    if (parsedInt != null) {
      return parseAccountHistoryDateTime(parsedInt);
    }
    return DateTime.tryParse(value);
  }
  return null;
}

String formatAccountHistoryDate(dynamic value) {
  final parsed = parseAccountHistoryDateTime(value)?.toLocal();
  if (parsed == null) return 'Unknown time';

  final month = _monthNames[parsed.month - 1];
  final day = parsed.day;
  final suffix = _daySuffix(day);
  final hour = parsed.hour.toString().padLeft(2, '0');
  final minute = parsed.minute.toString().padLeft(2, '0');
  final second = parsed.second.toString().padLeft(2, '0');
  return '$month $day$suffix, $hour:$minute:$second';
}

double parseAccountHistoryDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _daySuffix(int day) {
  if (day >= 11 && day <= 13) return 'th';
  return switch (day % 10) {
    1 => 'st',
    2 => 'nd',
    3 => 'rd',
    _ => 'th',
  };
}
