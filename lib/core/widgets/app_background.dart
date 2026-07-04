import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Fondo cinematográfico con gradientes ambientales estilo Apple TV.
class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(color: palette.background),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -120,
            right: -80,
            child: _AmbientOrb(
              size: 480,
              colors: [
                palette.ambientBlue.withValues(alpha: isDark ? 0.55 : 0.7),
                palette.ambientBlue.withValues(alpha: 0),
              ],
            ),
          ),
          Positioned(
            bottom: -100,
            left: -60,
            child: _AmbientOrb(
              size: 420,
              colors: [
                palette.ambientIndigo.withValues(alpha: isDark ? 0.45 : 0.6),
                palette.ambientIndigo.withValues(alpha: 0),
              ],
            ),
          ),
          Positioned(
            top: 200,
            left: 120,
            child: _AmbientOrb(
              size: 280,
              colors: [
                palette.ambientWarm.withValues(alpha: isDark ? 0.2 : 0.45),
                palette.ambientWarm.withValues(alpha: 0),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _AmbientOrb extends StatelessWidget {
  final double size;
  final List<Color> colors;

  const _AmbientOrb({required this.size, required this.colors});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: colors),
        ),
      ),
    );
  }
}
