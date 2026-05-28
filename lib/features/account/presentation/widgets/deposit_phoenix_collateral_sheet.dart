import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/providers/wallet/wallet_balance_provider.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/phoenix/phoenix_collateral_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../positions/providers/positions_provider.dart';

class DepositPhoenixCollateralSheet extends ConsumerStatefulWidget {
  final String walletAddress;
  final double? initialAmountUsdc;

  const DepositPhoenixCollateralSheet({
    super.key,
    required this.walletAddress,
    this.initialAmountUsdc,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String walletAddress,
    double? initialAmountUsdc,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (_) => DepositPhoenixCollateralSheet(
        walletAddress: walletAddress,
        initialAmountUsdc: initialAmountUsdc,
      ),
    );
  }

  @override
  ConsumerState<DepositPhoenixCollateralSheet> createState() =>
      _DepositPhoenixCollateralSheetState();
}

class _DepositPhoenixCollateralSheetState
    extends ConsumerState<DepositPhoenixCollateralSheet> {
  late final TextEditingController _amountController;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialAmountUsdc;
    _amountController = TextEditingController(
      text: initial != null && initial > 0 ? _formatInput(initial) : '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double get _amount => double.tryParse(_amountController.text.trim()) ?? 0;

  Future<void> _submit(double walletUsdc) async {
    final amount = _amount;
    final previousCollateral =
        ref.read(positionsProvider).traderState?.collateral ?? 0.0;

    if (amount <= 0) {
      setState(() => _error = 'Enter an amount greater than 0');
      return;
    }
    if (amount > walletUsdc + 0.000001) {
      setState(() => _error = 'Amount is higher than your wallet USDC');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final result = await ref
        .read(phoenixCollateralServiceProvider)
        .depositUsdc(authority: widget.walletAddress, amountUsdc: amount);

    if (!mounted) return;

    setState(() => _submitting = false);

    if (!result.success) {
      setState(() => _error = result.error ?? 'Deposit failed');
      return;
    }

    ref.invalidate(walletUsdcBalanceProvider(widget.walletAddress));
    final synced = await _refreshCollateralState(
      minimumCollateral: previousCollateral + amount,
    );
    await ref
        .read(notificationServiceProvider)
        .showPhoenixCollateralDepositNotification(amountUsdc: amount);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          synced
              ? 'Phoenix collateral funded'
              : 'Deposit confirmed. Phoenix balance is still syncing.',
        ),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16.w),
      ),
    );
    Navigator.of(context).pop(true);
  }

  Future<bool> _refreshCollateralState({
    required double minimumCollateral,
    int maxAttempts = 8,
  }) async {
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      await ref.read(positionsProvider.notifier).refresh();
      final currentCollateral =
          ref.read(positionsProvider).traderState?.collateral ?? 0.0;

      if (currentCollateral + 0.000001 >= minimumCollateral) {
        return true;
      }

      if (attempt < maxAttempts - 1) {
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }

    return false;
  }

  void _setMax(double walletUsdc) {
    _amountController.text = _formatInput(walletUsdc);
    _amountController.selection = TextSelection.fromPosition(
      TextPosition(offset: _amountController.text.length),
    );
    setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(
      walletUsdcBalanceProvider(widget.walletAddress),
    );
    final walletUsdc = walletAsync.value ?? 0.0;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                margin: EdgeInsets.only(bottom: 16.h),
                decoration: BoxDecoration(
                  color: AppColors.borderDark,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            Text(
              'Deposit to Phoenix',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimaryDark,
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Move Solana USDC from your Dream wallet into tradable Phoenix collateral',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 12.sp,
              ),
            ),
            SizedBox(height: 18.h),
            _BalanceRow(
              label: 'Wallet USDC',
              value: walletAsync.isLoading ? '...' : formatUsdc(walletUsdc),
            ),
            SizedBox(height: 14.h),
            TextField(
              controller: _amountController,
              enabled: !_submitting,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,6}')),
              ],
              style: TextStyle(
                color: AppColors.textPrimaryDark,
                fontSize: 22.sp,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                labelText: 'Amount',
                suffixText: 'USDC',
                suffixStyle: TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
                filled: true,
                fillColor: AppColors.cardDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: AppColors.borderDark),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: AppColors.borderDark),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: AppColors.primary),
                ),
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
            SizedBox(height: 10.h),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _submitting || walletUsdc <= 0
                    ? null
                    : () => _setMax(walletUsdc),
                child: const Text('Max'),
              ),
            ),
            if (_error != null) ...[
              SizedBox(height: 6.h),
              Text(
                _error!,
                style: TextStyle(color: AppColors.bearish, fontSize: 12.sp),
              ),
            ],
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: _submitting || walletAsync.isLoading
                  ? null
                  : () => _submit(walletUsdc),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: _submitting
                  ? SizedBox(
                      height: 18.r,
                      width: 18.r,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Deposit'),
            ),
            SizedBox(height: 12.h),
            Text(
              'This uses your current Dream wallet. Keep a small SOL balance for network fees.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMutedDark,
                fontSize: 11.sp,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  final String label;
  final String value;

  const _BalanceRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 12.sp,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatInput(double value) {
  return value.toStringAsFixed(6).replaceFirst(RegExp(r'\.?0+$'), '');
}
