import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/providers/auth/client_auth_provider.dart';
import '../../../../core/providers/wallet/wallet_balance_provider.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../shared/services/storage_service.dart';
import '../../../account/presentation/widgets/deposit_phoenix_collateral_sheet.dart';
import '../../../../core/theme/dream_colors.dart';

class WalletDepositListener extends ConsumerStatefulWidget {
  const WalletDepositListener({super.key});

  @override
  ConsumerState<WalletDepositListener> createState() =>
      _WalletDepositListenerState();
}

class _WalletDepositListenerState extends ConsumerState<WalletDepositListener> {
  bool _handling = false;
  bool _promptOpen = false;

  static const _threshold = 0.000001;

  @override
  Widget build(BuildContext context) {
    final walletAddress = ref.watch(
      clientAuthProvider.select((state) => state.walletAddress),
    );

    if (walletAddress == null) return const SizedBox.shrink();

    ref.listen<AsyncValue<double>>(walletUsdcBalanceProvider(walletAddress), (
      _,
      next,
    ) {
      next.whenData((balance) => _handleBalance(walletAddress, balance));
    });

    return const SizedBox.shrink();
  }

  Future<void> _handleBalance(String walletAddress, double balance) async {
    if (_handling || !mounted || balance.isNaN || balance.isInfinite) return;
    _handling = true;

    try {
      final initializedKey = _initializedKey(walletAddress);
      final lastSeenKey = _lastSeenKey(walletAddress);
      final initialized = StorageService.getBool(initializedKey);

      if (!initialized) {
        await StorageService.setDouble(lastSeenKey, balance);
        await StorageService.setBool(initializedKey, true);
        return;
      }

      final lastSeen = StorageService.getDouble(lastSeenKey);
      final delta = balance - lastSeen;
      if (delta <= _threshold) {
        if ((lastSeen - balance) > _threshold) {
          await StorageService.setDouble(lastSeenKey, balance);
        }
        return;
      }

      await StorageService.setDouble(lastSeenKey, balance);
      await ref
          .read(notificationServiceProvider)
          .showWalletDepositNotification(amountUsdc: delta);

      if (!mounted || _promptOpen) return;
      _promptOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          _promptOpen = false;
          return;
        }
        _showDepositPrompt(
          walletAddress: walletAddress,
          receivedAmount: delta,
          walletBalance: balance,
        );
      });
    } finally {
      _handling = false;
    }
  }

  Future<void> _showDepositPrompt({
    required String walletAddress,
    required double receivedAmount,
    required double walletBalance,
  }) async {
    final shouldDeposit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.dreamColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Text(
          'USDC received',
          style: TextStyle(
            color: context.dreamColors.onSurface,
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          '${formatUsdc(receivedAmount)} arrived in your Dream wallet. Convert it to Phoenix collateral now?',
          style: TextStyle(
            color: context.dreamColors.muted,
            fontSize: 13.sp,
            height: 1.35,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Deposit'),
          ),
        ],
      ),
    );

    _promptOpen = false;
    if (shouldDeposit == true && mounted) {
      await DepositPhoenixCollateralSheet.show(
        context,
        walletAddress: walletAddress,
        initialAmountUsdc: walletBalance,
      );
    }
  }

  String _initializedKey(String walletAddress) {
    return 'wallet_usdc_seen_initialized_$walletAddress';
  }

  String _lastSeenKey(String walletAddress) {
    return 'wallet_usdc_last_seen_$walletAddress';
  }
}
