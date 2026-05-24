import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/auth/client_auth_provider.dart';
import '../../../../core/services/phoenix/phoenix_trader_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/widgets/auth_background.dart';
import '../../../auth/presentation/widgets/login_header.dart';
import '../../providers/account_provider.dart';
import '../../../positions/providers/positions_provider.dart';

// ---------------------------------------------------------------------------
// Activation gate page — shown after login when account is not registered.
// Tries referral-code endpoint first; falls back to access-code endpoint.
// User never needs to know which type of code they have.
// ---------------------------------------------------------------------------

class ActivatePage extends ConsumerStatefulWidget {
  const ActivatePage({super.key});

  @override
  ConsumerState<ActivatePage> createState() => _ActivatePageState();
}

class _ActivatePageState extends ConsumerState<ActivatePage> {
  late final TextEditingController _codeCtrl;
  bool _loading = false;
  String? _error;
  bool _hintVisible = false;

  @override
  void initState() {
    super.initState();
    _codeCtrl = TextEditingController(text: AppConstants.dreamReferralCode);

    // One-time guard: skip immediately if already registered (race condition).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ts = ref.read(accountProvider).traderState;
      if (ts != null && ts.isRegistered && context.mounted) {
        context.go('/home');
        return;
      }
      // Delay hint fade-in so it doesn't compete with the page entrance.
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _hintVisible = true);
      });
    });
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  /// Tries referral-code endpoint first; if that fails tries access-code.
  /// Both endpoints result in a fully activated trader account.
  Future<void> _activate() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter your code to continue');
      return;
    }
    final walletAddress = ref.read(clientAuthProvider).walletAddress;
    if (walletAddress == null) {
      setState(() => _error = 'No wallet connected');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final svc = ref.read(phoenixTraderServiceProvider);

      // Try referral code first
      bool activated = false;
      try {
        await svc.activateWithReferral(walletAddress, code);
        activated = true;
      } catch (_) {
        // Not a referral code — try as an access / invite code
      }

      if (!activated) {
        await svc.activateAccount(walletAddress, code);
      }

      if (mounted) {
        await ref.read(accountProvider.notifier).refresh();
        await ref.read(positionsProvider.notifier).refresh();
        if (mounted) context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error =
              'Invalid code. Double-check your referral or access code.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    await ref.read(clientAuthProvider.notifier).signOut();
    if (mounted) context.go('/enhanced-login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      resizeToAvoidBottomInset: true,
      body: AuthBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(24.w, 32.h, 24.w, 32.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LoginHeader(showCopy: false),
                SizedBox(height: 36.h),

                Text(
                  'Activate Your\nAccount',
                  style: TextStyle(
                    color: AppColors.textPrimaryDark,
                    fontSize: 30.sp,
                    fontWeight: FontWeight.w800,
                    height: 1.12,
                  ),
                ),
                SizedBox(height: 10.h),
                Text(
                  'Phoenix Trade is invite-only for now. Enter your referral or access code below.',
                  style: TextStyle(
                    color: AppColors.textSecondaryDark,
                    fontSize: 14.sp,
                    height: 1.55,
                  ),
                ),
                SizedBox(height: 28.h),

                // Code input
                TextField(
                  controller: _codeCtrl,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.characters,
                  style: TextStyle(
                    color: AppColors.textPrimaryDark,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter your code',
                    hintStyle: TextStyle(
                      color: AppColors.textMutedDark,
                      fontSize: 14.sp,
                      letterSpacing: 0,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceDark,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 14.h,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.r),
                      borderSide: BorderSide(color: AppColors.borderDark),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.r),
                      borderSide: BorderSide(color: AppColors.borderDark),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.r),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                    errorText: _error,
                    errorStyle: TextStyle(
                      color: AppColors.bearish,
                      fontSize: 12.sp,
                    ),
                  ),
                  onSubmitted: (_) => _activate(),
                ),

                SizedBox(height: 8.h),

                // Inline hint — fades in after a short delay, no container
                AnimatedOpacity(
                  opacity: _hintVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 400),
                  child: Text(
                    'Search "Phoenix referral" on X or Discord if you need a code.',
                    style: TextStyle(
                      color: AppColors.textMutedDark,
                      fontSize: 11.sp,
                      height: 1.4,
                    ),
                  ),
                ),

                SizedBox(height: 24.h),

                // Activate button
                SizedBox(
                  width: double.infinity,
                  height: 52.h,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _activate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: AppColors.primary.withValues(
                        alpha: 0.3,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Activate Account',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),

                SizedBox(height: 20.h),

                Center(
                  child: TextButton(
                    onPressed: _loading ? null : _signOut,
                    child: Text(
                      'Sign out',
                      style: TextStyle(
                        color: AppColors.textSecondaryDark,
                        fontSize: 13.sp,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
