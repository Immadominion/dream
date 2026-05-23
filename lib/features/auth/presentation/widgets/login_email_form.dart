import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pinput/pinput.dart';

import '../../../../core/theme/app_colors.dart';

class LoginEmailForm extends StatelessWidget {
  const LoginEmailForm({
    super.key,
    required this.isLoading,
    required this.isOtpSent,
    required this.emailController,
    required this.otpController,
    required this.emailFocusNode,
    required this.otpFocusNode,
    required this.onSendOtp,
    required this.onVerifyOtp,
    required this.onResendOtp,
    required this.onBackToOptions,
  });

  final bool isLoading;
  final bool isOtpSent;
  final TextEditingController emailController;
  final TextEditingController otpController;
  final FocusNode emailFocusNode;
  final FocusNode otpFocusNode;
  final VoidCallback onSendOtp;
  final VoidCallback onVerifyOtp;
  final VoidCallback onResendOtp;
  final VoidCallback onBackToOptions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Continue with email',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 12.h),
        Text(
          'We will email you a six-digit code secured by Privy.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
        ),
        SizedBox(height: 24.h),
        TextField(
          controller: emailController,
          focusNode: emailFocusNode,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          enabled: !isOtpSent && !isLoading,
          onSubmitted: (_) {
            if (isOtpSent) {
              otpFocusNode.requestFocus();
            } else {
              onSendOtp();
            }
          },
          autofillHints: const [AutofillHints.email],
          decoration: InputDecoration(
            labelText: 'Email address',
            prefixIcon: Icon(PhosphorIcons.envelope()),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20.r),
            ),
          ),
        ),
        SizedBox(height: 16.h),
        if (isOtpSent) ...[
          Text(
            'Enter verification code',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 12.h),
          _buildPinput(context, colorScheme),
          SizedBox(height: 12.h),
          FilledButton(
            onPressed: isLoading ? null : onVerifyOtp,
            style: FilledButton.styleFrom(minimumSize: Size.fromHeight(52.h)),
            child: isLoading
                ? SizedBox(
                    height: 20.h,
                    width: 20.h,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Verify and continue'),
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: isLoading ? null : onResendOtp,
                icon: Icon(PhosphorIcons.arrowClockwise(), size: 16.sp),
                label: const Text('Resend code'),
              ),
              SizedBox(width: 8.w),
              Text('•', style: TextStyle(color: theme.hintColor)),
              SizedBox(width: 8.w),
              TextButton(
                onPressed: isLoading ? null : onBackToOptions,
                child: const Text('Back Home'),
              ),
            ],
          ),
        ] else ...[
          FilledButton(
            onPressed: isLoading ? null : onSendOtp,
            style: FilledButton.styleFrom(minimumSize: Size.fromHeight(52.h)),
            child: isLoading
                ? SizedBox(
                    height: 20.h,
                    width: 20.h,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Send verification code'),
          ),
          SizedBox(height: 12.h),
          TextButton(
            onPressed: isLoading ? null : onBackToOptions,
            child: const Text('Back to other options'),
          ),
        ],
      ],
    );
  }

  Widget _buildPinput(BuildContext context, ColorScheme colorScheme) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final defaultPinTheme = PinTheme(
      width: 48.w,
      height: 56.h,
      textStyle: theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurface,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          width: 1.5,
        ),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.primary.withOpacity(0.1)
            : AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.primary, width: 2),
      ),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.primary.withOpacity(0.15)
            : AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.5),
          width: 1.5,
        ),
      ),
    );

    final errorPinTheme = defaultPinTheme.copyWith(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.error.withOpacity(0.1)
            : AppColors.error.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.error, width: 2),
      ),
    );

    return Pinput(
      length: 6,
      controller: otpController,
      focusNode: otpFocusNode,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      animationCurve: Curves.easeOutCubic,
      animationDuration: const Duration(milliseconds: 200),
      defaultPinTheme: defaultPinTheme,
      focusedPinTheme: focusedPinTheme,
      submittedPinTheme: submittedPinTheme,
      errorPinTheme: errorPinTheme,
      pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
      showCursor: true,
      cursor: Container(
        width: 2,
        height: 24.h,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
      onCompleted: (pin) {
        // Auto-submit when all 6 digits are entered
        if (pin.length == 6) {
          onVerifyOtp();
        }
      },
      hapticFeedbackType: HapticFeedbackType.lightImpact,
      separatorBuilder: (index) => SizedBox(width: 8.w),
    );
  }
}
