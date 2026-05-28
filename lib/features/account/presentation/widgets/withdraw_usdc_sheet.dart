import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/providers/wallet/wallet_balance_provider.dart';
import '../../../../core/services/solana/usdc_transfer_service.dart';
import 'withdraw_usdc_form.dart';
import 'withdraw_usdc_success.dart';
import '../../../../core/theme/dream_colors.dart';

// Bottom sheet to send USDC from the user's connected wallet to any Solana
// address. Builds + signs + broadcasts an SPL transferChecked transaction
// (auto-creates the recipient's ATA if missing).
class WithdrawUsdcSheet extends ConsumerStatefulWidget {
  final String walletAddress;
  const WithdrawUsdcSheet({super.key, required this.walletAddress});

  static Future<void> show(
    BuildContext context, {
    required String walletAddress,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.dreamColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (_) => WithdrawUsdcSheet(walletAddress: walletAddress),
    );
  }

  @override
  ConsumerState<WithdrawUsdcSheet> createState() => _WithdrawUsdcSheetState();
}

class _WithdrawUsdcSheetState extends ConsumerState<WithdrawUsdcSheet> {
  final _destController = TextEditingController();
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _submitting = false;
  String? _submitError;
  String? _txSignature;

  @override
  void dispose() {
    _destController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _setMax(double balance) {
    _amountController.text = balance.toStringAsFixed(2);
  }

  String? _validateDest(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Destination address required';
    if (s.length < 32 || s.length > 44) return 'Invalid Solana address';
    final base58 = RegExp(r'^[1-9A-HJ-NP-Za-km-z]+$');
    if (!base58.hasMatch(s)) return 'Invalid base58 characters';
    if (s == widget.walletAddress) return 'Cannot send to yourself';
    return null;
  }

  String? _validateAmount(String? v, double balance) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Amount required';
    final n = double.tryParse(s);
    if (n == null || n <= 0) return 'Enter a positive amount';
    if (n > balance) return 'Exceeds available balance';
    return null;
  }

  Future<void> _pasteDestination() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty) {
      _destController.text = text;
    }
  }

  Future<void> _submit(double balance) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    final service = ref.read(usdcTransferServiceProvider);
    final result = await service.sendUsdc(
      fromOwner: widget.walletAddress,
      toOwner: _destController.text.trim(),
      amountUsdc: double.parse(_amountController.text.trim()),
    );

    if (!mounted) return;

    if (result.success) {
      ref.invalidate(walletUsdcBalanceProvider);
      setState(() {
        _submitting = false;
        _txSignature = result.signature;
      });
    } else {
      setState(() {
        _submitting = false;
        _submitError = result.error;
      });
    }
  }

  Future<void> _openExplorer() async {
    final sig = _txSignature;
    if (sig == null) return;
    final uri = Uri.parse('https://explorer.solana.com/tx/$sig');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usdcAsync = ref.watch(
      walletUsdcBalanceProvider(widget.walletAddress),
    );
    final balance = usdcAsync.value ?? 0.0;

    return SafeArea(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.only(
            left: 20.w,
            right: 20.w,
            top: 12.h,
            bottom: 24.h + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: _txSignature != null
              ? WithdrawSuccessView(
                  onOpenExplorer: _openExplorer,
                  onDone: () => Navigator.pop(context),
                )
              : WithdrawUsdcFormBody(
                  formKey: _formKey,
                  destController: _destController,
                  amountController: _amountController,
                  balance: balance,
                  loadingBalance: usdcAsync.isLoading,
                  submitting: _submitting,
                  submitError: _submitError,
                  onPaste: _pasteDestination,
                  onSetMax: () => _setMax(balance),
                  onSubmit: () => _submit(balance),
                  validateDest: _validateDest,
                  validateAmount: (v) => _validateAmount(v, balance),
                ),
        ),
      ),
    );
  }
}
