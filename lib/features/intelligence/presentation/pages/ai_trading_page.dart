import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/providers/auth/client_auth_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../models/intelligence_models.dart';
import '../../providers/ai_trading_provider.dart';
import '../widgets/bot_log_tile.dart';

class AITradingPage extends ConsumerStatefulWidget {
  const AITradingPage({super.key});

  @override
  ConsumerState<AITradingPage> createState() => _AITradingPageState();
}

class _AITradingPageState extends ConsumerState<AITradingPage> {
  bool _showConfig = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiTradingProvider);
    final isAuthenticated =
        ref.watch(clientAuthProvider).walletAddress != null;

    if (!isAuthenticated) {
      return const Center(child: _NotConnected());
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 100.h),
      children: [
        // Credits strip
        _CreditsStrip(state: state),
        SizedBox(height: 12.h),
        // Main controls
        _BotControlCard(
          state: state,
          onStart: () =>
              ref.read(aiTradingProvider.notifier).startBot(),
          onStop: () => ref.read(aiTradingProvider.notifier).stopBot(),
          onToggleConfig: () => setState(() => _showConfig = !_showConfig),
          showConfig: _showConfig,
        ),
        // Config panel
        if (_showConfig) ...[
          SizedBox(height: 10.h),
          _ConfigPanel(config: state.config),
        ],
        // Error message
        if (state.error != null) ...[
          SizedBox(height: 10.h),
          _ErrorBanner(message: state.error!),
        ],
        SizedBox(height: 20.h),
        // Log
        if (state.log.isNotEmpty) ...[
          _SectionHeader('Activity Log (last 20)'),
          SizedBox(height: 8.h),
          ...state.log.map((e) => BotLogTile(entry: e)),
        ] else if (!state.isRunning) ...[
          _EmptyLog(),
        ],
      ],
    );
  }
}

// ── Credits strip ──────────────────────────────────────────────────────────

class _CreditsStrip extends ConsumerWidget {
  final AITradingState state;
  const _CreditsStrip({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Row(
        children: [
          Icon(
            PhosphorIcons.lightning(PhosphorIconsStyle.duotone),
            color: AppColors.warning,
            size: 18.r,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.isLoadingCredits
                      ? 'Loading…'
                      : '${state.aiCredits} AI credit${state.aiCredits == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: state.aiCredits > 0
                        ? AppColors.textPrimaryDark
                        : AppColors.error,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  state.aiCredits > 0
                      ? '1 credit per bot cycle (${state.aiCredits} cycles remaining)'
                      : 'Purchase credits to run the AI bot',
                  style: TextStyle(
                    color: AppColors.textMutedDark,
                    fontSize: 10.sp,
                  ),
                ),
              ],
            ),
          ),
          _BuyCreditsButton(state: state),
        ],
      ),
    );
  }
}

class _BuyCreditsButton extends ConsumerWidget {
  final AITradingState state;
  const _BuyCreditsButton({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: state.isBuying ? null : () => _showPurchaseDialog(context, ref),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: state.isBuying
              ? AppColors.borderDark
              : AppColors.warning.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: AppColors.warning.withValues(alpha: 0.3),
          ),
        ),
        child: state.isBuying
            ? SizedBox(
                width: 14.r,
                height: 14.r,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.warning,
                ),
              )
            : Text(
                '+ Buy',
                style: TextStyle(
                  color: AppColors.warning,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  void _showPurchaseDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PurchaseSheet(
        onTierSelected: (tier) {
          Navigator.of(context).pop();
          ref.read(aiTradingProvider.notifier).purchaseCredits(tier);
        },
      ),
    );
  }
}

class _PurchaseSheet extends StatelessWidget {
  final ValueChanged<CreditTier> onTierSelected;
  const _PurchaseSheet({required this.onTierSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.r),
          topRight: Radius.circular(20.r),
        ),
        border: Border.all(color: AppColors.borderDark),
      ),
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 32.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: AppColors.borderDark,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'Purchase AI Credits',
            style: TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'SOL is sent on-chain to Dream treasury. Credits are issued automatically after confirmation.',
            style: TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 12.sp,
            ),
          ),
          SizedBox(height: 16.h),
          ...CreditTier.tiers.map(
            (tier) => _TierRow(tier: tier, onSelect: () => onTierSelected(tier)),
          ),
        ],
      ),
    );
  }
}

class _TierRow extends StatelessWidget {
  final CreditTier tier;
  final VoidCallback onSelect;

