import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import 'account_history_providers.dart';
import '../../../../core/theme/dream_colors.dart';

// ---------------------------------------------------------------------------
// Native referral experience (no web view).
//
// Phoenix's referral program lets traders earn a fee share from people they
// refer. Generating a personal code happens on phoenix.trade once a trader
// passes $10k lifetime volume, so this surface focuses on what we *can* do
// natively: explain the program, show progress to the unlock, share an invite
// via the OS share sheet, and copy the configured Dream invite code.
// ---------------------------------------------------------------------------

const double _kUnlockVolume = 10000; // $10k lifetime volume to unlock a code.

class AccountReferralCard extends ConsumerWidget {
  final String? walletAddress;
  const AccountReferralCard({super.key, this.walletAddress});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = AppConstants.dreamReferralCode;

    double lifetimeVolume = 0;
    if (walletAddress != null) {
      final tradesAsync = ref.watch(
        accountTradeHistoryProvider(walletAddress!),
      );
      lifetimeVolume = tradesAsync.maybeWhen(
        data: (trades) =>
            trades.fold<double>(0, (s, t) => s + t.price * t.size),
        orElse: () => 0,
      );
    }

    final unlocked = lifetimeVolume >= _kUnlockVolume;
    final progress = (lifetimeVolume / _kUnlockVolume).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Hero ─────────────────────────────────────────────────────────
        Row(
          children: [
            Container(
              width: 44.w,
              height: 44.w,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withValues(alpha: 0.55),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16.r),
              ),
              alignment: Alignment.center,
              child: Icon(
                PhosphorIcons.gift(PhosphorIconsStyle.fill),
                color: Colors.white,
                size: 22.sp,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Invite friends, earn fees',
                    style: TextStyle(
                      color: context.dreamColors.onSurface,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Earn a share of every fee your referrals pay — forever.',
                    style: TextStyle(
                      color: context.dreamColors.muted,
                      fontSize: 12.sp,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 22.h),

        // ── Reward breakdown (flat rows, no boxes) ───────────────────────
        Text(
          'HOW IT WORKS',
          style: TextStyle(
            color: context.dreamColors.mutedSecondary,
            fontSize: 10.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: 12.h),
        _RewardRow(
          icon: PhosphorIcons.usersThree(PhosphorIconsStyle.bold),
          title: 'Direct referrals',
          subtitle: 'When a friend signs up with your code',
          trailing: '20%',
        ),
        const _HairlineDivider(),
        _RewardRow(
          icon: PhosphorIcons.share(PhosphorIconsStyle.bold),
          title: 'Second-tier',
          subtitle: 'Fees from people your referrals invite',
          trailing: '10%',
        ),
        const _HairlineDivider(),
        _RewardRow(
          icon: PhosphorIcons.coins(PhosphorIconsStyle.bold),
          title: 'Paid weekly in USDC',
          subtitle: 'Auto-credited to your spot balance · \$1 min claim',
          trailing: null,
        ),
        SizedBox(height: 24.h),

        // ── Unlock progress ──────────────────────────────────────────────
        Text(
          unlocked ? 'YOUR CODE IS UNLOCKED' : 'UNLOCK YOUR CODE',
          style: TextStyle(
            color: unlocked
                ? AppColors.bullish
                : context.dreamColors.mutedSecondary,
            fontSize: 10.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: 12.h),
        if (!unlocked) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatUsdc(lifetimeVolume),
                style: TextStyle(
                  color: context.dreamColors.onSurface,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                'of \$10k volume',
                style: TextStyle(
                  color: context.dreamColors.muted,
                  fontSize: 12.sp,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(999.r),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6.h,
              backgroundColor: context.dreamColors.stroke,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Trade \$10k lifetime volume to generate a personal referral code. '
            'Until then, share the Dream invite below.',
            style: TextStyle(
              color: context.dreamColors.mutedSecondary,
              fontSize: 11.sp,
              height: 1.4,
            ),
          ),
        ] else
          Text(
            'You\'ve traded enough to generate a personal referral code. '
            'Share your invite to start earning.',
            style: TextStyle(
              color: context.dreamColors.muted,
              fontSize: 12.sp,
              height: 1.4,
            ),
          ),

        // ── Invite code chip ─────────────────────────────────────────────
        if (code.isNotEmpty) ...[
          SizedBox(height: 16.h),
          _InviteCodeChip(code: code),
        ],

        SizedBox(height: 20.h),

        // ── Share CTA ────────────────────────────────────────────────────
        _ShareButton(code: code),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _RewardRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? trailing;

  const _RewardRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryLight, size: 18.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.dreamColors.onSurface,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: context.dreamColors.muted,
                    fontSize: 11.sp,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            SizedBox(width: 10.w),
            Text(
              trailing!,
              style: TextStyle(
                color: AppColors.bullish,
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HairlineDivider extends StatelessWidget {
  const _HairlineDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: context.dreamColors.stroke.withValues(alpha: 0.6),
    );
  }
}

class _InviteCodeChip extends StatelessWidget {
  final String code;
  const _InviteCodeChip({required this.code});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: code));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invite code copied')));
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: context.dreamColors.surface,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: context.dreamColors.stroke),
        ),
        child: Row(
          children: [
            Text(
              'Invite code',
              style: TextStyle(
                color: context.dreamColors.muted,
                fontSize: 12.sp,
              ),
            ),
            const Spacer(),
            Text(
              code,
              style: TextStyle(
                color: context.dreamColors.onSurface,
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
                letterSpacing: 1.0,
              ),
            ),
            SizedBox(width: 10.w),
            Icon(
              PhosphorIcons.copy(PhosphorIconsStyle.regular),
              color: context.dreamColors.muted,
              size: 15.sp,
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  final String code;
  const _ShareButton({required this.code});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: () {
          final msg = code.isNotEmpty
              ? 'Trade perps on Dream. Use my invite code "$code" to get a '
                    '10% trading-fee discount: https://phoenix.trade'
              : 'Trade perps on Dream — fast, mobile-first perpetuals on '
                    'Solana. https://phoenix.trade';
          Share.share(msg, subject: 'Join me on Dream');
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 15.h),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.primary.withValues(alpha: 0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(18.r),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                PhosphorIcons.shareNetwork(PhosphorIconsStyle.bold),
                color: Colors.white,
                size: 18.sp,
              ),
              SizedBox(width: 10.w),
              Text(
                'Share invite',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
