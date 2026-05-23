import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

export 'error_utils.dart';

/// Enhanced error widget with retry functionality
class EnhancedErrorWidget extends StatelessWidget {
  final String? title;
  final String? message;
  final VoidCallback? onRetry;
  final Widget? icon;
  final bool showRetryButton;
  final String? retryButtonText;

  const EnhancedErrorWidget({
    super.key,
    this.title,
    this.message,
    this.onRetry,
    this.icon,
    this.showRetryButton = true,
    this.retryButtonText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(50),
                ),
                child:
                    icon ??
                    Icon(PhosphorIcons.warning(), size: 48, color: Colors.red),
              )
              .animate()
              .scale(delay: 200.ms, duration: 600.ms)
              .shake(delay: 800.ms),
          const SizedBox(height: 20),
          Text(
                title ?? 'Oops! Something went wrong',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              )
              .animate()
              .fadeIn(delay: 400.ms, duration: 600.ms)
              .slideY(begin: 0.3, end: 0),
          const SizedBox(height: 12),
          Text(
                message ??
                    'We encountered an unexpected error. Please try again.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              )
              .animate()
              .fadeIn(delay: 600.ms, duration: 600.ms)
              .slideY(begin: 0.3, end: 0),
          if (showRetryButton && onRetry != null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: Icon(PhosphorIcons.arrowClockwise()),
                  label: Text(retryButtonText ?? 'Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                )
                .animate()
                .fadeIn(delay: 800.ms, duration: 600.ms)
                .slideY(begin: 0.3, end: 0),
          ],
        ],
      ),
    );
  }
}

/// Network error widget
class NetworkErrorWidget extends StatelessWidget {
  final VoidCallback? onRetry;

  const NetworkErrorWidget({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return EnhancedErrorWidget(
      title: 'No Internet Connection',
      message: 'Please check your internet connection and try again.',
      icon: Icon(PhosphorIcons.wifiSlash(), size: 48, color: Colors.orange),
      onRetry: onRetry,
      retryButtonText: 'Retry Connection',
    );
  }
}

/// Server error widget
class ServerErrorWidget extends StatelessWidget {
  final VoidCallback? onRetry;

  const ServerErrorWidget({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return EnhancedErrorWidget(
      title: 'Server Error',
      message: 'Our servers are experiencing issues. Please try again later.',
      icon: Icon(PhosphorIcons.database(), size: 48, color: Colors.red),
      onRetry: onRetry,
      retryButtonText: 'Retry Request',
    );
  }
}

/// Empty state widget
class EmptyStateWidget extends StatelessWidget {
  final String? title;
  final String? message;
  final Widget? icon;
  final Widget? action;

  const EmptyStateWidget({
    super.key,
    this.title,
    this.message,
    this.icon,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(50),
            ),
            child:
                icon ??
                Icon(PhosphorIcons.fileX(), size: 48, color: Colors.grey[500]),
          ).animate().scale(
            delay: 200.ms,
            duration: 800.ms,
            curve: Curves.elasticOut,
          ),
          const SizedBox(height: 20),
          Text(
                title ?? 'Nothing here yet',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              )
              .animate()
              .fadeIn(delay: 400.ms, duration: 600.ms)
              .slideY(begin: 0.3, end: 0),
          const SizedBox(height: 12),
          Text(
                message ??
                    "We'll show content here when it becomes available.",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              )
              .animate()
              .fadeIn(delay: 600.ms, duration: 600.ms)
              .slideY(begin: 0.3, end: 0),
          if (action != null) ...[
            const SizedBox(height: 24),
            action!
                .animate()
                .fadeIn(delay: 800.ms, duration: 600.ms)
                .slideY(begin: 0.3, end: 0),
          ],
        ],
      ),
    );
  }
}

/// Loading state with optional message
class LoadingStateWidget extends StatelessWidget {
  final String? message;
  final Widget? customLoader;

  const LoadingStateWidget({super.key, this.message, this.customLoader});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          (customLoader ??
                  CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Theme.of(context).colorScheme.primary,
                  ))
              .animate(onPlay: (controller) => controller.repeat())
              .rotate(duration: 2000.ms),
          if (message != null) ...[
            const SizedBox(height: 20),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 200.ms, duration: 600.ms),
          ],
        ],
      ),
    );
  }
}
