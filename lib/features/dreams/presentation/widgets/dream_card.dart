import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/dream_colors.dart';
import '../../models/dream_models.dart';

String formatUsd(String decimal) {
  final v = double.tryParse(decimal) ?? 0;
  if (v >= 1000000) return '\$${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 10000) return '\$${(v / 1000).toStringAsFixed(1)}k';
  return v == v.roundToDouble()
      ? '\$${v.toStringAsFixed(0)}'
      : '\$${v.toStringAsFixed(2)}';
}

String shortWallet(String w) =>
    w.length <= 10 ? w : '${w.substring(0, 4)}…${w.substring(w.length - 4)}';

String timeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inHours < 1) return '${d.inMinutes}m ago';
  if (d.inDays < 1) return '${d.inHours}h ago';
  if (d.inDays < 30) return '${d.inDays}d ago';
  return '${(d.inDays / 30).floor()}mo ago';
}

class DreamProgressBar extends StatelessWidget {
  final double progress;
  final double? height;
  const DreamProgressBar({super.key, required this.progress, this.height});

  @override
  Widget build(BuildContext context) {
    final dc = context.dreamColors;
    final h = height ?? 6.h;
    return ClipRRect(
      borderRadius: BorderRadius.circular(h),
      child: Stack(
        children: [
          Container(height: h, color: dc.stroke.withValues(alpha: 0.6)),
          FractionallySizedBox(
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              height: h,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [dc.primary, progress >= 1 ? dc.success : dc.accent],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DreamCard extends StatelessWidget {
  final Dream dream;
  final VoidCallback onTap;
  const DreamCard({super.key, required this.dream, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dc = context.dreamColors;
    return Semantics(
      button: true,
      label:
          '${dream.title}. Raised ${formatUsd(dream.raisedUsdc)} of ${formatUsd(dream.goalUsdc)}.',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: dc.surface,
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(color: dc.stroke.withValues(alpha: 0.7)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Chip(
                    text: '${dream.category.emoji} ${dream.category.label}',
                  ),
                  if (dream.hidden) ...[
                    SizedBox(width: 6.w),
                    const _Chip(text: 'Under review'),
                  ],
                  if (dream.coin != null) ...[
                    SizedBox(width: 6.w),
                    _Chip(text: '\$${dream.coin!.symbol}', highlight: true),
                  ],
                  const Spacer(),
                  Text(
                    timeAgo(dream.createdAt),
                    style: TextStyle(color: dc.muted, fontSize: 11.sp),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              Text(
                dream.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: dc.onSurface,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  letterSpacing: -0.2,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                dream.story,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: dc.muted,
                  fontSize: 13.sp,
                  height: 1.35,
                ),
              ),
              SizedBox(height: 14.h),
              DreamProgressBar(progress: dream.progress),
              SizedBox(height: 8.h),
              Row(
                children: [
                  Text(
                    formatUsd(dream.raisedUsdc),
                    style: TextStyle(
                      color: dc.onSurface,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    ' of ${formatUsd(dream.goalUsdc)}',
                    style: TextStyle(color: dc.muted, fontSize: 13.sp),
                  ),
                  const Spacer(),
                  Icon(PhosphorIcons.heart(), size: 14.r, color: dc.muted),
                  SizedBox(width: 4.w),
                  Text(
                    '${dream.supporterCount}',
                    style: TextStyle(color: dc.muted, fontSize: 12.sp),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final bool highlight;
  const _Chip({required this.text, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final dc = context.dreamColors;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: highlight
            ? dc.primary.withValues(alpha: 0.14)
            : dc.surfaceVariant.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: highlight ? dc.primary : dc.onSurfaceVariant,
          fontSize: 11.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
