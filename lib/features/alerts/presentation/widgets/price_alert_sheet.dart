import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/price_alerts_provider.dart';
import 'price_alert_widgets.dart';

// ---------------------------------------------------------------------------
// Bottom sheet — add alerts, view / delete active alerts
// ---------------------------------------------------------------------------

class PriceAlertSheet extends ConsumerStatefulWidget {
  final String symbol;
  const PriceAlertSheet({super.key, required this.symbol});

  @override
  ConsumerState<PriceAlertSheet> createState() => _PriceAlertSheetState();
}

class _PriceAlertSheetState extends ConsumerState<PriceAlertSheet> {
  final _priceCtrl = TextEditingController();
  AlertDirection _direction = AlertDirection.above;
  String? _inputError;
  bool _permissionGranted = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final granted = await ref
        .read(notificationServiceProvider)
        .areNotificationsEnabled;
    if (mounted) setState(() => _permissionGranted = granted);
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    super.dispose();
  }

  void _addAlert() {
    final input = _priceCtrl.text.trim();
    final price = double.tryParse(input);
    if (price == null || price <= 0) {
      setState(() => _inputError = 'Enter a valid price');
      return;
    }
    ref
        .read(priceAlertsProvider.notifier)
        .addAlert(
          symbol: widget.symbol,
          targetPrice: price,
          direction: _direction,
        );
    _priceCtrl.clear();
    setState(() => _inputError = null);
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Alert set for ${widget.symbol}'),
        backgroundColor: AppColors.bullish,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final alerts = ref.watch(priceAlertsProvider);
    final symbolAlerts =
        alerts.alerts.where((a) => a.symbol == widget.symbol).toList()
          ..sort((a, b) => a.targetPrice.compareTo(b.targetPrice));

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 20.h),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: AppColors.borderDark,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Row(
                children: [
                  Icon(
                    Icons.notifications_active,
                    color: AppColors.primary,
                    size: 18.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'Price Alerts · ${widget.symbol}',
                    style: TextStyle(
                      color: AppColors.textPrimaryDark,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              if (!_permissionGranted) ...[
                PriceAlertPermissionBanner(
                  onRequest: () async {
                    final granted = await ref
                        .read(notificationServiceProvider)
                        .requestPermission();
                    if (mounted) {
                      setState(() => _permissionGranted = granted);
                    }
                  },
                ),
                SizedBox(height: 12.h),
              ],
              Row(
                children: [
                  PriceAlertDirectionChip(
                    label: '↑ Price rises above',
                    selected: _direction == AlertDirection.above,
                    onTap: () =>
                        setState(() => _direction = AlertDirection.above),
                  ),
                  SizedBox(width: 8.w),
                  PriceAlertDirectionChip(
                    label: '↓ Price falls below',
                    selected: _direction == AlertDirection.below,
                    onTap: () =>
                        setState(() => _direction = AlertDirection.below),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      style: TextStyle(
                        color: AppColors.textPrimaryDark,
                        fontSize: 15.sp,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Target price (USD)',
                        hintStyle: TextStyle(
                          color: AppColors.textMutedDark,
                          fontSize: 14.sp,
                        ),
                        errorText: _inputError,
                        prefixText: '\$',
                        prefixStyle: TextStyle(
                          color: AppColors.textSecondaryDark,
                          fontSize: 15.sp,
                        ),
                        filled: true,
                        fillColor: AppColors.cardDark,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 12.h,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                          borderSide: BorderSide(color: AppColors.borderDark),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                          borderSide: BorderSide(color: AppColors.borderDark),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                          borderSide: BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  ElevatedButton(
                    onPressed: _addAlert,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 14.h,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    child: Text(
                      'Set',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (symbolAlerts.isNotEmpty) ...[
                SizedBox(height: 16.h),
                Text(
                  'Active & Recent',
                  style: TextStyle(
                    color: AppColors.textSecondaryDark,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 8.h),
                ...symbolAlerts.map(
                  (alert) => PriceAlertRow(
                    alert: alert,
                    onDelete: () => ref
                        .read(priceAlertsProvider.notifier)
                        .removeAlert(alert.id),
                  ),
                ),
              ],
            ],
            ),
          ),
        ),
      ),
    );
  }
}
