import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/providers/auth/client_auth_provider.dart';
import '../../../../core/services/analytics/product_analytics.dart';
import '../../../../core/theme/dream_colors.dart';
import '../../../../shared/widgets/dream_buttons.dart';
import '../../../../shared/widgets/dream_display.dart';
import '../../../../shared/widgets/dream_spinner.dart';
import '../../../../shared/widgets/error_utils.dart';
import '../../models/dream_models.dart';
import '../../providers/dreams_providers.dart';
import '../widgets/dream_card.dart';
import '../widgets/dream_sheets.dart';

class DreamDetailPage extends ConsumerStatefulWidget {
  final String dreamId;
  const DreamDetailPage({super.key, required this.dreamId});

  @override
  ConsumerState<DreamDetailPage> createState() => _DreamDetailPageState();
}

class _DreamDetailPageState extends ConsumerState<DreamDetailPage> {
  String get dreamId => widget.dreamId;
  bool _viewLogged = false;

  @override
  void initState() {
    super.initState();
    // Finish recording any contribution whose transfer landed but whose
    // record call was interrupted earlier.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dreamActionsProvider).retryPendingContributions();
    });
    // Log one view per page open once the dream has loaded.
    ref.listenManual(dreamDetailProvider(widget.dreamId), (_, next) {
      final d = next.value?.dream;
      if (d == null || _viewLogged) return;
      _viewLogged = true;
      final me = ref.read(clientAuthProvider).walletAddress;
      unawaited(
        ProductAnalytics.dreamViewed(
          dreamId: d.id,
          hasCoin: d.coin != null,
          isOwner: me != null && me == d.ownerWallet,
        ),
      );
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) {
    final dc = context.dreamColors;
    final detail = ref.watch(dreamDetailProvider(dreamId));

    return Scaffold(
      backgroundColor: dc.background,
      appBar: AppBar(
        backgroundColor: dc.background,
        elevation: 0,
        actions: [if (detail.value != null) _Menu(dream: detail.value!.dream)],
      ),
      body: detail.when(
        loading: () => const Center(child: DreamSpinner()),
        error: (e, _) => DreamEmptyState(
          icon: PhosphorIcons.moonStars(),
          title: 'Dream not found',
          subtitle: e.toString(),
        ),
        data: (d) => RefreshIndicator(
          onRefresh: () => ref.refresh(dreamDetailProvider(dreamId).future),
          child: _DetailBody(detail: d),
        ),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  final DreamDetail detail;
  const _DetailBody({required this.detail});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dc = context.dreamColors;
    final dream = detail.dream;
    final me = ref.watch(clientAuthProvider).walletAddress;
    final isOwner = me != null && me == dream.ownerWallet;
    final launchesEnabled = ref.watch(dreamsFeedProvider).coinLaunchesEnabled;

    TextStyle label() => TextStyle(
      color: dc.muted,
      fontSize: 12.sp,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.4,
    );

    return ListView(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 48.h),
      children: [
        Text(
          '${dream.category.emoji} ${dream.category.label} · ${timeAgo(dream.createdAt)}',
          style: label(),
        ),
        SizedBox(height: 8.h),
        Text(
          dream.title,
          style: TextStyle(
            color: dc.onSurface,
            fontSize: 22.sp,
            fontWeight: FontWeight.w800,
            height: 1.2,
            letterSpacing: -0.4,
          ),
        ),
        SizedBox(height: 6.h),
        Row(
          children: [
            Flexible(
              child: Text(
                isOwner ? 'Your dream' : 'by ${shortWallet(dream.ownerWallet)}',
                style: TextStyle(color: dc.muted, fontSize: 13.sp),
              ),
            ),
            if (dream.xHandle != null) ...[
              SizedBox(width: 8.w),
              _VerifiedXChip(handle: dream.xHandle!, url: dream.xPostUrl),
            ],
          ],
        ),
        SizedBox(height: 20.h),
        Container(
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
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatUsd(dream.raisedUsdc),
                    style: TextStyle(
                      color: dc.onSurface,
                      fontSize: 26.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(bottom: 4.h, left: 6.w),
                    child: Text(
                      'of ${formatUsd(dream.goalUsdc)}',
                      style: TextStyle(color: dc.muted, fontSize: 14.sp),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${dream.supporterCount} supporter${dream.supporterCount == 1 ? '' : 's'}',
                    style: TextStyle(color: dc.muted, fontSize: 12.sp),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              DreamProgressBar(progress: dream.progress, height: 8.h),
              if (!isOwner && !dream.isClosed) ...[
                SizedBox(height: 16.h),
                DreamPrimaryButton(
                  label: 'Fund this dream',
                  icon: PhosphorIcons.heart(PhosphorIconsStyle.fill),
                  onPressed: () => _openSheet(
                    context,
                    FundDreamSheet(dream: dream),
                    'Thank you — your support was sent',
                  ),
                ),
              ],
              if (dream.isClosed) ...[
                SizedBox(height: 12.h),
                Text(
                  'This dream is closed.',
                  style: TextStyle(color: dc.muted, fontSize: 13.sp),
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: 16.h),
        _CoinSection(
          detail: detail,
          isOwner: isOwner,
          launchesEnabled: launchesEnabled,
        ),
        SizedBox(height: 24.h),
        Text('THE STORY', style: label()),
        SizedBox(height: 8.h),
        SelectableText(
          dream.story,
          style: TextStyle(color: dc.onSurface, fontSize: 15.sp, height: 1.5),
        ),
        if (isOwner && dream.xHandle == null && !dream.isClosed) ...[
          SizedBox(height: 16.h),
          _VerifyXPanel(dream: dream),
        ],
        if (detail.supporters.isNotEmpty) ...[
          SizedBox(height: 24.h),
          Text('RECENT SUPPORT', style: label()),
          SizedBox(height: 8.h),
          for (final s in detail.supporters)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                PhosphorIcons.heart(PhosphorIconsStyle.fill),
                color: dc.primary,
                size: 18.r,
              ),
              title: Text(
                shortWallet(s.wallet),
                style: TextStyle(color: dc.onSurface, fontSize: 13.sp),
              ),
              subtitle: Text(
                timeAgo(s.createdAt),
                style: TextStyle(color: dc.muted, fontSize: 11.sp),
              ),
              trailing: Text(
                formatUsd(s.amountUsdc),
                style: TextStyle(
                  color: dc.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.sp,
                ),
              ),
              onTap: () => launchUrl(
                Uri.parse('https://solscan.io/tx/${s.txSignature}'),
                mode: LaunchMode.externalApplication,
              ),
            ),
        ],
      ],
    );
  }
}

Future<void> _openSheet(
  BuildContext context,
  Widget sheet,
  String successMessage,
) async {
  final ok = await showDreamSheet<bool>(context, sheet);
  if (ok == true && context.mounted) {
    SnackBarUtils.showSuccess(context, successMessage);
  }
}

class _CoinSection extends ConsumerStatefulWidget {
  final DreamDetail detail;
  final bool isOwner;
  final bool launchesEnabled;
  const _CoinSection({
    required this.detail,
    required this.isOwner,
    required this.launchesEnabled,
  });

  @override
  ConsumerState<_CoinSection> createState() => _CoinSectionState();
}

class _CoinSectionState extends ConsumerState<_CoinSection> {
  bool _claiming = false;

  Future<void> _claim() async {
    setState(() => _claiming = true);
    try {
      await ref.read(dreamActionsProvider).claimFees(widget.detail.dream);
      if (mounted) {
        SnackBarUtils.showSuccess(context, 'Fees sent to your wallet');
      }
    } catch (e) {
      if (mounted) SnackBarUtils.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dc = context.dreamColors;
    final dream = widget.detail.dream;
    final coin = dream.coin;
    final stats = widget.detail.coinStats;

    if (coin == null) {
      if (!widget.isOwner || !widget.launchesEnabled || dream.isClosed) {
        return const SizedBox.shrink();
      }
      return _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Turn attention into support',
              style: TextStyle(
                color: dc.onSurface,
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              'Launch a coin for this dream. Every trade pays you a fee — people '
              'can support you just by trading it.',
              style: TextStyle(color: dc.muted, fontSize: 13.sp, height: 1.4),
            ),
            SizedBox(height: 12.h),
            DreamGhostButton(
              label: 'Launch a coin',
              icon: PhosphorIcons.rocketLaunch(),
              onPressed: () => _openSheet(
                context,
                LaunchCoinSheet(dream: dream),
                'Your coin is live',
              ),
            ),
          ],
        ),
      );
    }

    final graduated = stats?.graduated ?? false;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '\$${coin.symbol}',
                style: TextStyle(
                  color: dc.onSurface,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (stats != null)
                Text(
                  graduated
                      ? 'Graduated'
                      : '${(stats.curveProgress * 100).toStringAsFixed(1)}% to graduation',
                  style: TextStyle(color: dc.muted, fontSize: 12.sp),
                ),
            ],
          ),
          if (stats != null) ...[
            SizedBox(height: 6.h),
            Text(
              'Owner has earned ${stats.ownerLifetimeSol} SOL in fees',
              style: TextStyle(color: dc.muted, fontSize: 13.sp),
            ),
          ],
          SizedBox(height: 12.h),
          if (graduated)
            DreamGhostButton(
              label: 'Trade on Jupiter',
              icon: PhosphorIcons.arrowSquareOut(),
              onPressed: () => launchUrl(
                Uri.parse('https://jup.ag/swap/SOL-${coin.mint}'),
                mode: LaunchMode.externalApplication,
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: DreamPrimaryButton(
                    label: 'Buy',
                    onPressed: () => _openSheet(
                      context,
                      TradeCoinSheet(dream: dream, buy: true),
                      'Bought \$${coin.symbol}',
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: DreamGhostButton(
                    label: 'Sell',
                    onPressed: () => _openSheet(
                      context,
                      TradeCoinSheet(dream: dream, buy: false),
                      'Sold \$${coin.symbol}',
                    ),
                  ),
                ),
              ],
            ),
          if (widget.isOwner &&
              !graduated &&
              (stats?.hasUnclaimed ?? false)) ...[
            SizedBox(height: 10.h),
            DreamGhostButton(
              label: _claiming
                  ? 'Claiming…'
                  : 'Claim ${stats!.ownerUnclaimedSol} SOL',
              icon: PhosphorIcons.handCoins(),
              onPressed: _claiming ? null : _claim,
            ),
          ],
          if (widget.isOwner && graduated) ...[
            SizedBox(height: 8.h),
            Text(
              'After graduation your fees accrue to your LP position — claim them in the Meteora app.',
              style: TextStyle(color: dc.muted, fontSize: 12.sp, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    final dc = context.dreamColors;
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: dc.surface,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: dc.stroke.withValues(alpha: 0.7)),
      ),
      child: child,
    );
  }
}

class _Menu extends ConsumerWidget {
  final Dream dream;
  const _Menu({required this.dream});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(clientAuthProvider).walletAddress;
    final isOwner = me != null && me == dream.ownerWallet;

    return PopupMenuButton<String>(
      icon: Icon(PhosphorIcons.dotsThreeVertical()),
      onSelected: (action) async {
        final actions = ref.read(dreamActionsProvider);
        try {
          switch (action) {
            case 'share':
              unawaited(ProductAnalytics.dreamShared());
              await SharePlus.instance.share(
                ShareParams(
                  text:
                      '${dream.title}\n\nHelp make it happen on Dream: ${dream.shareUrl}',
                ),
              );
            case 'close':
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Close this dream?'),
                  content: const Text(
                    'It will stop accepting support and leave the public feed. '
                    'Your coin (if any) keeps trading.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Close dream'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) await actions.close(dream);
            default:
              await actions.report(dream, action);
              if (context.mounted) {
                SnackBarUtils.showInfo(context, 'Thanks — we’ll review it');
              }
          }
        } catch (e) {
          if (context.mounted) SnackBarUtils.showError(context, e.toString());
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'share', child: Text('Share')),
        if (isOwner && !dream.isClosed)
          const PopupMenuItem(value: 'close', child: Text('Close dream')),
        if (!isOwner) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(value: 'fake', child: Text('Report: looks fake')),
          const PopupMenuItem(value: 'scam', child: Text('Report: scam')),
          const PopupMenuItem(
            value: 'offensive',
            child: Text('Report: offensive'),
          ),
        ],
      ],
    );
  }
}

