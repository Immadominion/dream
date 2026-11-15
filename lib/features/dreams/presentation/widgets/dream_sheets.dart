import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/dream_colors.dart';
import '../../../../shared/widgets/dream_buttons.dart';
import '../../models/dream_models.dart';
import '../../providers/dreams_providers.dart';
import 'dream_card.dart';

/// Shared bottom-sheet chrome: grabber, title, subtitle, body.
class DreamSheetScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  const DreamSheetScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final dc = context.dreamColors;
    return Container(
      decoration: BoxDecoration(
        color: dc.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        border: Border(
          top: BorderSide(color: dc.stroke.withValues(alpha: 0.6)),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        20.w,
        0,
        20.w,
        MediaQuery.of(context).viewInsets.bottom + 28.h,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: EdgeInsets.only(top: 12.h, bottom: 20.h),
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: dc.stroke,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            Text(
              title,
              style: TextStyle(
                color: dc.onSurface,
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle != null) ...[
              SizedBox(height: 6.h),
              Text(
                subtitle!,
                style: TextStyle(color: dc.muted, fontSize: 13.sp, height: 1.4),
              ),
            ],
            SizedBox(height: 18.h),
            child,
          ],
        ),
      ),
    );
  }
}

Future<T?> showDreamSheet<T>(BuildContext context, Widget sheet) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => sheet,
  );
}

class _AmountField extends StatelessWidget {
  final TextEditingController controller;
  final String suffix;
  final String? errorText;
  final int decimals;
  const _AmountField({
    required this.controller,
    required this.suffix,
    required this.decimals,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final dc = context.dreamColors;
    return TextField(
      controller: controller,
      autofocus: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          RegExp('^\\d{0,9}(\\.\\d{0,$decimals})?'),
        ),
      ],
      style: TextStyle(
        color: dc.onSurface,
        fontSize: 28.sp,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        hintText: '0',
        hintStyle: TextStyle(color: dc.muted),
        suffixText: suffix,
        suffixStyle: TextStyle(color: dc.muted, fontSize: 16.sp),
        errorText: errorText,
        border: InputBorder.none,
      ),
    );
  }
}

class _QuickAmounts extends StatelessWidget {
  final List<String> values;
  final ValueChanged<String> onPick;
  final String Function(String) label;
  const _QuickAmounts({
    required this.values,
    required this.onPick,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final dc = context.dreamColors;
    return Wrap(
      spacing: 8.w,
      children: [
        for (final v in values)
          ActionChip(
            label: Text(label(v)),
            onPressed: () => onPick(v),
            backgroundColor: dc.surfaceVariant,
            side: BorderSide(color: dc.stroke),
            labelStyle: TextStyle(color: dc.onSurface, fontSize: 13.sp),
          ),
      ],
    );
  }
}

// ── Fund (direct USDC) ───────────────────────────────────────────────────────

class FundDreamSheet extends ConsumerStatefulWidget {
  final Dream dream;
  const FundDreamSheet({super.key, required this.dream});

  @override
  ConsumerState<FundDreamSheet> createState() => _FundDreamSheetState();
}

class _FundDreamSheetState extends ConsumerState<FundDreamSheet> {
  final _amount = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit(double balance) async {
    final value = double.tryParse(_amount.text) ?? 0;
    if (value < 0.01) return setState(() => _error = 'Enter at least \$0.01');
    if (value > balance) {
      return setState(
        () => _error = 'You have ${balance.toStringAsFixed(2)} USDC',
      );
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(dreamActionsProvider).fund(widget.dream, value);
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dc = context.dreamColors;
    final balance = ref.watch(usdcBalanceProvider).value ?? 0;
    return DreamSheetScaffold(
      title: 'Fund this dream',
      subtitle:
          'USDC goes straight from your wallet to ${shortWallet(widget.dream.ownerWallet)}. Dream never holds it.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AmountField(
            controller: _amount,
            suffix: 'USDC',
            decimals: 2,
            errorText: _error,
          ),
          Text(
            'Balance: ${balance.toStringAsFixed(2)} USDC',
            style: TextStyle(color: dc.muted, fontSize: 12.sp),
          ),
          SizedBox(height: 12.h),
          _QuickAmounts(
            values: const ['5', '10', '25', '50'],
            label: (v) => '\$$v',
            onPick: (v) => setState(() => _amount.text = v),
          ),
          SizedBox(height: 20.h),
          DreamPrimaryButton(
            label: 'Send',
            isLoading: _busy,
            onPressed: _busy ? null : () => _submit(balance),
          ),
        ],
      ),
    );
  }
}

// ── Launch coin (owner only) ─────────────────────────────────────────────────

