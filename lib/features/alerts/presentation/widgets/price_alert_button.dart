import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../providers/price_alerts_provider.dart';
import 'price_alert_sheet.dart';

// ---------------------------------------------------------------------------
// Compact bell-icon button shown in trade page / markets header
// ---------------------------------------------------------------------------

class PriceAlertButton extends ConsumerWidget {
  final String symbol;
  const PriceAlertButton({super.key, required this.symbol});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(priceAlertsProvider);
    final active = alerts.activeAlerts(symbol);
    final hasAlerts = active.isNotEmpty;

    return GestureDetector(
      onTap: () => _showAlertSheet(context, symbol),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            hasAlerts ? Icons.notifications_active : Icons.notifications_none,
            color: hasAlerts ? AppColors.primary : AppColors.textSecondaryDark,
            size: 20.sp,
          ),
          if (hasAlerts)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: EdgeInsets.all(2.r),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${active.length}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

void _showAlertSheet(BuildContext context, String symbol) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surfaceDark,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
    ),
    builder: (_) => PriceAlertSheet(symbol: symbol),
  );
}
