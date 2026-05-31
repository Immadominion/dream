import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '../../core/theme/app_colors.dart';

/// Full-screen loading state used wherever a screen shows nothing but a spinner.
/// Use [DreamSpinner] to replace bare `Center(child: CircularProgressIndicator())`.
class DreamSpinner extends StatelessWidget {
  final Color? color;
  final double size;

  const DreamSpinner({super.key, this.color, this.size = 36});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SpinKitFadingCube(color: color ?? AppColors.primary, size: size.r),
    );
  }
}