  const _TierRow({required this.tier, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect,
      child: Container(
        margin: EdgeInsets.only(bottom: 8.h),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: AppColors.borderDark),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        tier.label,
                        style: TextStyle(
                          color: AppColors.textPrimaryDark,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          '${tier.credits} credits',
                          style: TextStyle(
                            color: AppColors.primaryLight,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    '~\$${(tier.solPrice * 150).toStringAsFixed(2)} · ${tier.credits} AI cycles',
                    style: TextStyle(
                      color: AppColors.textMutedDark,
                      fontSize: 10.sp,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${tier.solPrice} SOL',
                  style: TextStyle(
                    color: AppColors.textPrimaryDark,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Icon(
                  PhosphorIcons.arrowRight(PhosphorIconsStyle.bold),
                  size: 14.r,
                  color: AppColors.textMutedDark,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bot control card ───────────────────────────────────────────────────────

class _BotControlCard extends StatelessWidget {
  final AITradingState state;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onToggleConfig;
  final bool showConfig;

  const _BotControlCard({
    required this.state,
    required this.onStart,
    required this.onStop,
    required this.onToggleConfig,
    required this.showConfig,
  });

  @override
  Widget build(BuildContext context) {
    final isRunning = state.isRunning;

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: isRunning
              ? AppColors.primary.withValues(alpha: 0.5)
              : AppColors.borderDark,
        ),
        boxShadow: isRunning
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  blurRadius: 20,
                  spreadRadius: -5,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _BotStatusIndicator(isRunning: isRunning),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Trading Bot',
                      style: TextStyle(
                        color: AppColors.textPrimaryDark,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      isRunning
                          ? 'Running · ${state.config.market}'
                          : 'Idle · ${state.config.market}',
                      style: TextStyle(
                        color: isRunning
                            ? AppColors.success
                            : AppColors.textMutedDark,
                        fontSize: 11.sp,
                      ),
                    ),
                  ],
                ),
              ),
              _ToggleConfigButton(
                onTap: onToggleConfig,
                active: showConfig,
              ),
            ],
          ),
          SizedBox(height: 14.h),
          // P&L pill
          if (state.totalPnl != 0)
            Container(
              margin: EdgeInsets.only(bottom: 12.h),
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
              decoration: BoxDecoration(
                color: (state.totalPnl >= 0 ? AppColors.bullish : AppColors.bearish)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Text(
                'Session P&L: ${state.totalPnl >= 0 ? '+' : ''}\$${state.totalPnl.toStringAsFixed(2)}',
                style: TextStyle(
                  color: state.totalPnl >= 0 ? AppColors.bullish : AppColors.bearish,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          // Start / Stop button
          SizedBox(
            width: double.infinity,
            height: 44.h,
            child: isRunning
                ? _StopButton(onTap: onStop)
                : _StartButton(
                    onTap: state.aiCredits <= 0 ? null : onStart,
                    hasCredits: state.aiCredits > 0,
                  ),
          ),
        ],
      ),
    );
  }
}

class _BotStatusIndicator extends StatelessWidget {
  final bool isRunning;
  const _BotStatusIndicator({required this.isRunning});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40.r,
      height: 40.r,
      decoration: BoxDecoration(
        color: (isRunning ? AppColors.primary : AppColors.textMutedDark)
            .withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Icon(
        isRunning
            ? PhosphorIcons.robot(PhosphorIconsStyle.duotone)
            : PhosphorIcons.robot(),
        color: isRunning ? AppColors.primary : AppColors.textMutedDark,
        size: 22.r,
      ),
    );
  }
}

class _ToggleConfigButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool active;
  const _ToggleConfigButton({required this.onTap, required this.active});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(8.r),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Icon(
          PhosphorIcons.slidersHorizontal(PhosphorIconsStyle.bold),
          color: active ? AppColors.primary : AppColors.textMutedDark,
          size: 18.r,
        ),
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool hasCredits;
  const _StartButton({this.onTap, required this.hasCredits});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor:
            hasCredits ? AppColors.primary : AppColors.borderDark,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        elevation: 0,
      ),
      icon: Icon(PhosphorIcons.play(PhosphorIconsStyle.fill), size: 16.r),
      label: Text(
        hasCredits ? 'Start Bot' : 'Buy Credits First',
        style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _StopButton extends StatelessWidget {
  final VoidCallback onTap;
  const _StopButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.error,
        side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
      icon: Icon(PhosphorIcons.stop(PhosphorIconsStyle.fill), size: 16.r),
      label: Text(
        'Stop Bot',
        style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Config panel ───────────────────────────────────────────────────────────

class _ConfigPanel extends ConsumerStatefulWidget {
  final AIBotConfig config;
  const _ConfigPanel({required this.config});

  @override
  ConsumerState<_ConfigPanel> createState() => _ConfigPanelState();
}

class _ConfigPanelState extends ConsumerState<_ConfigPanel> {
  late String _market;
  late double _maxSize;
  late double _maxLeverage;
  late RiskMode _riskMode;

  static const _markets = ['SOL-PERP', 'BTC-PERP', 'ETH-PERP'];

  @override
  void initState() {
    super.initState();
    _market = widget.config.market;
    _maxSize = widget.config.maxSizeUSDC;
    _maxLeverage = widget.config.maxLeverage;
    _riskMode = widget.config.riskMode;
  }

  void _save() {
    ref.read(aiTradingProvider.notifier).updateConfig(
      AIBotConfig(
        market: _market,
        maxSizeUSDC: _maxSize,
        maxLeverage: _maxLeverage,
        riskMode: _riskMode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ConfigRow(
            label: 'Market',
            child: DropdownButton<String>(
              value: _market,
              dropdownColor: AppColors.cardDark,
              style: TextStyle(
                color: AppColors.textPrimaryDark,
                fontSize: 13.sp,
              ),
              underline: const SizedBox.shrink(),
              items: _markets
                  .map(
                    (m) => DropdownMenuItem(
                      value: m,
                      child: Text(m),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _market = v);
                _save();
              },
            ),
          ),
          _ConfigRow(
            label: 'Max size: \$${_maxSize.toStringAsFixed(0)} USDC',
            child: Slider(
              value: _maxSize,
              min: 10,
              max: 500,
              divisions: 49,
              activeColor: AppColors.primary,
              inactiveColor: AppColors.borderDark,
              onChanged: (v) => setState(() => _maxSize = v),
              onChangeEnd: (_) => _save(),
            ),
          ),
          _ConfigRow(
            label: 'Max leverage: ${_maxLeverage.toStringAsFixed(0)}×',
            child: Slider(
              value: _maxLeverage,
              min: 1,
              max: 10,
              divisions: 9,
              activeColor: AppColors.warning,
              inactiveColor: AppColors.borderDark,
              onChanged: (v) => setState(() => _maxLeverage = v),
              onChangeEnd: (_) => _save(),
            ),
          ),
          _ConfigRow(
            label: 'Risk mode',
            child: SegmentedButton<RiskMode>(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((s) {
                  if (s.contains(WidgetState.selected)) {
                    return AppColors.primary.withValues(alpha: 0.25);
                  }
                  return Colors.transparent;
                }),
                foregroundColor: WidgetStateProperty.resolveWith((s) {
                  if (s.contains(WidgetState.selected)) {
                    return AppColors.primaryLight;
                  }
                  return AppColors.textSecondaryDark;
                }),
                side: WidgetStatePropertyAll(
                  BorderSide(color: AppColors.borderDark),
                ),
              ),
              segments: [
                ButtonSegment(
                  value: RiskMode.conservative,
                  label: Text(
                    'Safe',
                    style: TextStyle(fontSize: 10.sp),
                  ),
                ),
                ButtonSegment(
                  value: RiskMode.balanced,
                  label: Text(
                    'Balanced',
                    style: TextStyle(fontSize: 10.sp),
                  ),
                ),
                ButtonSegment(
                  value: RiskMode.aggressive,
                  label: Text(
                    'Degen',
                    style: TextStyle(fontSize: 10.sp),
                  ),
                ),
              ],
              selected: {_riskMode},
              onSelectionChanged: (v) {
                setState(() => _riskMode = v.first);
                _save();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfigRow extends StatelessWidget {
  final String label;
  final Widget child;
  const _ConfigRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 11.sp,
            ),
          ),
          SizedBox(height: 4.h),
          child,
        ],
      ),
    );
  }
}

// ── Misc ───────────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            PhosphorIcons.warningCircle(PhosphorIconsStyle.fill),
            color: AppColors.error,
            size: 16.r,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: AppColors.error,
                fontSize: 11.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: AppColors.textSecondaryDark,
        fontSize: 11.sp,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _EmptyLog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(top: 24.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PhosphorIcons.robot(PhosphorIconsStyle.duotone),
              size: 44.r,
              color: AppColors.textMutedDark,
            ),
            SizedBox(height: 14.h),
            Text(
              'Bot is idle',
              style: TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              'Start the bot to begin AI-driven trading.\nEach cycle uses 1 credit.',
              style: TextStyle(
                color: AppColors.textMutedDark,
                fontSize: 12.sp,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotConnected extends StatelessWidget {
  const _NotConnected();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          PhosphorIcons.wallet(PhosphorIconsStyle.duotone),
          size: 44.r,
          color: AppColors.textMutedDark,
        ),
        SizedBox(height: 14.h),
        Text(
          'Wallet required',
          style: TextStyle(
            color: AppColors.textSecondaryDark,
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 6.h),
        Text(
          'Connect a wallet to use AI trading.',
          style: TextStyle(
            color: AppColors.textMutedDark,
            fontSize: 12.sp,
          ),
        ),
      ],
    );
  }
}
