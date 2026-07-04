import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';

class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double blur;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.blur = 40,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ClipRRect(
      borderRadius: AppRadius.large,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: AppRadius.large,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                palette.glassHighlight,
                palette.glassHighlight.withValues(alpha: 0.35),
              ],
            ),
            border: Border.all(
              color: palette.border.withValues(alpha: 0.45),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: palette.glassShadow,
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ),
    );
  }
}
