import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class LoginHeader extends StatelessWidget {
  const LoginHeader({super.key, this.showCopy = true});

  final bool showCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Image.asset(
          'assets/images/dream-logo-tp.png',
          width: 88.r,
          height: 88.r,
          fit: BoxFit.fill,
        ),
        SizedBox(height: showCopy ? 24.h : 12.h),
        if (showCopy) ...[
          Text(
            'Dream',
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Trade perpetual futures on Solana.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ],
    );
  }
}
