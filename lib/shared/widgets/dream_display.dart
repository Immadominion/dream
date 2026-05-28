import 'package:flutter/material.dart';
import 'package:flutter_boring_avatars/flutter_boring_avatars.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/dream_colors.dart';

// =============================================================================
// AVATAR - Token or user avatar with optional verified badge
// =============================================================================
class DreamAvatar extends StatelessWidget {
  const DreamAvatar({
    super.key,
    this.imageUrl,
    this.emoji,
    this.size,
    this.isVerified = false,
    this.borderColor,
    this.seed,
  });

  final String? imageUrl;
  final String? emoji;
  final double? size;
  final bool isVerified;
  final Color? borderColor;
  final String? seed;

  @override
  Widget build(BuildContext context) {
    final avatarSize = size ?? 48.r;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: avatarSize,
          height: avatarSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.dreamColors.surface,
            border: borderColor != null || isVerified
                ? Border.all(color: borderColor ?? AppColors.info, width: 2)
                : Border.all(color: Colors.white.withOpacity(0.06), width: 1),
          ),
          child: ClipOval(
            child: imageUrl != null && imageUrl!.isNotEmpty
                ? Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _buildFallback(avatarSize),
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Center(
                        child: SizedBox(
                          width: avatarSize * 0.4,
                          height: avatarSize * 0.4,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.w,
                            color: AppColors.primary,
                          ),
                        ),
                      );
                    },
                  )
                : _buildFallback(avatarSize),
          ),
        ),
        if (isVerified)
          Positioned(
            right: -2.r,
            bottom: -2.r,
            child: Container(
              padding: EdgeInsets.all(2.r),
              decoration: BoxDecoration(
                color: context.dreamColors.background,
                shape: BoxShape.circle,
              ),
              child: Icon(
                PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                color: AppColors.info,
                size: (avatarSize * 0.35).sp,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFallback(double size) {
    if (seed != null) {
      return BoringAvatar(
        name: seed!,
        palette: BoringAvatarPalette(AppColors.chartColors),
        type: BoringAvatarType.beam,
        shape: const OvalBorder(),
      );
    }
    return Center(
      child: Text(emoji ?? '🌐', style: TextStyle(fontSize: (size * 0.45).sp)),
    );
  }
}

// =============================================================================
// STAT ITEM - Key-value display for metrics
// =============================================================================
class DreamStatItem extends StatelessWidget {
  const DreamStatItem({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.isLoading = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: context.dreamColors.mutedSecondary,
            fontSize: 11.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 4.h),
        isLoading
            ? Container(
                width: 60.w,
                height: 16.h,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(4.r),
                ),
              )
            : Text(
                value,
                style: TextStyle(
                  color: valueColor ?? context.dreamColors.onSurface,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ],
    );
  }
}

// =============================================================================
// EMPTY STATE - For when there's no content
// =============================================================================
class DreamEmptyState extends StatelessWidget {
  const DreamEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(24.r),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48.sp,
                color: AppColors.primary.withOpacity(0.6),
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              title,
              style: TextStyle(
                color: context.dreamColors.onSurface,
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              SizedBox(height: 8.h),
              Text(
                subtitle!,
                style: TextStyle(
                  color: context.dreamColors.muted,
                  fontSize: 14.sp,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[SizedBox(height: 24.h), action!],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// LOADING SHIMMER - Skeleton placeholder
// =============================================================================
class DreamShimmer extends StatefulWidget {
  const DreamShimmer({super.key, this.width, this.height, this.borderRadius});

  final double? width;
  final double? height;
  final double? borderRadius;

  @override
  State<DreamShimmer> createState() => _DreamShimmerState();
}

class _DreamShimmerState extends State<DreamShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height ?? 16.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius ?? 4.r),
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value, 0),
              colors: [
                Colors.white.withOpacity(0.03),
                Colors.white.withOpacity(0.08),
                Colors.white.withOpacity(0.03),
              ],
            ),
          ),
        );
      },
    );
  }
}
