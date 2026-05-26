import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/app_notification.dart';
import '../../../../core/providers/notifications/notifications_provider.dart';
import '../../../../core/theme/app_colors.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(
            PhosphorIcons.arrowLeft(PhosphorIconsStyle.bold),
            color: AppColors.textPrimaryDark,
            size: 20.sp,
          ),
        ),
        title: Text(
          'Notifications',
          style: TextStyle(
            color: AppColors.textPrimaryDark,
            fontSize: 17.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: () =>
                  ref.read(notificationsProvider.notifier).markAllRead(),
              child: Text(
                'Mark all read',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
      body: notifications.isEmpty
          ? _EmptyState()
          : _NotificationFeed(notifications: notifications),
    );
  }
}

// ---------------------------------------------------------------------------
// Feed
// ---------------------------------------------------------------------------

class _NotificationFeed extends ConsumerWidget {
  final List<AppNotification> notifications;
  const _NotificationFeed({required this.notifications});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Group by date: Today / Yesterday / Older
    final today = DateTime.now();
    final todayStart =
        DateTime(today.year, today.month, today.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));

    final todayItems = notifications
        .where((n) => n.timestamp.isAfter(todayStart))
        .toList();
    final yesterdayItems = notifications
        .where((n) =>
            n.timestamp.isAfter(yesterdayStart) &&
            !n.timestamp.isAfter(todayStart))
        .toList();
    final olderItems = notifications
        .where((n) => !n.timestamp.isAfter(yesterdayStart))
        .toList();

    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      children: [
        if (todayItems.isNotEmpty) ...[
          _SectionHeader(label: 'Today'),
          SizedBox(height: 8.h),
          ...todayItems.map(
            (n) => _NotifTile(notification: n, onTap: () {
              ref.read(notificationsProvider.notifier).markRead(n.id);
            }),
          ),
        ],
        if (yesterdayItems.isNotEmpty) ...[
          SizedBox(height: 16.h),
          _SectionHeader(label: 'Yesterday'),
          SizedBox(height: 8.h),
          ...yesterdayItems.map(
            (n) => _NotifTile(notification: n, onTap: () {
              ref.read(notificationsProvider.notifier).markRead(n.id);
            }),
          ),
        ],
        if (olderItems.isNotEmpty) ...[
          SizedBox(height: 16.h),
          _SectionHeader(label: 'Older'),
          SizedBox(height: 8.h),
          ...olderItems.map(
            (n) => _NotifTile(notification: n, onTap: () {
              ref.read(notificationsProvider.notifier).markRead(n.id);
            }),
          ),
        ],
        SizedBox(height: 80.h), // bottom padding for nav bar
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: AppColors.textMutedDark,
        fontSize: 12.sp,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single notification tile
// ---------------------------------------------------------------------------

class _NotifTile extends ConsumerWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotifTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = notification;
    final (icon, accent) = _categoryStyle(n.category);

    return GestureDetector(
      onTap: onTap,
      child: Dismissible(
        key: ValueKey(n.id),
        direction: DismissDirection.endToStart,
        onDismissed: (_) =>
            ref.read(notificationsProvider.notifier).remove(n.id),
        background: Container(
          alignment: Alignment.centerRight,
          padding: EdgeInsets.only(right: 20.w),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Icon(
            PhosphorIcons.trash(PhosphorIconsStyle.bold),
            color: AppColors.error,
            size: 18.sp,
          ),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: EdgeInsets.only(bottom: 8.h),
          padding: EdgeInsets.all(14.r),
          decoration: BoxDecoration(
            color: n.isRead
                ? AppColors.cardDark
                : AppColors.cardDark.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: n.isRead
                  ? AppColors.borderDark
                  : accent.withValues(alpha: 0.35),
              width: n.isRead ? 1 : 1.2,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category icon
              Container(
                width: 36.r,
                height: 36.r,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accent, size: 17.sp),
              ),
              SizedBox(width: 12.w),
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            n.title,
                            style: TextStyle(
                              color: AppColors.textPrimaryDark,
                              fontSize: 13.sp,
                              fontWeight: n.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                            ),
                          ),
                        ),
                        if (!n.isRead)
                          Container(
                            width: 7.r,
                            height: 7.r,
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      n.body,
                      style: TextStyle(
                        color: AppColors.textSecondaryDark,
                        fontSize: 12.sp,
                        height: 1.45,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      _formatTimestamp(n.timestamp),
                      style: TextStyle(
                        color: AppColors.textMutedDark,
                        fontSize: 11.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static (IconData, Color) _categoryStyle(AppNotifCategory cat) {
    switch (cat) {
      case AppNotifCategory.trade:
        return (
          PhosphorIcons.chartLine(PhosphorIconsStyle.bold),
          AppColors.success,
        );
      case AppNotifCategory.alert:
        return (
          PhosphorIcons.bell(PhosphorIconsStyle.bold),
          const Color(0xFFF59E0B), // amber
        );
      case AppNotifCategory.risk:
        return (
          PhosphorIcons.warning(PhosphorIconsStyle.bold),
          AppColors.error,
        );
      case AppNotifCategory.system:
        return (
          PhosphorIcons.lightning(PhosphorIconsStyle.bold),
          AppColors.textMutedDark,
        );
      case AppNotifCategory.marketing:
        return (
          PhosphorIcons.megaphone(PhosphorIconsStyle.bold),
          AppColors.primary,
        );
      case AppNotifCategory.intelligence:
        return (
          PhosphorIcons.robot(PhosphorIconsStyle.bold),
          const Color(0xFF8B5CF6), // violet
        );
    }
  }

  static String _formatTimestamp(DateTime ts) {
    final now = DateTime.now();
    final diff = now.difference(ts);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return DateFormat('EEE, h:mm a').format(ts);
    return DateFormat('MMM d, h:mm a').format(ts);
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
            color: AppColors.textMutedDark,
            size: 52.sp,
          ),
          SizedBox(height: 16.h),
          Text(
            'No notifications yet',
            style: TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'Trade alerts, price triggers, and\napp updates will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMutedDark,
              fontSize: 13.sp,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