class LaunchCoinSheet extends ConsumerStatefulWidget {
  final Dream dream;
  const LaunchCoinSheet({super.key, required this.dream});

  @override
  ConsumerState<LaunchCoinSheet> createState() => _LaunchCoinSheetState();
}

class _LaunchCoinSheetState extends ConsumerState<LaunchCoinSheet> {
  late final _name = TextEditingController(
    text: widget.dream.title.length <= 32
        ? widget.dream.title
        : widget.dream.title.substring(0, 32).trim(),
  );
  final _symbol = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _symbol.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final symbol = _symbol.text.trim().toUpperCase();
    if (name.length < 2) return setState(() => _error = 'Add a name');
    if (!RegExp(r'^[A-Z0-9]{2,10}$').hasMatch(symbol)) {
      return setState(() => _error = 'Ticker: 2–10 letters or digits');
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(dreamActionsProvider)
          .launchCoin(widget.dream, name: name, symbol: symbol);
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dc = context.dreamColors;
    InputDecoration deco(String label, {String? prefix}) => InputDecoration(
      labelText: label,
      prefixText: prefix,
      labelStyle: TextStyle(color: dc.muted),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: dc.stroke),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: dc.primary),
      ),
    );
    return DreamSheetScaffold(
      title: 'Launch a coin for your dream',
      subtitle:
          'You become the coin’s creator: 64% of every trading fee goes to your wallet '
          'while it trades on its curve, and you keep earning LP fees after it graduates. '
          'Liquidity is locked and supply is fixed. Launching costs about 0.03 SOL.',
      child: Column(
        children: [
          TextField(
            controller: _name,
            maxLength: 32,
            style: TextStyle(color: dc.onSurface),
            decoration: deco('Coin name'),
          ),
          SizedBox(height: 8.h),
          TextField(
            controller: _symbol,
            maxLength: 10,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
            ],
            style: TextStyle(color: dc.onSurface),
            decoration: deco('Ticker', prefix: '\$'),
          ),
          if (_error != null)
            Padding(
              padding: EdgeInsets.only(top: 4.h),
              child: Text(
                _error!,
                style: TextStyle(color: dc.error, fontSize: 12.sp),
              ),
            ),
          SizedBox(height: 16.h),
          DreamPrimaryButton(
            label: 'Launch coin',
            isLoading: _busy,
            onPressed: _busy ? null : _submit,
          ),
        ],
      ),
    );
  }
}

// ── Trade coin ───────────────────────────────────────────────────────────────

class TradeCoinSheet extends ConsumerStatefulWidget {
  final Dream dream;
  final bool buy;
  const TradeCoinSheet({super.key, required this.dream, required this.buy});

  @override
  ConsumerState<TradeCoinSheet> createState() => _TradeCoinSheetState();
}

class _TradeCoinSheetState extends ConsumerState<TradeCoinSheet> {
  static const _coinDecimals = 6;
  static const _lamportsPerSol = 1000000000;

  final _amount = TextEditingController();
  bool _busy = false;
  String? _error;

  /// Set after "Review": the exact trade the user will be asked to sign.
  SwapQuote? _quote;

