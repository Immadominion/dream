import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/providers/auth/client_auth_provider.dart';
import '../../../../core/providers/settings/ui_preferences_provider.dart';
import '../../../../core/providers/solana/wallet_name_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/dream_display.dart';
import 'package:dream/features/navigation/providers/bottom_nav_providers.dart';
import '../../providers/account_provider.dart';
import '../widgets/account_balance_card.dart';

import '../../../../core/services/chat_service.dart';
import 'analytics_page.dart';
import 'equity_page.dart';
import 'history_page.dart';
import 'earn_page.dart';
import 'leaderboard_page.dart';
import 'health_page.dart';
import '../../../../core/theme/dream_colors.dart';
import '../../../settings/presentation/widgets/theme_toggle_tile.dart';

class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  /// Derives the best display name from auth state + optional resolved domain.
  ///
  /// Priority: OAuth display name → SNS domain (.skr/.sol/…) → email local
  /// part → truncated wallet address.
  static String _computeDisplayName({
    required AuthStateData auth,
    required String? resolvedDomain,
  }) {
    // 1. OAuth display name (Google / Apple)
    final dn = auth.session?.user.displayName;
    if (dn != null && dn.trim().isNotEmpty) {
      return dn.trim().split(' ').first;
    }
    // 2. SNS domain name (.skr, .sol, …)
    if (resolvedDomain != null) return resolvedDomain;
    // 3. Email local part, capitalised
    final email = auth.userEmail ?? '';
    if (email.contains('@')) {
      final local = email.split('@').first;
      final part = local
          .replaceAll(RegExp(r'[._+\-]'), ' ')
          .trim()
          .split(' ')
          .first;
      if (part.isNotEmpty) {
        return part[0].toUpperCase() + part.substring(1).toLowerCase();
      }
    }
    // 4. Truncated wallet address
    final wallet = auth.walletAddress;
    if (wallet != null && wallet.length >= 8) {
      return '${wallet.substring(0, 4)}…${wallet.substring(wallet.length - 4)}';
    }
    return 'Trader';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(clientAuthProvider);
    final accountState = ref.watch(accountProvider);
    final walletAddress = authState.walletAddress;
    final user = authState.session?.user;
    final avatarSeed = user?.walletAddress ?? user?.id ?? user?.email;

    // Resolve SNS domain name for wallet users (.skr, .sol, etc.)
    final walletNameAsync = walletAddress != null
        ? ref.watch(walletNameProvider(walletAddress))
        : const AsyncData<String?>(null);
    final displayName = _computeDisplayName(
      auth: authState,
      resolvedDomain: walletNameAsync.asData?.value,
    );

    return Scaffold(
      backgroundColor: context.dreamColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Custom premium Top Bar with Back Button & Settings Gear
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () =>
                        ref.read(bottomNavIndexProvider.notifier).setIndex(0),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: EdgeInsets.all(8.r),
                      decoration: BoxDecoration(
                        color: context.dreamColors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: context.dreamColors.stroke),
                      ),
                      child: Icon(
                        PhosphorIcons.arrowLeft(PhosphorIconsStyle.bold),
                        color: context.dreamColors.onSurface,
                        size: 24.sp,
                      ),
                    ),
                  ),
                  Text(
                    'Profile',
                    style: TextStyle(
                      color: context.dreamColors.onSurface,
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Row(
                    children: [
                      if (walletAddress != null) ...[
                        _buildHistoryButton(context, walletAddress),
                        SizedBox(width: 8.w),
                      ],
                      _buildSettingsButton(context, ref),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                backgroundColor: context.dreamColors.surface,
                onRefresh: () => ref.read(accountProvider.notifier).refresh(),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    16.w,
                    8.h,
                    16.w,
                    MediaQuery.paddingOf(context).bottom + 24.h,
                  ),
                  children: [
                    // Premium Unified Profile Card (Chumbucket styling theme)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.only(
                        left: 20.w,
                        right: 20.w,
                        top: 24.h,
                      ),
                      child: Column(
                        children: [
                          // Large sleek Avatar with Edit / Change Indicator
                          Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.primary.withOpacity(0.4),
                                    width: 3.w,
                                  ),
                                ),
                                child: avatarSeed != null
                                    ? DreamAvatar(
                                        imageUrl: user?.photoUrl,
                                        seed: avatarSeed,
                                        size: 84.r,
                                        borderColor: Colors.transparent,
                                      )
                                    : CircleAvatar(
                                        radius: 42.r,
                                        backgroundColor:
                                            context.dreamColors.surfaceVariant,
                                        child: Icon(
                                          PhosphorIcons.user(
                                            PhosphorIconsStyle.duotone,
                                          ),
                                          size: 40.sp,
                                          color: context.dreamColors.muted,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                          SizedBox(height: 14.h),

                          // Name/Greeting
                          Text(
                            displayName,
                            style: TextStyle(
                              color: context.dreamColors.onSurface,
                              fontSize: 22.sp,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 4.h),

                          // Connected message / status pill
                          Text(
                            authState.userEmail != null
                                ? authState.userEmail!
                                : walletAddress != null &&
                                      walletAddress.length >= 8
                                ? '${walletAddress.substring(0, 6)}…${walletAddress.substring(walletAddress.length - 6)}'
                                : 'Solana Wallet',
                            style: TextStyle(
                              color: context.dreamColors.muted,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          SizedBox(height: 14.h),

                          // Integrated Wallet Pill (Replacing bulky wallet card)
                          if (walletAddress != null)
                            GestureDetector(
                              onTap: () {
                                Clipboard.setData(
                                  ClipboardData(text: walletAddress),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                      'Address copied to clipboard',
                                    ),
                                    backgroundColor: AppColors.primary,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10.r),
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 14.w,
                                  vertical: 8.h,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(16.r),
                                  border: Border.all(
                                    color: context.dreamColors.stroke,
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      PhosphorIcons.wallet(
                                        PhosphorIconsStyle.bold,
                                      ),
                                      color: AppColors.primaryLight,
                                      size: 14.sp,
                                    ),
                                    SizedBox(width: 8.w),
                                    Text(
                                      '${walletAddress.substring(0, 8)}…${walletAddress.substring(walletAddress.length - 8)}',
                                      style: TextStyle(
                                        color: context.dreamColors.onSurface,
                                        fontSize: 12.sp,
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    Icon(
                                      PhosphorIcons.copy(
                                        PhosphorIconsStyle.regular,
                                      ),
                                      color: context.dreamColors.muted,
                                      size: 12.sp,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // Balance details card (Receive/Send)
                    if (walletAddress != null) ...[
                      AccountBalanceCard(
                        walletAddress: walletAddress,
                        accountState: accountState,
                      ),
                      SizedBox(height: 16.h),
                    ],

                    // Grouped Menu Section Container (Squircle, premium styling)
                    _ProfileGroupContainer(
                      children: [
                        _ProfileItemTile(
                          icon: PhosphorIcons.chartBar(PhosphorIconsStyle.bold),
                          title: 'Portfolio Analytics',
                          subtitle: 'View your volume, fee paid & asset logs',
                          onTap: () {
                            if (walletAddress != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AnalyticsPage(
                                    walletAddress: walletAddress,
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                        _ProfileItemTile(
                          icon: PhosphorIcons.chartLineUp(
                            PhosphorIconsStyle.bold,
                          ),
                          title: 'Equity Curve',
                          subtitle: 'Track your relative net worth performance',
                          isLast: true,
                          onTap: () {
                            if (walletAddress != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      EquityPage(walletAddress: walletAddress),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),

                    _ProfileGroupContainer(
                      children: [
                        _ProfileItemTile(
                          icon: PhosphorIcons.gift(PhosphorIconsStyle.bold),
                          title: 'Refer & Earn',
                          subtitle: 'Earn fees & unlock system perks',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    EarnPage(walletAddress: walletAddress),
                              ),
                            );
                          },
                        ),
                        _ProfileItemTile(
                          icon: PhosphorIcons.trophy(PhosphorIconsStyle.bold),
                          title: 'Rank & Leaderboard',
                          subtitle:
                              'Compare your trading tier against the vault',
                          isLast: true,
                          onTap: () {
                            if (walletAddress != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => LeaderboardPage(
                                    walletAddress: walletAddress,
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),

                    _ProfileGroupContainer(
                      children: [
                        _ProfileItemTile(
                          icon: PhosphorIcons.shieldCheck(
                            PhosphorIconsStyle.bold,
                          ),
                          title: 'Account Health',
                          subtitle:
                              'Review your margin requirements & collateral levels',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const HealthPage(),
                              ),
                            );
                          },
                        ),
                        _ProfileItemTile(
                          icon: PhosphorIcons.headset(PhosphorIconsStyle.bold),
                          title: 'Talk To Support',
                          subtitle: 'Get help with live in-app support chat',
                          isLast: true,
                          onTap: () => ChatService.openChat(context),
                        ),
                      ],
                    ),
                    SizedBox(height: 24.h),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsButton(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _showSettingsSheet(context, ref),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.all(8.r),
        decoration: BoxDecoration(
          color: context.dreamColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: context.dreamColors.stroke),
        ),
        child: Icon(
          PhosphorIcons.gearSix(PhosphorIconsStyle.bold),
          color: context.dreamColors.onSurface,
          size: 24.sp,
        ),
      ),
    );
  }

  Widget _buildHistoryButton(BuildContext context, String walletAddress) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HistoryPage(walletAddress: walletAddress),
          ),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.all(8.r),
        decoration: BoxDecoration(
          color: context.dreamColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: context.dreamColors.stroke),
        ),
        child: Icon(
          PhosphorIcons.clockCounterClockwise(PhosphorIconsStyle.bold),
          color: context.dreamColors.onSurface,
          size: 24.sp,
        ),
      ),
    );
  }

  void _showSettingsSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.dreamColors.surface,
      barrierColor: Colors.black.withOpacity(0.5),
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26.r)),
      ),
      builder: (ctx) => _SettingsSheet(
        onSignOut: () {
          Navigator.pop(ctx);
          _confirmSignOut(context, ref);
        },
      ),
    );
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.dreamColors.surface,
        title: Text(
          'Sign Out',
          style: TextStyle(
            color: context.dreamColors.onSurface,
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: context.dreamColors.muted, fontSize: 13.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: context.dreamColors.muted,
                fontSize: 13.sp,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Sign Out',
              style: TextStyle(
                color: AppColors.bearish,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await ref.read(clientAuthProvider.notifier).signOut();
      if (context.mounted) {
        // Go back to login
        context.go('/enhanced-login');
      }
    }
  }
}

// ---------------------------------------------------------------------------
// _SettingsSheet — rich Settings & Security bottom sheet
// ---------------------------------------------------------------------------

class _SettingsSheet extends ConsumerWidget {
  final VoidCallback onSignOut;
  const _SettingsSheet({required this.onSignOut});

  static const _twitterUrl = 'https://x.com/HeIsJoel0x';
  static const _appVersion = '1.0.0';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiPrefs = ref.watch(uiPreferencesProvider);

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 24.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: EdgeInsets.only(top: 10.h, bottom: 20.h),
                width: 36.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: context.dreamColors.stroke,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),

            // Title
            Text(
              'Settings & Security',
              style: TextStyle(
                color: context.dreamColors.onSurface,
                fontSize: 24.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 24.h),

            // ── Appearance ───────────────────────────────────────────────
            _SheetSectionLabel(label: 'Appearance'),
            SizedBox(height: 10.h),
            const ThemeToggleTile(),
            SizedBox(height: 24.h),

            // ── UI Preferences ──────────────────────────────────────────
            _SheetSectionLabel(label: 'Preferences'),
            SizedBox(height: 10.h),
            Container(
              decoration: BoxDecoration(
                color: context.dreamColors.surface,
                borderRadius: BorderRadius.circular(18.r),
                border: Border.all(color: context.dreamColors.stroke),
              ),
              child: SwitchListTile(
                value: uiPrefs.enabled,
                onChanged: (val) =>
                    ref.read(uiPreferencesProvider.notifier).setEnabled(val),
                title: Row(
                  children: [
                    Icon(
                      PhosphorIcons.floppyDisk(PhosphorIconsStyle.bold),
                      color: AppColors.primary,
                      size: 20.sp,
                    ),
                    SizedBox(width: 10.w),
                    Text(
                      'Remember UI State',
                      style: TextStyle(
                        color: context.dreamColors.onSurface,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: EdgeInsets.only(top: 2.h),
                  child: Text(
                    uiPrefs.enabled
                        ? 'Trade direction & layout saved locally'
                        : 'No UI state persisted',
                    style: TextStyle(
                      color: context.dreamColors.muted,
                      fontSize: 12.sp,
                    ),
                  ),
                ),
                activeColor: AppColors.primary,
                activeTrackColor: AppColors.primary.withOpacity(0.2),
                inactiveThumbColor: context.dreamColors.muted,
                inactiveTrackColor: Colors.white.withOpacity(0.06),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18.r),
                ),
              ),
            ),
            SizedBox(height: 24.h),

            // ── About ────────────────────────────────────────────────────
            _SheetSectionLabel(label: 'About'),
            SizedBox(height: 10.h),
            Container(
              decoration: BoxDecoration(
                color: context.dreamColors.surface,
                borderRadius: BorderRadius.circular(18.r),
                border: Border.all(color: context.dreamColors.stroke),
              ),
              child: Column(
                children: [
                  _SheetInfoTile(
                    icon: PhosphorIcons.terminal(PhosphorIconsStyle.bold),
                    title: 'Dream Terminal',
                    value: 'v$_appVersion',
                    isFirst: true,
                  ),
                  Divider(
                    color: context.dreamColors.stroke,
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
                  _SheetInfoTile(
                    icon: PhosphorIcons.buildings(PhosphorIconsStyle.bold),
                    title: 'Powered by',
                    value: 'Phoenix Trade · Solana',
                  ),
                  Divider(
                    color: context.dreamColors.stroke,
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
                  // Built with love credit
                  GestureDetector(
                    onTap: () => launchUrl(
                      Uri.parse(_twitterUrl),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: _SheetInfoTile(
                      icon: PhosphorIcons.heart(PhosphorIconsStyle.fill),
                      iconColor: const Color(0xFFE11D48),
                      title: 'Built with love by',
                      value: '@Heisjoel0x',
                      valueColor: AppColors.primary,
                      isLast: true,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 32.h),

            // ── Sign Out ─────────────────────────────────────────────────
            GestureDetector(
              onTap: onSignOut,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 16.h),
                decoration: BoxDecoration(
                  color: AppColors.bearish.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(18.r),
                  border: Border.all(
                    color: AppColors.bearish.withOpacity(0.35),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      PhosphorIcons.signOut(PhosphorIconsStyle.bold),
                      color: AppColors.bearish,
                      size: 22.sp,
                    ),
                    SizedBox(width: 10.w),
                    Text(
                      'Sign Out',
                      style: TextStyle(
                        color: AppColors.bearish,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetSectionLabel extends StatelessWidget {
  final String label;
  const _SheetSectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        color: context.dreamColors.mutedSecondary,
        fontSize: 11.sp,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.3,
      ),
    );
  }
}

class _SheetInfoTile extends StatelessWidget {
  final PhosphorIconData icon;
  final Color? iconColor;
  final String title;
  final String value;
  final Color? valueColor;
  final bool isFirst;
  final bool isLast;

  const _SheetInfoTile({
    required this.icon,
    this.iconColor,
    required this.title,
    required this.value,
    this.valueColor,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      child: Row(
        children: [
          Icon(
            icon,
            color: iconColor ?? context.dreamColors.muted,
            size: 22.sp,
          ),
          SizedBox(width: 14.w),
          Text(
            title,
            style: TextStyle(
              color: context.dreamColors.onSurface,
              fontSize: 15.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? context.dreamColors.muted,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grouped container and beautiful list tiles (squircle style)
// ---------------------------------------------------------------------------

class _ProfileGroupContainer extends StatelessWidget {
  final List<Widget> children;
  const _ProfileGroupContainer({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.dreamColors.surface,
        borderRadius: BorderRadius.circular(26.r),
        border: Border.all(color: context.dreamColors.stroke),
      ),
      child: Column(children: children),
    );
  }
}

class _ProfileItemTile extends StatelessWidget {
  final PhosphorIconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isLast;

  const _ProfileItemTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: isLast
              ? BorderRadius.vertical(bottom: Radius.circular(26.r))
              : null,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
            child: Row(
              children: [
                Container(
                  width: 40.w,
                  height: 40.w,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: AppColors.primary, size: 20.sp),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: context.dreamColors.onSurface,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: context.dreamColors.muted,
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  PhosphorIcons.caretRight(PhosphorIconsStyle.bold),
                  color: context.dreamColors.mutedSecondary,
                  size: 16.sp,
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(color: context.dreamColors.stroke, height: 1, indent: 72),
      ],
    );
  }
}
