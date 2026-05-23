import 'package:flutter/material.dart';

/// Decorative background used on authentication screens.
class AuthBackground extends StatelessWidget {
  const AuthBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colorScheme.surface,
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              image: const DecorationImage(
                image: AssetImage('assets/images/dot-texture.png'),
                fit: BoxFit.cover,
              ),
              color: colorScheme.primary.withValues(alpha: 0.05),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
              ),
            ),
            child: child,
          ),
        ),
      ],
    );
  }
}
