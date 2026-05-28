import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/services/phoenix/phoenix_trader_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/account_provider.dart';
import '../../../positions/providers/positions_provider.dart';
import '../../../../core/theme/dream_colors.dart';

// ---------------------------------------------------------------------------
// Activate trading account card
// ---------------------------------------------------------------------------

class AccountActivateCard extends ConsumerStatefulWidget {
  final String? walletAddress;
  const AccountActivateCard({super.key, required this.walletAddress});

  @override
  ConsumerState<AccountActivateCard> createState() =>
      _AccountActivateCardState();
}

class _AccountActivateCardState extends ConsumerState<AccountActivateCard> {
  // 0 = referral code (from a friend), 1 = invite/access code (allowlist)
  int _tab = 0;
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      setState(
        () => _error = _tab == 0
            ? 'Enter a referral code'
            : 'Enter an access code',
      );
      return;
    }
    final address = widget.walletAddress;
    if (address == null) {
      setState(() => _error = 'No wallet connected');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final svc = ref.read(phoenixTraderServiceProvider);
      if (_tab == 0) {
        await svc.activateWithReferral(address, code);
      } else {
        await svc.activateAccount(address, code);
      }
      if (mounted) {
        await ref.read(accountProvider.notifier).refresh();
        await ref.read(positionsProvider.notifier).refresh();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account activated! Welcome to Dream.'),
              backgroundColor: AppColors.bullish,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final msg = e
            .toString()
            .replaceAll('DioException', '')
            .replaceAll('Exception:', '')
            .trim();
        setState(() => _error = msg.isNotEmpty ? msg : 'Activation failed');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: context.dreamColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppColors.primary.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.lock_open_outlined,
                color: AppColors.primary,
                size: 20.sp,
              ),
              SizedBox(width: 8.w),
              Text(
                'Activate Trading Account',
                style: TextStyle(
                  color: context.dreamColors.onSurface,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),

          // Code type tabs
          Container(
            height: 34.h,
            decoration: BoxDecoration(
              color: context.dreamColors.surface,
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Row(
              children: [
                _CodeTab(
                  label: 'Referral Code',
                  selected: _tab == 0,
                  onTap: () => setState(() {
                    _tab = 0;
                    _error = null;
                    _codeCtrl.clear();
                  }),
                ),
                _CodeTab(
                  label: 'Access Code',
                  selected: _tab == 1,
                  onTap: () => setState(() {
                    _tab = 1;
                    _error = null;
                    _codeCtrl.clear();
                  }),
                ),
              ],
            ),
          ),
          SizedBox(height: 10.h),

          Text(
            _tab == 0
                ? 'Enter a referral code from an existing Phoenix trader.'
                : 'Enter your allowlist access code from the Phoenix team.',
            style: TextStyle(
              color: context.dreamColors.muted,
              fontSize: 12.sp,
              height: 1.5,
            ),
          ),
          SizedBox(height: 12.h),

          // Code input
          TextField(
            controller: _codeCtrl,
            autocorrect: false,
            textCapitalization: TextCapitalization.none,
            style: TextStyle(color: context.dreamColors.onSurface, fontSize: 14.sp),
            decoration: InputDecoration(
              hintText: _tab == 0 ? 'e.g. DREAM-XXXX' : 'Access code',
              hintStyle: TextStyle(
                color: context.dreamColors.mutedSecondary,
                fontSize: 13.sp,
              ),
              filled: true,
              fillColor: context.dreamColors.surface,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12.w,
                vertical: 12.h,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: BorderSide(color: context.dreamColors.stroke),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: BorderSide(color: context.dreamColors.stroke),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
              errorText: _error,
              errorStyle: TextStyle(color: AppColors.bearish, fontSize: 11.sp),
            ),
            onSubmitted: (_) => _activate(),
          ),
          SizedBox(height: 12.h),

          // Activate button
          SizedBox(
            width: double.infinity,
            height: 44.h,
            child: ElevatedButton(
              onPressed: _loading ? null : _activate,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primary.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              child: _loading
                  ? SizedBox(
                      width: 18.w,
                      height: 18.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Activate Account',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

class _CodeTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CodeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.all(3),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(4.r),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : context.dreamColors.muted,
              fontSize: 12.sp,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
