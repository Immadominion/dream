import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class LoginFooter extends StatelessWidget {
  const LoginFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Text(
        'By continuing you agree to our Terms of Service and Privacy Policy.',
        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
        textAlign: TextAlign.center,
      ),
    );
  }
}
