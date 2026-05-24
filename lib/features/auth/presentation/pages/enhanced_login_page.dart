import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/auth/client_auth_provider.dart';
import '../../../../core/services/privy_sdk_service.dart';
import '../../../../shared/models/user.dart';
import '../widgets/auth_background.dart';
import '../widgets/login_email_form.dart';
import '../widgets/login_footer.dart';
import '../widgets/login_header.dart';
import '../widgets/login_social_options.dart';

/// Enhanced login page with Privy-backed authentication flows.
class EnhancedLoginPage extends ConsumerStatefulWidget {
  const EnhancedLoginPage({super.key});

  @override
  ConsumerState<EnhancedLoginPage> createState() => _EnhancedLoginPageState();
}

class _EnhancedLoginPageState extends ConsumerState<EnhancedLoginPage>
    with TickerProviderStateMixin {
  bool _isLoading = false;
  bool _showEmailForm = false;
  bool _isOtpSent = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _otpFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _emailFocusNode.addListener(_handleFocusChange);
    _otpFocusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _emailFocusNode.removeListener(_handleFocusChange);
    _otpFocusNode.removeListener(_handleFocusChange);
    _emailFocusNode.dispose();
    _otpFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthStateData>(clientAuthProvider, (previous, next) {
      if (!mounted) return;

      switch (next.state) {
        case AuthState.loading:
          setState(() => _isLoading = true);
          break;
        case AuthState.authenticated:
          setState(() => _isLoading = false);
          context.go(AppRoutes.home);
          break;
        case AuthState.error:
          setState(() => _isLoading = false);
          _showErrorSnackbar('Authentication failed. Please try again.');
          break;
        default:
          setState(() => _isLoading = false);
          break;
      }
    });

    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          FocusManager.instance.primaryFocus?.unfocus();
          _scrollToStart();
        },
        child: AuthBackground(
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final mediaQuery = MediaQuery.of(context);
                final viewInsets = mediaQuery.viewInsets.bottom;
                final safeBottom = mediaQuery.padding.bottom;
                final keyboardInset = (viewInsets - safeBottom).clamp(
                  0.0,
                  double.infinity,
                );
                final isKeyboardVisible = keyboardInset > 0;
                // Reduce header gap on Android to accommodate Connect Wallet button
                // Also reduce when email form is shown for better balance
                final baseHeaderGap = Platform.isAndroid && !_showEmailForm
                    ? 180.h
                    : 220.h;
                final adjustedHeaderGap =
                    (baseHeaderGap - (isKeyboardVisible ? 90.h : 0)).clamp(
                      60.h,
                      baseHeaderGap,
                    );

                return Stack(
                  children: [
                    Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            physics: const ClampingScrollPhysics(),
                            padding: EdgeInsets.only(
                              left: 24.w,
                              right: 24.w,
                              top: 24.h,
                              bottom:
                                  24.h +
                                  safeBottom +
                                  (isKeyboardVisible ? 12.h : 0),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(height: adjustedHeaderGap.toDouble()),
                                LoginHeader(showCopy: !_showEmailForm),
                                SizedBox(height: 32.h),
                                IndexedStack(
                                  index: _showEmailForm ? 1 : 0,
                                  children: [
                                    LoginSocialOptions(
                                      isLoading: _isLoading,
                                      onEmailSelected: _handleEmailSelected,
                                      onSocialSelected: (provider) =>
                                          _handlePrivySocialLogin(provider),
                                      onWalletSelected: _handleWalletConnect,
                                    ),
                                    LoginEmailForm(
                                      isLoading: _isLoading,
                                      isOtpSent: _isOtpSent,
                                      emailController: _emailController,
                                      otpController: _otpController,
                                      emailFocusNode: _emailFocusNode,
                                      otpFocusNode: _otpFocusNode,
                                      onSendOtp: () => _handleRequestOtp(),
                                      onVerifyOtp: () => _handleVerifyOtp(),
                                      onResendOtp: () => _handleRequestOtp(),
                                      onBackToOptions: _handleBackToOptions,
                                    ),
                                  ],
                                ),
                                SizedBox(height: 24.h),
                              ],
                            ),
                          ),
                        ),
                        if (!_showEmailForm)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                            padding: EdgeInsets.fromLTRB(
                              24.w,
                              0,
                              24.w,
                              24.h + safeBottom + keyboardInset,
                            ),
                            child: const LoginFooter(),
                          ),
                      ],
                    ),
                    // Full-screen overlay only for OAuth/wallet flows, not email OTP
                    // (email form has an inline button spinner)
                    if (_isLoading && !_showEmailForm)
                      Container(
                        color: Colors.black.withValues(alpha: 0.25),
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleRequestOtp() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showErrorSnackbar('Please enter your email');
      return;
    }

    if (!_isValidEmail(email)) {
      _showErrorSnackbar('Please enter a valid email address');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(clientAuthProvider.notifier).requestEmailOtp(email);
      if (!mounted) return;
      setState(() => _isOtpSent = true);
      _otpFocusNode.requestFocus();
      Future.delayed(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        _ensureVisible(_otpFocusNode, alignment: 0.2);
      });
      _showInfoSnackbar('Verification code sent to $email');
    } catch (_) {
      _showErrorSnackbar('Failed to send code. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleVerifyOtp() async {
    final otp = _otpController.text.trim();
    final email = _emailController.text.trim();

    if (otp.length != 6) {
      _showErrorSnackbar('Please enter the six-digit code.');
      _ensureVisible(_otpFocusNode);
      return;
    }

    try {
      await ref.read(clientAuthProvider.notifier).verifyEmailOtp(email, otp);
    } catch (_) {
      _showErrorSnackbar('Verification failed. Please try again.');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleEmailSelected() {
    setState(() {
      _showEmailForm = true;
      _isOtpSent = false;
      _otpController.clear();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FocusScope.of(context).requestFocus(_emailFocusNode);
      // Give the keyboard time to animate in
      Future.delayed(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        _ensureVisible(_emailFocusNode, alignment: 0.2);
      });
    });
  }

  void _handleBackToOptions() {
    FocusScope.of(context).unfocus();
    setState(() {
      _showEmailForm = false;
      _isOtpSent = false;
      _emailController.clear();
      _otpController.clear();
    });
    _scrollToStart();
  }

  Future<void> _handlePrivySocialLogin(LoginMethod method) async {
    try {
      await ref.read(clientAuthProvider.notifier).signInWithOAuth(method);
    } catch (_) {
      _showErrorSnackbar('We could not complete that login. Please retry.');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleWalletConnect() async {
    try {
      await ref.read(clientAuthProvider.notifier).signInWithWallet();
    } catch (_) {
      _showErrorSnackbar('Wallet connection failed. Please try again.');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showInfoSnackbar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _handleFocusChange() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (_emailFocusNode.hasFocus) {
        _ensureVisible(_emailFocusNode, alignment: 0.2);
      } else if (_otpFocusNode.hasFocus) {
        _ensureVisible(_otpFocusNode, alignment: 0.2);
      } else {
        _scrollToStart();
      }
    });
  }

  void _ensureVisible(FocusNode node, {double alignment = 0.2}) {
    final focusContext = node.context;
    if (focusContext == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      Scrollable.ensureVisible(
        focusContext,
        duration: const Duration(milliseconds: 250),
        alignment: alignment,
        curve: Curves.easeOut,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );
    });
  }

  void _scrollToStart() {
    if (!_scrollController.hasClients) return;
    _animateScroll(_scrollController.position.minScrollExtent);
  }

  void _animateScroll(double offset) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final target = offset.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }
}
