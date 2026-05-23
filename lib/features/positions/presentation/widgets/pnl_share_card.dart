import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/models/phoenix/phoenix_models.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';

// ---------------------------------------------------------------------------
// PnL Share Card — renders to PNG and shares via system share sheet
// ---------------------------------------------------------------------------

class PnlShareButton extends StatefulWidget {
  final PhoenixPosition position;
  final double livePnl;
  final double markPrice;

  const PnlShareButton({
    super.key,
    required this.position,
    required this.livePnl,
    required this.markPrice,
  });

  @override
  State<PnlShareButton> createState() => _PnlShareButtonState();
}

class _PnlShareButtonState extends State<PnlShareButton> {
  final _repaintKey = GlobalKey();
  final _logger = LoggerService();
  bool _sharing = false;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);

    try {
      // Wait a frame so the RepaintBoundary has a valid render object
      await Future.delayed(const Duration(milliseconds: 50));
      final boundary =
          _repaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      final xFile = XFile.fromData(
        Uint8List.fromList(bytes),
        name:
            'pnl_${widget.position.symbol.replaceAll('-', '_').toLowerCase()}.png',
        mimeType: 'image/png',
      );

      await Share.shareXFiles(
        [xFile],
        text:
            '${widget.position.side.toUpperCase()} ${widget.position.symbol} '
            '${_fmtPnl(widget.livePnl)} (${_fmtPct(_pnlPct)})',
      );

      _logger.info('[Trading] Shared PnL card for ${widget.position.symbol}');
    } catch (e) {
      _logger.error('[Trading] PnL share failed', error: e);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  double get _pnlPct {
    final c = widget.position.collateral;
    return c > 0 ? (widget.livePnl / c) * 100 : 0;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Hidden card rendered off-screen for screenshot capture
        Positioned(
          left: -9999,
          top: -9999,
          child: RepaintBoundary(
            key: _repaintKey,
            child: _PnlCard(
              position: widget.position,
              livePnl: widget.livePnl,
              markPrice: widget.markPrice,
            ),
          ),
        ),

        // Visible share button
        SizedBox(
          height: 34.h,
          child: OutlinedButton.icon(
            onPressed: _sharing ? null : _share,
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: AppColors.textMutedDark.withValues(alpha: 0.4),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6.r),
              ),
              padding: EdgeInsets.zero,
            ),
            icon: _sharing
                ? SizedBox(
                    width: 12.w,
                    height: 12.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: AppColors.textSecondaryDark,
                    ),
                  )
                : Icon(
                    Icons.share_outlined,
                    size: 13.sp,
                    color: AppColors.textSecondaryDark,
                  ),
            label: Text(
              'Share',
              style: TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Off-screen styled PnL card (rendered to PNG)
// ---------------------------------------------------------------------------

class _PnlCard extends StatelessWidget {
  final PhoenixPosition position;
  final double livePnl;
  final double markPrice;

  const _PnlCard({
    required this.position,
    required this.livePnl,
    required this.markPrice,
  });

  double get _pnlPct {
    final c = position.collateral;
    return c > 0 ? (livePnl / c) * 100 : 0;
  }

  @override
  Widget build(BuildContext context) {
    final isLong = position.side == 'long';
    final isProfit = livePnl >= 0;
    final sideColor = isLong ? AppColors.bullish : AppColors.bearish;
    final pnlColor = isProfit ? AppColors.bullish : AppColors.bearish;

    // Use MediaQuery-independent fixed sizes for screenshot card
    const cardW = 320.0;

    return SizedBox(
      width: cardW,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: cardW,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: pnlColor.withValues(alpha: 0.3),
              width: 1.5,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [const Color(0xFF13131C), const Color(0xFF0D0D12)],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: app brand + symbol
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'DREAM',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    position.symbol,
                    style: const TextStyle(
                      color: Color(0xFFE2E8F0),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Direction + leverage badge
              Row(
                children: [
                  _Badge(label: position.side.toUpperCase(), color: sideColor),
                  const SizedBox(width: 8),
                  _Badge(
                    label:
                        '${position.leverage.toStringAsFixed(position.leverage % 1 == 0 ? 0 : 1)}×',
                    color: AppColors.primary,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // PnL
              Text(
                _fmtPnl(livePnl),
                style: TextStyle(
                  color: pnlColor,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: pnlColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _fmtPct(_pnlPct),
                      style: TextStyle(
                        color: pnlColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Entry / Mark price row
              Row(
                children: [
                  _PriceCol(
                    label: 'Entry',
                    value: formatPrice(position.entryPrice),
                  ),
                  const SizedBox(width: 24),
                  _PriceCol(label: 'Mark', value: formatPrice(markPrice)),
                  const SizedBox(width: 24),
                  _PriceCol(
                    label: 'Size',
                    value:
                        '${position.sizeBase.toStringAsFixed(4)} ${position.symbol.split('-').first}',
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Footer
              Text(
                'phoenix.trade/perps',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.25),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _PriceCol extends StatelessWidget {
  final String label;
  final String value;

  const _PriceCol({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFFCBD5E1),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _fmtPnl(double v) {
  final sign = v >= 0 ? '+' : '';
  return '$sign\$${v.abs().toStringAsFixed(2)}';
}

String _fmtPct(double v) {
  final sign = v >= 0 ? '+' : '';
  return '$sign${v.toStringAsFixed(2)}%';
}
