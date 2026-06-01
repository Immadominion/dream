import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/providers/solana/wallet_name_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/dream_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../../models/intelligence_models.dart';

/// Bottom sheet for configuring copy settings before following a leader.
class CopySettingsSheet extends ConsumerStatefulWidget {
  final LeaderProfile leader;
  final CopySettings initial;
  final ValueChanged<CopySettings> onConfirm;

  const CopySettingsSheet({
    super.key,
    required this.leader,
    required this.initial,
    required this.onConfirm,
  });

  static Future<void> show(
    BuildContext context, {
    required LeaderProfile leader,
    CopySettings initial = const CopySettings(),
    required ValueChanged<CopySettings> onConfirm,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => CopySettingsSheet(
        leader: leader,
        initial: initial,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  ConsumerState<CopySettingsSheet> createState() => _CopySettingsSheetState();
}

class _CopySettingsSheetState extends ConsumerState<CopySettingsSheet> {
  late double _copyUSDC;
  late double _slippage;
  late double _stopLoss;
  final _usdcController = TextEditingController();
  final _usdcFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _copyUSDC = widget.initial.copyUSDC;
    _slippage = widget.initial.maxSlippage;
    _stopLoss = widget.initial.stopLossRatio;
    _usdcController.text = _copyUSDC.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _usdcController.dispose();
    _usdcFocus.dispose();
    super.dispose();
  }

  void _confirm() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
    widget.onConfirm(
      CopySettings(
        copyUSDC: _copyUSDC,
        maxSlippage: _slippage,
        stopLossRatio: _stopLoss,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.dreamColors;
    final leader = widget.leader;
    final domain = ref.watch(walletNameProvider(leader.address)).asData?.value;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              20.w,
              8.h,
              20.w,
              MediaQuery.of(context).viewInsets.bottom + 16.h,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DragHandle(),
                SizedBox(height: 14.h),
                _LeaderIdentity(leader: leader, domain: domain),
                if (_hasStats(leader)) ...[
                  SizedBox(height: 10.h),
                  _StatStrip(leader: leader),
                ],
                SizedBox(height: 20.h),
                _FieldLabel(
                  'Amount per copied trade',
                  hint: 'USDC committed each time they open',
                ),
                SizedBox(height: 12.h),
                _AmountField(
                  controller: _usdcController,
                  focusNode: _usdcFocus,
                  onChanged: (v) {
                    final parsed = double.tryParse(v);
                    if (parsed != null && parsed > 0) {
                      setState(() => _copyUSDC = parsed);
                    }
                  },
                ),
                SizedBox(height: 22.h),
                _SliderRow(
                  label: 'Max slippage',
                  value: '${(_slippage * 100).toStringAsFixed(1)}%',
                  accent: AppColors.primary,
                  slider: Slider(
                    value: _slippage,
                    min: 0.001,
                    max: 0.05,
                    divisions: 49,
                    activeColor: AppColors.primary,
                    inactiveColor: colors.stroke.withValues(alpha: 0.6),
                    onChanged: (v) => setState(() => _slippage = v),
                  ),
                ),
                SizedBox(height: 6.h),
                _SliderRow(
                  label: 'Stop-loss from entry',
                  value: '${(_stopLoss * 100).toStringAsFixed(0)}%',
                  accent: AppColors.warning,
                  slider: Slider(
                    value: _stopLoss,
                    min: 0.05,
                    max: 0.5,
                    divisions: 45,
                    activeColor: AppColors.warning,
                    inactiveColor: colors.stroke.withValues(alpha: 0.6),
                    onChanged: (v) => setState(() => _stopLoss = v),
                  ),
                ),
                SizedBox(height: 20.h),
                _MirrorNote(),
                SizedBox(height: 18.h),
                _ConfirmButton(
                  label: 'Copy ${leader.displayLabel}',
                  onTap: _confirm,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _hasStats(LeaderProfile leader) =>
      leader.hasPnlHistory || leader.copierCount > 0 || leader.winRate > 0;
}

// ── Identity ──────────────────────────────────────────────────────────────────

class _LeaderIdentity extends StatelessWidget {
  final LeaderProfile leader;
  final String? domain;

  const _LeaderIdentity({required this.leader, this.domain});

  @override
  Widget build(BuildContext context) {
    final colors = context.dreamColors;
    final title = leader.label ?? domain ?? leader.displayLabel;
    final subtitle = switch ((leader.label, domain)) {
      (String _, String d) => d,
      (String _, null) => _short(leader.address),
      (null, String _) => _short(leader.address),
      _ => null,
    };

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              if (subtitle != null) ...[
                SizedBox(height: 3.h),
                Text(
                  subtitle,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.mutedSecondary,
                    fontSize: 12.sp,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (leader.isRegistered) ...[SizedBox(width: 10.w), _VerifiedBadge()],
      ],
    );
  }

  String _short(String address) {
    if (address.length <= 10) return address;
    return '${address.substring(0, 4)}…${address.substring(address.length - 4)}';
  }
}

class _VerifiedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            PhosphorIcons.broadcast(PhosphorIconsStyle.fill),
            size: 11.r,
            color: AppColors.primary,
          ),
          SizedBox(width: 5.w),
          Text(
            'Broadcaster',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stat strip ────────────────────────────────────────────────────────────────

class _StatStrip extends StatelessWidget {
  final LeaderProfile leader;
  const _StatStrip({required this.leader});

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];

    if (leader.hasPnlHistory) {
      items.add(
        _InlineStat(
          label: '7d PnL',
          value: formatPnl(leader.pnl7d),
          valueColor: leader.pnl7d >= 0 ? AppColors.bullish : AppColors.bearish,
        ),
      );
    }
    if (leader.winRate > 0) {
      final pct = leader.winRate <= 1 ? leader.winRate * 100 : leader.winRate;
      items.add(_InlineStat(label: 'Win', value: '${pct.toStringAsFixed(0)}%'));
    }
    if (leader.copierCount > 0) {
      items.add(_InlineStat(label: 'Copiers', value: '${leader.copierCount}'));
    }

    return Wrap(spacing: 12.w, runSpacing: 6.h, children: items);
  }
}

class _InlineStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InlineStat({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.dreamColors;
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label ',
            style: TextStyle(
              color: colors.mutedSecondary,
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              color: valueColor ?? colors.onSurface,
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Inputs ────────────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  final String? hint;
  const _FieldLabel(this.text, {this.hint});

  @override
  Widget build(BuildContext context) {
    final colors = context.dreamColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (hint != null) ...[
          SizedBox(height: 3.h),
          Text(
            hint!,
            style: TextStyle(color: colors.mutedSecondary, fontSize: 11.sp),
          ),
        ],
      ],
    );
  }
}

class _AmountField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const _AmountField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.dreamColors;
    return Container(
      height: 54.h,
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: colors.stroke.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Text(
            '\$',
            style: TextStyle(
              color: colors.mutedSecondary,
              fontSize: 20.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(width: 6.w),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              onChanged: onChanged,
              cursorColor: colors.primary,
              textAlignVertical: TextAlignVertical.center,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 22.sp,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: '50',
                hintStyle: TextStyle(
                  color: colors.mutedSecondary,
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w600,
                ),
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,

                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          Text(
            'USDC',
            style: TextStyle(
              color: colors.muted,
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  final Widget slider;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.accent,
    required this.slider,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.dreamColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: colors.muted,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(7.r),
              ),
              child: Text(
                value,
                style: TextStyle(
                  color: accent,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3.h,
            overlayShape: SliderComponentShape.noOverlay,
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7.r),
          ),
          child: slider,
        ),
      ],
    );
  }
}

class _MirrorNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.dreamColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          PhosphorIcons.warningCircle(PhosphorIconsStyle.fill),
          size: 14.r,
          color: colors.mutedSecondary,
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            'New positions open automatically. '
            'Pause or unfollow anytime.',
            style: TextStyle(
              color: colors.mutedSecondary,
              fontSize: 11.sp,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _ConfirmButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ConfirmButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52.h,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50.r),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(PhosphorIcons.copy(PhosphorIconsStyle.bold), size: 17.r),
            SizedBox(width: 9.w),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40.w,
        height: 4.h,
        decoration: BoxDecoration(
          color: context.dreamColors.stroke,
          borderRadius: BorderRadius.circular(2.r),
        ),
      ),
    );
  }
}