/// Shown only for a verified X post (the server sets the handle only after
/// proving the post contains this dream's id).
class _VerifiedXChip extends StatelessWidget {
  final String handle;
  final String? url;
  const _VerifiedXChip({required this.handle, this.url});

  @override
  Widget build(BuildContext context) {
    final dc = context.dreamColors;
    return InkWell(
      borderRadius: BorderRadius.circular(8.r),
      onTap: url == null
          ? null
          : () => launchUrl(
              Uri.parse(url!),
              mode: LaunchMode.externalApplication,
            ),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
        decoration: BoxDecoration(
          color: dc.success.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PhosphorIcons.sealCheck(PhosphorIconsStyle.fill),
              size: 13.r,
              color: dc.success,
            ),
            SizedBox(width: 4.w),
            Text(
              'Verified on X · @$handle',
              style: TextStyle(
                color: dc.success,
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Owner flow: post a pre-filled message containing the Dream ID from their
/// X account, then paste the post link so the server can verify it.
class _VerifyXPanel extends ConsumerStatefulWidget {
  final Dream dream;
  const _VerifyXPanel({required this.dream});

  @override
  ConsumerState<_VerifyXPanel> createState() => _VerifyXPanelState();
}

class _VerifyXPanelState extends ConsumerState<_VerifyXPanel> {
  final _url = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final intent = Uri.https('x.com', '/intent/post', {
      'text': widget.dream.xVerificationText,
    });
    await launchUrl(intent, mode: LaunchMode.externalApplication);
  }

  Future<void> _verify() async {
    final url = _url.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'Paste the link to your post');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(dreamActionsProvider).linkX(widget.dream, url);
      if (mounted) {
        SnackBarUtils.showSuccess(
          context,
          'Verified — supporters can see it’s you',
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dc = context.dreamColors;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Show it’s really you',
            style: TextStyle(
              color: dc.onSurface,
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'Dreams verified on X get far more support. Post from your X account '
            '(we pre-fill it with your Dream ID), then paste the link here.',
            style: TextStyle(color: dc.muted, fontSize: 13.sp, height: 1.4),
          ),
          SizedBox(height: 12.h),
          DreamGhostButton(
            label: '1. Post on X',
            icon: PhosphorIcons.xLogo(),
            onPressed: _post,
          ),
          SizedBox(height: 10.h),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            style: TextStyle(color: dc.onSurface, fontSize: 14.sp),
            decoration: InputDecoration(
              hintText: '2. Paste your post link',
              hintStyle: TextStyle(color: dc.muted),
              errorText: _error,
              isDense: true,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: dc.stroke),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: dc.primary),
              ),
            ),
          ),
          SizedBox(height: 10.h),
          DreamPrimaryButton(
            label: '3. Verify',
            isLoading: _busy,
            onPressed: _busy ? null : _verify,
          ),
        ],
      ),
    );
  }
}
