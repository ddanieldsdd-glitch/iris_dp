import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';

class AppCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;
  final bool focused;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
    this.focused = false,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _hovered = false;

  Duration get _animDuration =>
      Platform.environment['FLUTTER_TEST'] == 'true'
          ? Duration.zero
          : const Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final elevated = _hovered || widget.focused;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: elevated ? 1.02 : 1.0,
          duration: _animDuration,
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: _animDuration,
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: AppRadius.large,
              boxShadow: elevated
                  ? [
                      BoxShadow(
                        color: palette.accentGlow.withValues(alpha: 0.35),
                        blurRadius: 32,
                        spreadRadius: -4,
                      ),
                      BoxShadow(
                        color: palette.focusGlow.withValues(alpha: 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: palette.chipShadow.withValues(alpha: 0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: ClipRRect(
              borderRadius: AppRadius.large,
              child: _maybeBlur(
                child: AnimatedContainer(
                  duration: _animDuration,
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.large,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        (widget.color ?? palette.surfaceElevated)
                            .withValues(alpha: elevated ? 0.95 : 0.85),
                        palette.surface.withValues(alpha: elevated ? 0.9 : 0.75),
                      ],
                    ),
                    border: Border.all(
                      color: elevated
                          ? palette.border.withValues(alpha: 0.5)
                          : palette.border,
                      width: elevated ? 1 : 0.5,
                    ),
                  ),
                  padding: widget.padding ?? const EdgeInsets.all(20),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _maybeBlur({required Widget child}) {
    if (Platform.environment['FLUTTER_TEST'] == 'true') return child;
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
      child: child,
    );
  }
}
