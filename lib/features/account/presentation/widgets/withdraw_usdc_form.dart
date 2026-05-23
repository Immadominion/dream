import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';

// ---------------------------------------------------------------------------
// Pure UI form body for the Withdraw USDC sheet.
// All business logic lives in WithdrawUsdcSheet / _WithdrawUsdcSheetState.
// ---------------------------------------------------------------------------

class WithdrawUsdcFormBody extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController destController;
  final TextEditingController amountController;
  final double balance;
  final bool loadingBalance;
  final bool submitting;
  final String? submitError;
  final VoidCallback onPaste;
  final VoidCallback onSetMax;
  final VoidCallback onSubmit;
  final FormFieldValidator<String> validateDest;
  final FormFieldValidator<String> validateAmount;

  const WithdrawUsdcFormBody({
    super.key,
    required this.formKey,
    required this.destController,
    required this.amountController,
    required this.balance,
    required this.loadingBalance,
    required this.submitting,
    required this.submitError,
    required this.onPaste,
    required this.onSetMax,
    required this.onSubmit,
    required this.validateDest,
    required this.validateAmount,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
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
            'Withdraw USDC',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Send USDC to any Solana wallet',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 12.sp,
            ),
          ),
          SizedBox(height: 20.h),

          // Available balance row
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: AppColors.backgroundDark,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: Row(
              children: [
                Text(
                  'Available',
                  style: TextStyle(
                    color: AppColors.textMutedDark,
                    fontSize: 12.sp,
                  ),
                ),
                const Spacer(),
                Text(
                  loadingBalance
                      ? '...'
                      : '\$${balance.toStringAsFixed(2)} USDC',
                  style: TextStyle(
                    color: AppColors.textPrimaryDark,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 14.h),

          // Destination address
          Text(
            'Destination address',
            style: TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6.h),
          TextFormField(
            controller: destController,
            enabled: !submitting,
            style: TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 13.sp,
              fontFamily: 'monospace',
            ),
            decoration: _inputDecoration(
              hint: 'Solana wallet address',
              suffix: TextButton(
                onPressed: submitting ? null : onPaste,
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: EdgeInsets.symmetric(horizontal: 10.w),
                ),
                child: Text(
                  'Paste',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            validator: validateDest,
            autocorrect: false,
            textInputAction: TextInputAction.next,
          ),
          SizedBox(height: 14.h),

          // Amount
          Text(
            'Amount (USDC)',
            style: TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6.h),
          TextFormField(
            controller: amountController,
            enabled: !submitting,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,6}')),
            ],
            style: TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
            ),
            decoration: _inputDecoration(
              hint: '0.00',
              suffix: TextButton(
                onPressed: (submitting || balance <= 0) ? null : onSetMax,
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: EdgeInsets.symmetric(horizontal: 10.w),
                ),
                child: Text(
                  'MAX',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            validator: validateAmount,
          ),

          // Error banner
          if (submitError != null) ...[
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: AppColors.bearish.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(
                  color: AppColors.bearish.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 14.sp,
                    color: AppColors.bearish,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      submitError!,
                      style: TextStyle(
                        color: AppColors.textPrimaryDark,
                        fontSize: 11.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          SizedBox(height: 16.h),

          // Network fee warning
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: AppColors.borderDark.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              'A small SOL amount is required to pay the network fee. '
              'If the recipient has never received USDC, an extra ~0.002 SOL '
              'will be used to create their token account.',
              style: TextStyle(
                color: AppColors.textMutedDark,
                fontSize: 11.sp,
                height: 1.4,
              ),
            ),
          ),
          SizedBox(height: 16.h),

          // Submit button
          ElevatedButton(
            onPressed: submitting ? null : onSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
              padding: EdgeInsets.symmetric(vertical: 14.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: submitting
                ? SizedBox(
                    width: 18.w,
                    height: 18.w,
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'Send USDC',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint, Widget? suffix}) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10.r),
      borderSide: BorderSide(color: AppColors.borderDark),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: AppColors.textMutedDark,
        fontSize: 13.sp,
        fontFamily: hint == '0.00' ? null : 'monospace',
      ),
      filled: true,
      fillColor: AppColors.backgroundDark,
      contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: border.copyWith(
        borderSide: BorderSide(color: AppColors.bearish),
      ),
      focusedErrorBorder: border.copyWith(
        borderSide: BorderSide(color: AppColors.bearish, width: 1.5),
      ),
      suffixIcon: suffix,
      suffixIconConstraints: BoxConstraints(minHeight: 32.h, minWidth: 32.w),
    );
  }
}
