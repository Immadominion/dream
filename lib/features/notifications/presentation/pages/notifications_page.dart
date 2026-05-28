import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/app_notification.dart';
import '../../../../core/providers/notifications/notifications_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/dream_colors.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: context.dreamColors.background,
      appBar: AppBar(
        backgroundColor: context.dreamColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(
            PhosphorIcons.arrowLeft(PhosphorIconsStyle.bold),
            color: context.dreamColors.onSurface,
            size: 20.sp,
          ),
        ),
        title: Text(
          'Notifications',
          style: TextStyle(
            color: context.dreamColors.onSurface,
            fontSize: 17.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          PopupMenuButton<_MenuAction>(
            icon: Icon(
              PhosphorIcons.dotsThreeVertical(PhosphorIconsStyle.bold),
              color: context.dreamColors.muted,
              size: 20.sp,
            ),
            color: context.dreamColors.surfaceVariant,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.r),
              side: BorderSide(color: context.dreamColors.stroke),
            ),
            onSelected: (action) {
              switch (action) {
                case _MenuAction.markAllRead:
                  ref.read(notificationsProvider.notifier).markAllRead();
                case _MenuAction.clearAll:
                  ref.read(notificationsProvider.notifier).clearAll();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _MenuAction.markAllRead,
                child: Row(
                  children: [
                    Icon(
                      PhosphorIcons.checks(PhosphorIconsStyle.bold),
                      size: 15.sp,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'Mark all as read',
                      style: TextStyle(
                        color: context.dreamColors.onSurface,
                        fontSize: 13.sp,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _MenuAction.clearAll,
                child: Row(
                  children: [
                    Icon(
                      PhosphorIcons.trash(PhosphorIconsStyle.bold),
                      size: 15.sp,
                      color: AppColors.error,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'Clear all',
                      style: TextStyle(color: AppColors.error, fontSize: 13.sp),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: notifications.isEmpty
          ? _EmptyState()
          : _Timeline(notifications: notifications),
    );
  }
}

enum _MenuAction { markAllRead, clearAll }

// ---------------------------------------------------------------------------
// Timeline feed
// ---------------------------------------------------------------------------

class _Timeline extends ConsumerWidget {
  final List<AppNotification> notifications;
  const _Timeline({required this.notifications});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));

    final sections = <(String, List<AppNotification>)>[
      (
        'Today',
        notifications.where((n) => n.timestamp.isAfter(todayStart)).toList(),
      ),
      (
        'Yesterday',
        notifications
            .where(
              (n) =>
                  n.timestamp.isAfter(yesterdayStart) &&
                  !n.timestamp.isAfter(todayStart),
            )
            .toList(),
      ),
      (
        'Older',
        notifications
            .where((n) => !n.timestamp.isAfter(yesterdayStart))
            .toList(),
      ),
    ].where((s) => s.$2.isNotEmpty).toList();

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(20.w, 8.h, 16.w, 80.h),
      itemCount: sections.fold<int>(0, (sum, s) => sum + 1 + s.$2.length),
      itemBuilder: (context, index) {
        int pos = 0;
        for (final section in sections) {
          if (index == pos) {
            return _SectionLabel(label: section.$1);
          }
          pos++;
          final itemIndex = index - pos;
          if (itemIndex < section.$2.length) {
            final n = section.$2[itemIndex];
            final isLast =
                itemIndex == section.$2.length - 1 &&
                sections.last.$1 == section.$1;
            return _TimelineRow(
              notification: n,
              isLast: isLast,
              onTap: () =>
                  ref.read(notificationsProvider.notifier).markRead(n.id),
              onDismiss: () =>
                  ref.read(notificationsProvider.notifier).remove(n.id),
            );
          }
          pos += section.$2.length;
        }
        return const SizedBox.shrink();
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Section label (inline with timeline)
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 16.h, bottom: 8.h, left: 18.w),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: context.dreamColors.mutedSecondary,
          fontSize: 10.sp,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single timeline row
// ---------------------------------------------------------------------------

class _TimelineRow extends StatelessWidget {
  final AppNotification notification;
  final bool isLast;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _TimelineRow({
    required this.notification,
    required this.isLast,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final (icon, accent) = _categoryStyle(n.category, context);

    return Dismissible(
      key: ValueKey(n.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 16.w),
        child: Icon(
          PhosphorIcons.trash(PhosphorIconsStyle.bold),
          color: AppColors.error,
          size: 16.sp,
        ),
      ),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Timeline spine ──
              SizedBox(
                width: 24.w,
                child: Column(
                  children: [
                    // dot
                    Container(
                      width: 8.r,
                      height: 8.r,
                      margin: EdgeInsets.only(top: 5.h),
                      decoration: BoxDecoration(
                        color: n.isRead ? context.dreamColors.stroke : accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    // line below dot
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 1,
                          color: context.dreamColors.stroke.withValues(
                            alpha: 0.5,
                          ),
                          margin: EdgeInsets.symmetric(horizontal: 3.5.w),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(width: 10.w),
              // ── Content ──
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 18.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icon, size: 12.sp, color: accent),
                          SizedBox(width: 5.w),
                          Expanded(
                            child: Text(
                              n.title,
                              style: TextStyle(
                                color: context.dreamColors.onSurface,
                                fontSize: 13.sp,
                                fontWeight: n.isRead
                                    ? FontWeight.w500
                                    : FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            _formatTime(n.timestamp),
                            style: TextStyle(
                              color: context.dreamColors.mutedSecondary,
                              fontSize: 10.sp,
                            ),
                          ),
                          if (!n.isRead) ...[
                            SizedBox(width: 6.w),
                            Container(
                              width: 5.r,
                              height: 5.r,
                              decoration: BoxDecoration(
                                color: accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 3.h),
                      Text(
                        n.body,
                        style: TextStyle(
                          color: context.dreamColors.muted,
                          fontSize: 12.sp,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static (IconData, Color) _categoryStyle(
    AppNotifCategory cat,
    BuildContext context,
  ) {
    switch (cat) {
      case AppNotifCategory.trade:
        return (
          PhosphorIcons.chartLineUp(PhosphorIconsStyle.bold),
          AppColors.success,
        );
      case AppNotifCategory.alert:
        return (
          PhosphorIcons.bellSimpleRinging(PhosphorIconsStyle.bold),
          const Color(0xFFF59E0B),
        );
      case AppNotifCategory.risk:
        return (PhosphorIcons.siren(PhosphorIconsStyle.bold), AppColors.error);
      case AppNotifCategory.system:
        return (
          PhosphorIcons.appWindow(PhosphorIconsStyle.bold),
          context.dreamColors.mutedSecondary,
        );
      case AppNotifCategory.marketing:
        return (
          PhosphorIcons.megaphone(PhosphorIconsStyle.bold),
          AppColors.primary,
        );
      case AppNotifCategory.intelligence:
        return (
          PhosphorIcons.sparkle(PhosphorIconsStyle.bold),
          const Color(0xFF8B5CF6),
        );
    }
  }

  static String _formatTime(DateTime ts) {
    final diff = DateTime.now().difference(ts);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return DateFormat('MMM d').format(ts);
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            PhosphorIcons.bellSlash(PhosphorIconsStyle.duotone),
            color: context.dreamColors.mutedSecondary,
            size: 44.sp,
          ),
          SizedBox(height: 12.h),
          Text(
            'No notifications yet',
            style: TextStyle(
              color: context.dreamColors.muted,
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Trade alerts and updates will appear here.',
            style: TextStyle(
              color: context.dreamColors.mutedSecondary,
              fontSize: 12.sp,
            ),
          ),
        ],
      ),
    );
  }
}