  @override
  void initState() {
    super.initState();
    // Editing the amount invalidates a reviewed quote.
    _amount.addListener(() {
      if (_quote != null) setState(() => _quote = null);
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  static String _formatUnits(BigInt units, int decimals, {int shown = 4}) {
    final base = BigInt.from(10).pow(decimals);
    final whole = units ~/ base;
    final frac = (units % base).toString().padLeft(decimals, '0');
    final trimmed = frac.substring(0, shown).replaceAll(RegExp(r'0+$'), '');
    return trimmed.isEmpty ? '$whole' : '$whole.$trimmed';
  }

  /// Decimal string → raw integer units, without floating-point rounding.
  static BigInt? _toUnits(String text, int decimals) {
    final m = RegExp(r'^(\d+)(?:\.(\d+))?$').firstMatch(text.trim());
    if (m == null) return null;
    final frac = (m.group(2) ?? '').padRight(decimals, '0');
    if (frac.length > decimals) return null;
    return BigInt.parse(m.group(1)!) * BigInt.from(10).pow(decimals) +
        BigInt.parse(frac.isEmpty ? '0' : frac);
  }

  /// Step 1: build the trade and show what the user will get.
  Future<void> _review({required BigInt max}) async {
    final decimals = widget.buy ? 9 : _coinDecimals;
    final units = _toUnits(_amount.text, decimals);
    if (units == null || units <= BigInt.zero) {
      return setState(() => _error = 'Enter an amount');
    }
    if (units > max) return setState(() => _error = 'Not enough balance');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final quote = await ref
          .read(dreamActionsProvider)
          .quoteSwap(widget.dream, buy: widget.buy, amountIn: units);
      if (mounted) setState(() => _quote = quote);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Step 2: sign exactly the reviewed trade.
  Future<void> _confirm(SwapQuote quote) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(dreamActionsProvider).executeSwap(quote);
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      Navigator.of(context).pop(true);
    } catch (e) {
      // A stale quote (blockhash expired, price moved) needs a fresh review.
      if (mounted) {
        setState(() {
          _quote = null;
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dc = context.dreamColors;
    final symbol = widget.dream.coin?.symbol ?? '';
    final solBalance = ref.watch(solBalanceProvider).value ?? 0;
    final coinBalance = widget.dream.coin == null
        ? BigInt.zero
        : ref.watch(coinBalanceProvider(widget.dream.coin!.mint)).value ??
              BigInt.zero;

    // Leave a little SOL behind for fees and token-account rent.
    final maxBuy = BigInt.from(
      ((solBalance - 0.01).clamp(0, double.infinity) * _lamportsPerSol).floor(),
    );
    final coinDisplay =
        coinBalance / BigInt.from(10).pow(_coinDecimals); // double

    return DreamSheetScaffold(
      title: widget.buy ? 'Buy \$$symbol' : 'Sell \$$symbol',
      subtitle: widget.buy
          ? 'Most of the trading fee goes to the person behind this dream.'
          : 'You’ll receive SOL. Trading fees still support the dream.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AmountField(
            controller: _amount,
            suffix: widget.buy ? 'SOL' : symbol,
            decimals: widget.buy ? 4 : _coinDecimals,
            errorText: _error,
          ),
          Text(
            widget.buy
                ? 'Balance: ${solBalance.toStringAsFixed(4)} SOL'
                : 'Balance: ${coinDisplay.toStringAsFixed(2)} $symbol',
            style: TextStyle(color: dc.muted, fontSize: 12.sp),
          ),
          SizedBox(height: 12.h),
          if (widget.buy)
            _QuickAmounts(
              values: const ['0.05', '0.1', '0.5', '1'],
              label: (v) => '$v SOL',
              onPick: (v) => setState(() => _amount.text = v),
            )
          else
            _QuickAmounts(
              values: const ['25', '50', '100'],
              label: (v) => '$v%',
              onPick: (v) {
                final part = coinBalance * BigInt.parse(v) ~/ BigInt.from(100);
                final whole = part ~/ BigInt.from(10).pow(_coinDecimals);
                final frac = (part % BigInt.from(10).pow(_coinDecimals))
                    .toString()
                    .padLeft(_coinDecimals, '0');
                setState(() => _amount.text = '$whole.$frac');
              },
            ),
          if (_quote != null) ...[
            SizedBox(height: 16.h),
            _QuoteSummary(
              receiveLabel: widget.buy ? symbol : 'SOL',
              expected: _formatUnits(
                _quote!.expectedOut,
                widget.buy ? _coinDecimals : 9,
                shown: widget.buy ? 2 : 4,
              ),
              minimum: _formatUnits(
                _quote!.minimumOut,
                widget.buy ? _coinDecimals : 9,
                shown: widget.buy ? 2 : 4,
              ),
              slippagePercent: _quote!.slippageBps / 100,
            ),
          ],
          SizedBox(height: 20.h),
          DreamPrimaryButton(
            label: _quote == null
                ? 'Review'
                : (widget.buy ? 'Confirm buy' : 'Confirm sell'),
            isLoading: _busy,
            onPressed: _busy
                ? null
                : _quote == null
                ? () => _review(max: widget.buy ? maxBuy : coinBalance)
                : () => _confirm(_quote!),
          ),
        ],
      ),
    );
  }
}

class _QuoteSummary extends StatelessWidget {
  final String receiveLabel;
  final String expected;
  final String minimum;
  final double slippagePercent;
  const _QuoteSummary({
    required this.receiveLabel,
    required this.expected,
    required this.minimum,
    required this.slippagePercent,
  });

  @override
  Widget build(BuildContext context) {
    final dc = context.dreamColors;
    Widget row(String k, String v, {bool strong = false}) => Padding(
      padding: EdgeInsets.symmetric(vertical: 3.h),
      child: Row(
        children: [
          Text(
            k,
            style: TextStyle(color: dc.muted, fontSize: 13.sp),
          ),
          const Spacer(),
          Text(
            v,
            style: TextStyle(
              color: dc.onSurface,
              fontSize: 13.sp,
              fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: dc.surfaceVariant,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          row('You’ll get about', '$expected $receiveLabel', strong: true),
          row('At least', '$minimum $receiveLabel'),
          row('Max price movement', '${slippagePercent.toStringAsFixed(1)}%'),
        ],
      ),
    );
  }
}
