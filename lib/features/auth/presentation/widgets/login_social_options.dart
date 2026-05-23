import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/services/privy_sdk_service.dart';

class LoginSocialOptions extends StatelessWidget {
  const LoginSocialOptions({
    super.key,
    required this.isLoading,
    required this.onEmailSelected,
    required this.onSocialSelected,
    this.onWalletSelected,
  });

  final bool isLoading;
  final VoidCallback onEmailSelected;
  final ValueChanged<LoginMethod> onSocialSelected;
  final VoidCallback? onWalletSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttons = _buildButtonData();
    final showWalletConnect = Platform.isAndroid && onWalletSelected != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: isLoading
              ? null
              : () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  onEmailSelected();
                },
          style: FilledButton.styleFrom(
            minimumSize: Size.fromHeight(52.h),
            shape: const StadiumBorder(),
          ),
          child: Text('Continue with email', style: TextStyle(fontSize: 14.sp)),
        ),
        // Connect Wallet button - Android only
        if (showWalletConnect) ...[
          SizedBox(height: 16.h),
          OutlinedButton.icon(
            onPressed: isLoading ? null : onWalletSelected,
            label: Text('Connect Wallet', style: TextStyle(fontSize: 14.sp)),
            style: OutlinedButton.styleFrom(
              minimumSize: Size.fromHeight(52.h),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
              ),
              shape: const StadiumBorder(),
            ),
          ),
        ],
        SizedBox(height: 28.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Divider(
                height: 24.w,
                color: theme.colorScheme.onSurface.withAlpha(150),
              ),
            ),
            SizedBox(width: 6.h),
            Text(
              'Or sign in with',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.start,
            ),
            SizedBox(width: 6.h),
            Expanded(
              child: Divider(
                height: 24.h,
                color: theme.colorScheme.onSurface.withAlpha(150),
              ),
            ),
          ],
        ),

        SizedBox(height: 16.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: buttons
              .map(
                (data) => _PrivySocialButton(
                  data: data,
                  onTap: () => onSocialSelected(data.method),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  List<_SocialButtonData> _buildButtonData() {
    return [
      _SocialButtonData(
        method: LoginMethod.google,
        icon: PhosphorIcons.googleLogo(),
        style: SocialButtonStyle.outlined,
      ),

      ///Doing this would not make sense for now, as
      ///my apple account is an individual one, so even if it works,
      ///I can't upload this app to the store, cause all crypto processing
      /// apps need a company account.
      ///Will revisit this in the future.
      // _SocialButtonData(
      //   method: LoginMethod.apple,
      //   icon: PhosphorIcons.appleLogo(),
      //   style: SocialButtonStyle.outlined,
      // ),
      _SocialButtonData(
        method: LoginMethod.discord,
        icon: PhosphorIcons.discordLogo(),
        style: SocialButtonStyle.outlined,
      ),
      _SocialButtonData(
        method: LoginMethod.twitter,
        icon: PhosphorIcons.xLogo(),
        style: SocialButtonStyle.outlined,
      ),
    ];
  }
}

enum SocialButtonStyle { filled, outlined }

class _SocialButtonData {
  const _SocialButtonData({
    required this.method,
    required this.icon,
    required this.style,
  });

  final LoginMethod method;
  final IconData icon;
  final SocialButtonStyle style;
}

class _PrivySocialButton extends StatelessWidget {
  const _PrivySocialButton({required this.data, required this.onTap});

  final _SocialButtonData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFilled = data.style == SocialButtonStyle.filled;
    final backgroundColor = isFilled
        ? theme.colorScheme.onSurface
        : theme.colorScheme.surface;
    final foregroundColor = isFilled
        ? theme.colorScheme.surface
        : theme.colorScheme.onSurface;
    final borderSide = isFilled
        ? BorderSide.none
        : BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          );

    return Tooltip(
      message: 'Continue with ${data.method.name}',
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Ink(
            width: 56.r,
            height: 56.r,
            decoration: ShapeDecoration(
              color: backgroundColor,
              shape: CircleBorder(side: borderSide),
            ),
            child: Icon(data.icon, color: foregroundColor, size: 24.r),
          ),
        ),
      ),
    );
  }
}
