import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/models/phoenix/phoenix_models.dart';
import '../../../../core/navigation/trade_share_link.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../../providers/trade_provider.dart';

class TradeReceiptSheet extends StatefulWidget {
  final TradeSubmittedTrade trade;
  final PhoenixPosition? position;

  const TradeReceiptSheet({super.key, required this.trade, this.position});

  static Future<void> show(
    BuildContext context, {
    required TradeSubmittedTrade trade,
    PhoenixPosition? position,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (_) => TradeReceiptSheet(trade: trade, position: position),
    );
  }

  @override
  State<TradeReceiptSheet> createState() => _TradeReceiptSheetState();
}

class _TradeReceiptSheetState extends State<TradeReceiptSheet> {
  final _receiptKey = GlobalKey();
  bool _isSharing = false;
  File? _receiptImageFile;

  _TradeReceiptData get _data =>
      _TradeReceiptData.from(trade: widget.trade, position: widget.position);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _captureReceiptImage();
    });
  }

  Future<void> _captureReceiptImage() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 220));
      final boundary =
          _receiptKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final tempDir = await Directory.systemTemp.createTemp('dream-receipt-');
      final file = File('${tempDir.path}/trade-receipt.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      if (mounted) {
        setState(() => _receiptImageFile = file);
      }
    } catch (_) {
      // Sharing gracefully falls back to text-only if image capture fails.
    }
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(
      ClipboardData(text: _data.shareLink.webUri.toString()),
    );
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Trade link copied'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16.w),
      ),
    );
  }

  Future<void> _shareReceipt() async {
    setState(() => _isSharing = true);
    try {
      if (_receiptImageFile == null || !await _receiptImageFile!.exists()) {
        await _captureReceiptImage();
      }

      final file = _receiptImageFile;
      if (file != null && await file.exists()) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            text: _data.shareText,
            subject: '${_data.displaySymbol} on Dream',
          ),
        );
      } else {
        await SharePlus.instance.share(
          ShareParams(
            text: _data.shareText,
            subject: '${_data.displaySymbol} on Dream',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  Future<void> _openSolscan() async {
    if (_data.txSignature.isEmpty) return;
    final uri = Uri.parse('https://solscan.io/tx/${_data.txSignature}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.borderDark,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            SizedBox(height: 14.h),
            Text(
              'Trade Receipt',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimaryDark,
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              _data.sheetSubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 12.sp,
              ),
            ),
            SizedBox(height: 18.h),
            RepaintBoundary(
              key: _receiptKey,
              child: _TradeReceiptCard(data: _data),
            ),
            SizedBox(height: 18.h),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSharing ? null : _shareReceipt,
                    icon: _isSharing
                        ? SizedBox(
                            width: 16.w,
                            height: 16.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(PhosphorIcons.shareNetwork(), size: 18.sp),
                    label: Text(_isSharing ? 'Sharing…' : 'Share'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _copyLink,
                    icon: Icon(PhosphorIcons.copy(), size: 18.sp),
                    label: const Text('Copy Link'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimaryDark,
                      side: BorderSide(color: AppColors.borderDark),
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_data.txSignature.isNotEmpty) ...[
              SizedBox(height: 6.h),
              TextButton.icon(
                onPressed: _openSolscan,
                icon: Icon(PhosphorIcons.arrowSquareOut(), size: 18.sp),
                label: const Text('View on Solscan'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondaryDark,
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TradeReceiptCard extends StatelessWidget {
  final _TradeReceiptData data;

  const _TradeReceiptCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24.r),
          boxShadow: [
            BoxShadow(
              color: data.glowColor.withValues(alpha: 0.28),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24.r),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.surfaceDark,
                      AppColors.cardDark,
                      data.glowColor.withValues(alpha: 0.22),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: -40.h,
                right: -20.w,
                child: Container(
                  width: 180.w,
                  height: 180.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        data.glowColor.withValues(alpha: 0.24),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    data.glowColor.withValues(alpha: 0.22),
                    BlendMode.softLight,
                  ),
                  child: Image.asset(
                    'assets/images/receipt-texture.png',
                    fit: BoxFit.cover,
                    opacity: const AlwaysStoppedAnimation(0.18),
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(22.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.textPrimaryDark.withValues(
                              alpha: 0.08,
                            ),
                            borderRadius: BorderRadius.circular(999.r),
                            border: Border.all(
                              color: AppColors.textPrimaryDark.withValues(
                                alpha: 0.08,
                              ),
                            ),
                          ),
                          child: Text(
                            data.cardLabel,
                            style: TextStyle(
                              color: AppColors.textPrimaryDark,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: data.sideColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999.r),
                            border: Border.all(
                              color: data.sideColor.withValues(alpha: 0.32),
                            ),
                          ),
                          child: Text(
                            '${data.sideLabel} ${data.leverageLabel}',
                            style: TextStyle(
                              color: data.sideColor,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      data.displaySymbol,
                      style: TextStyle(
                        color: AppColors.textPrimaryDark,
                        fontSize: 28.sp,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      data.headline,
                      style: TextStyle(
                        color: data.headlineColor,
                        fontSize: 32.sp,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      data.subheadline,
                      style: TextStyle(
                        color: AppColors.textSecondaryDark,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 18.h),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                _ReceiptMetric(
                                  label: data.primaryMetricLabel,
                                  value: data.primaryMetricValue,
                                ),
                                SizedBox(height: 10.h),
                                _ReceiptMetric(
                                  label: 'Collateral',
                                  value: formatUsdc(data.collateralUsdc),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Column(
                              children: [
                                _ReceiptMetric(
                                  label: data.secondaryMetricLabel,
                                  value: data.secondaryMetricValue,
                                ),
                                SizedBox(height: 10.h),
                                _ReceiptMetric(
                                  label: 'Liq. Price',
                                  value: data.liquidationText,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            data.txLabel,
                            style: TextStyle(
                              color: AppColors.textTertiaryDark,
                              fontSize: 10.sp,
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Text(
                          data.deepLinkLabel,
                          style: TextStyle(
                            color: AppColors.textSecondaryDark,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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
}

class _ReceiptMetric extends StatelessWidget {
  final String label;
  final String value;

  const _ReceiptMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: AppColors.textTertiaryDark,
                fontSize: 10.sp,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              value,
              style: TextStyle(
                color: AppColors.textPrimaryDark,
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TradeReceiptData {
  final TradeSubmittedTrade trade;
  final PhoenixPosition? position;
  final TradeShareLink shareLink;

  const _TradeReceiptData({
    required this.trade,
    required this.position,
    required this.shareLink,
  });

  factory _TradeReceiptData.from({
    required TradeSubmittedTrade trade,
    PhoenixPosition? position,
  }) {
    return _TradeReceiptData(
      trade: trade,
      position: position,
      shareLink: TradeShareLink(
        symbol: trade.symbol,
        side: trade.side == OrderSide.buy ? 'buy' : 'sell',
        leverage: trade.leverage,
      ),
    );
  }

  String get baseSymbol => trade.symbol.split('-').first;
  String get displaySymbol => '$baseSymbol/USDC';
  String get sideLabel => trade.side == OrderSide.buy ? 'LONG' : 'SHORT';
  String get leverageLabel =>
      trade.leverage.truncateToDouble() == trade.leverage
      ? '${trade.leverage.toStringAsFixed(0)}x'
      : '${trade.leverage.toStringAsFixed(1)}x';
  double get collateralUsdc => position?.collateral ?? trade.collateralUsdc;
  Color get sideColor =>
      trade.side == OrderSide.buy ? AppColors.bullish : AppColors.bearish;

  bool get hasLivePosition => position != null;
  bool get hasLivePnl =>
      hasLivePosition && position!.unrealizedPnl.abs() > 0.009;
  bool get isProfit => (position?.unrealizedPnl ?? 0) >= 0;
  Color get headlineColor => hasLivePnl
      ? (isProfit ? AppColors.bullish : AppColors.bearish)
      : AppColors.textPrimaryDark;
  Color get glowColor => hasLivePnl
      ? (isProfit ? AppColors.success : AppColors.error)
      : AppColors.primary;
  String get cardLabel => hasLivePnl ? 'LIVE P&L' : 'TRADE RECEIPT';

  String get headline => hasLivePnl
      ? formatPnl(position!.unrealizedPnl)
      : '${trade.quantity.toStringAsFixed(4)} $baseSymbol';

  String get subheadline {
    if (hasLivePnl) {
      return '${formatPercent(position!.unrealizedPnlPercent)} unrealized · ${formatUsdc(position!.sizeUsd)} notional';
    }
    return '${formatUsdc(trade.notionalUsdc)} notional · ${trade.orderType == OrderType.market ? 'Market order' : 'Limit order'}';
  }

  String get primaryMetricLabel => hasLivePnl ? 'Entry' : 'Est. Entry';
  String get primaryMetricValue =>
      formatPrice(position?.entryPrice ?? trade.entryPrice);
  String get secondaryMetricLabel => hasLivePnl ? 'Mark' : 'Size';
  String get secondaryMetricValue => hasLivePnl
      ? formatPrice(position!.markPrice)
      : '${trade.quantity.toStringAsFixed(4)} $baseSymbol';
  String get liquidationText =>
      formatPrice(position?.liquidationPrice ?? trade.estimatedLiqPrice ?? 0);
  String get txSignature => trade.txSignature;
  String get txLabel => trade.txSignature.isNotEmpty
      ? 'Tx ${trade.txSignature.substring(0, 8)}...${trade.txSignature.substring(trade.txSignature.length - 8)}'
      : _formatTimestamp(trade.submittedAt);
  String get deepLinkLabel => 'dream.app/trade/${trade.symbol}';

  String get sheetSubtitle => hasLivePnl
      ? 'Share the setup and the live P&L from your open trade.'
      : 'Share the setup and an open-app link instead of a raw transaction line.';

  String get shareText {
    final direction =
        '${trade.side == OrderSide.buy ? 'Long' : 'Short'} $baseSymbol ${leverageLabel.toUpperCase()}';
    final openLink = shareLink.webUri.toString();

    if (hasLivePnl) {
      return '${isProfit ? 'Up' : 'Live'} ${formatPnl(position!.unrealizedPnl)} (${formatPercent(position!.unrealizedPnlPercent)}) on $direction in Dream.\nOpen in Dream: $openLink';
    }

    return '$direction opened on Dream.\nEntry ${formatPrice(trade.entryPrice)} · ${trade.quantity.toStringAsFixed(4)} $baseSymbol · ${formatUsdc(trade.collateralUsdc)} collateral\nOpen in Dream: $openLink';
  }

  static String _formatTimestamp(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final meridiem = value.hour >= 12 ? 'PM' : 'AM';
    return '${value.month}/${value.day} · $hour:$minute $meridiem';
  }
}
