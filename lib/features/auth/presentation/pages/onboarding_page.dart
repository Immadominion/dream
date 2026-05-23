import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/services/storage_service.dart';

/// Notifier for onboarding page index (Riverpod 3.x)
class OnboardingPageNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setPage(int page) => state = page;
}

/// Provider for onboarding page index
final onboardingPageProvider = NotifierProvider<OnboardingPageNotifier, int>(
  OnboardingPageNotifier.new,
);

/// Onboarding flow with multi-step introduction and Lottie animations
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  late PageController _pageController;

  final List<OnboardingStep> _steps = [
    OnboardingStep(
      title: 'Perpetual Futures\non Solana',
      subtitle:
          'Trade BTC, ETH, SOL and more with\nup to 20× leverage. No expiry, no KYC.',
      icon: Icons.candlestick_chart_outlined,
      backgroundColor: const Color(0xFF6366F1),
    ),
    OnboardingStep(
      title: 'Long & Short\nAny Market',
      subtitle:
          'Open isolated positions, set TP/SL,\nand manage risk with precision.',
      icon: Icons.swap_vert_circle_outlined,
      backgroundColor: const Color(0xFF6366F1),
    ),
    OnboardingStep(
      title: 'Your Keys,\nYour Collateral',
      subtitle:
          'Powered by Privy. Your USDC stays\non-chain — non-custodial, always.',
      icon: Icons.lock_outline_rounded,
      backgroundColor: const Color(0xFF6366F1),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentPage = ref.watch(onboardingPageProvider);
    final currentStep = _steps[currentPage];

    return Scaffold(
      backgroundColor: currentStep.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextButton(
                  onPressed: _completeOnboarding,
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),

            // Page content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _steps.length,
                onPageChanged: (index) {
                  ref.read(onboardingPageProvider.notifier).setPage(index);
                },
                itemBuilder: (context, index) {
                  return _buildOnboardingStep(_steps[index], index);
                },
              ),
            ),

            // Bottom section with indicators and buttons
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Page indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _steps.length,
                      (index) => _buildPageIndicator(index == currentPage),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Navigation buttons
                  Row(
                    children: [
                      if (currentPage > 0)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _previousPage,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(
                                color: Colors.white,
                                width: 2,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25.r),
                              ),
                            ),
                            child: const Text(
                              'Back',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                      if (currentPage > 0) const SizedBox(width: 16),

                      Expanded(
                        child: ElevatedButton(
                          onPressed: currentPage == _steps.length - 1
                              ? _completeOnboarding
                              : _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: currentStep.backgroundColor,
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25.r),
                            ),
                          ),
                          child: Text(
                            currentPage == _steps.length - 1
                                ? 'Get Started'
                                : 'Next',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnboardingStep(OnboardingStep step, int index) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon illustration
          Container(
                width: 120.w,
                height: 120.w,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(step.icon, size: 56.sp, color: Colors.white),
              )
              .animate()
              .scale(
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
              )
              .fadeIn(duration: const Duration(milliseconds: 400)),

          SizedBox(height: 48.h),

          Text(
                step.title,
                style: TextStyle(
                  fontSize: 28.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              )
              .animate()
              .fadeIn(
                duration: const Duration(milliseconds: 800),
                delay: const Duration(milliseconds: 200),
              )
              .slideY(
                begin: 0.2,
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
              ),

          SizedBox(height: 12.h),

          Text(
                step.subtitle,
                style: TextStyle(
                  fontSize: 15.sp,
                  color: Colors.white.withOpacity(0.85),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              )
              .animate()
              .fadeIn(
                duration: const Duration(milliseconds: 800),
                delay: const Duration(milliseconds: 400),
              )
              .slideY(
                begin: 0.2,
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
              ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 8,
      width: isActive ? 32 : 8,
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  void _nextPage() {
    if (_pageController.hasClients) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_pageController.hasClients) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeOnboarding() async {
    // Mark onboarding as completed
    await StorageService.setFirstLaunchComplete();

    // Navigate to login screen
    if (mounted) {
      context.go('/enhanced-login');
    }
  }
}

/// Data model for onboarding steps
class OnboardingStep {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color backgroundColor;

  const OnboardingStep({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.backgroundColor,
  });
}
