import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'error_widgets.dart';

/// Generic async value widget — handles loading/error/data states uniformly.
class AsyncValueWidget<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final Widget Function(Object error, StackTrace? stackTrace)? error;
  final Widget? loading;
  final bool showErrorDetails;

  const AsyncValueWidget({
    super.key,
    required this.value,
    required this.data,
    this.error,
    this.loading,
    this.showErrorDetails = false,
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: data,
      error: (err, stack) =>
          error?.call(err, stack) ?? _buildDefaultError(context, err, stack),
      loading: () => loading ?? _buildDefaultLoading(),
    );
  }

  Widget _buildDefaultError(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) {
    String errorMessage = error.toString();
    String? title;

    if (error.toString().toLowerCase().contains('network') ||
        error.toString().toLowerCase().contains('connection')) {
      title = 'Connection Error';
      errorMessage = 'Please check your internet connection and try again.';
    } else if (error.toString().toLowerCase().contains('timeout')) {
      title = 'Request Timeout';
      errorMessage = 'The request took too long. Please try again.';
    } else if (error.toString().toLowerCase().contains('server')) {
      title = 'Server Error';
      errorMessage =
          'Our servers are experiencing issues. Please try again later.';
    }

    return EnhancedErrorWidget(
      title: title,
      message: showErrorDetails ? error.toString() : errorMessage,
    );
  }

  Widget _buildDefaultLoading() {
    return const LoadingStateWidget(message: 'Loading...');
  }
}

/// Snackbar helpers for error, success, and info messages.
class SnackBarUtils {
  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(PhosphorIcons.warning(), color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }

  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(PhosphorIcons.checkCircle(), color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static void showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(PhosphorIcons.info(), color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
