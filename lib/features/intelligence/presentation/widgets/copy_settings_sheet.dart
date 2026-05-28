import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/intelligence_models.dart';
import '../../../../core/theme/dream_colors.dart';

/// Bottom sheet for configuring copy settings before following a leader.
class CopySettingsSheet extends StatefulWidget {
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
      builder: (_) => CopySettingsSheet(
        leader: leader,
        initial: initial,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  State<CopySettingsSheet> createState() => _CopySettingsSheetState();
}

class _CopySettingsSheetState extends State<CopySettingsSheet> {
  late double _copyUSDC;
  late double _slippage;
  late double _stopLoss;
  final _usdcController = TextEditingController();

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.dreamColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.r),
          topRight: Radius.circular(20.r),
        ),
        border: Border.all(color: context.dreamColors.stroke.withValues(alpha: 0.5)),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            16.w,
            16.h,
            16.w,
            MediaQuery.of(context).viewInsets.bottom + 24.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Handle(),
              SizedBox(height: 16.h),
              Text(
                'Copy ${widget.leader.displayLabel}',
                style: TextStyle(
                  color: context.dreamColors.onSurface,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'Orders are mirrored proportionally as the trader opens positions.',
                style: TextStyle(
                  color: context.dreamColors.muted,
                  fontSize: 12.sp,
                ),
              ),
              SizedBox(height: 20.h),
              // USDC per trade
              _Label('Size per copy trade (USDC)'),
              SizedBox(height: 6.h),
              _TextField(
                controller: _usdcController,
                suffix: 'USDC',
                keyboardType: TextInputType.number,
                onChanged: (v) {
                  final parsed = double.tryParse(v);
                  if (parsed != null && parsed > 0) {
                    setState(() => _copyUSDC = parsed);
                  }
                },
              ),
              SizedBox(height: 16.h),
              // Slippage
              _Label('Max slippage: ${(_slippage * 100).toStringAsFixed(1)}%'),
              SizedBox(height: 4.h),
              Slider(
                value: _slippage,
                min: 0.001,
                max: 0.05,
                divisions: 49,
                activeColor: AppColors.primary,
                inactiveColor: context.dreamColors.stroke,
                onChanged: (v) => setState(() => _slippage = v),
              ),
              SizedBox(height: 12.h),
              // Stop-loss
              _Label(
                'Stop-loss: ${(_stopLoss * 100).toStringAsFixed(0)}% of entry',
              ),
              SizedBox(height: 4.h),
              Slider(
                value: _stopLoss,
                min: 0.05,
                max: 0.5,
                divisions: 45,
                activeColor: AppColors.warning,
                inactiveColor: context.dreamColors.stroke,
                onChanged: (v) => setState(() => _stopLoss = v),
              ),
              SizedBox(height: 24.h),
              _ConfirmButton(
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onConfirm(
                    CopySettings(
                      copyUSDC: _copyUSDC,
                      maxSlippage: _slippage,
                      stopLossRatio: _stopLoss,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36.w,
        height: 4.h,
        decoration: BoxDecoration(
          color: context.dreamColors.stroke,
          borderRadius: BorderRadius.circular(2.r),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: context.dreamColors.muted,
        fontSize: 12.sp,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String suffix;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;

  const _TextField({
    required this.controller,
    required this.suffix,
    this.keyboardType = TextInputType.text,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44.h,
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      decoration: BoxDecoration(
        color: AppColors.insetDark,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: context.dreamColors.stroke),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              onChanged: onChanged,
              style: TextStyle(
                color: context.dreamColors.onSurface,
                fontSize: 14.sp,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          Text(
            suffix,
            style: TextStyle(
              color: context.dreamColors.muted,
              fontSize: 12.sp,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ConfirmButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48.h,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(PhosphorIcons.copy(PhosphorIconsStyle.bold), size: 16.r),
            SizedBox(width: 8.w),
            Text(
              'Start Copy Trading',
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
