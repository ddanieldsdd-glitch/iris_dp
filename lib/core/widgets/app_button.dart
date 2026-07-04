import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_radius.dart';

enum AppButtonVariant { primary, secondary, ghost, destructive }

class AppButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool loading;

  const AppButton({
    super.key,
    required this.label,
    this.onTap,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.loading = false,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    final bg = switch (widget.variant) {
      AppButtonVariant.primary => palette.accent,
      AppButtonVariant.secondary => palette.surfaceOverlay.withValues(alpha: 0.55),
      AppButtonVariant.ghost => Colors.transparent,
      AppButtonVariant.destructive => palette.error,
    };

    final fg = switch (widget.variant) {
      AppButtonVariant.primary => Colors.white,
      AppButtonVariant.secondary => palette.textPrimary,
      AppButtonVariant.ghost => palette.textSecondary,
      AppButtonVariant.destructive => Colors.white,
    };

    final glow = widget.variant == AppButtonVariant.primary && _hovered;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.loading ? null : widget.onTap,
        child: AnimatedScale(
          scale: _hovered ? 1.04 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: AppRadius.pill,
              border: widget.variant == AppButtonVariant.secondary ||
                      widget.variant == AppButtonVariant.ghost
                  ? Border.all(
                      color: palette.border.withValues(
                        alpha: _hovered ? 0.6 : 0.35,
                      ),
                    )
                  : null,
              boxShadow: glow
                  ? [
                      BoxShadow(
                        color: palette.accentGlow,
                        blurRadius: 20,
                        spreadRadius: -2,
                      ),
                    ]
                  : null,
            ),
            child: widget.loading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: fg,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, color: fg, size: 16),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.label,
                        style: AppTypography.titleMedium(palette).copyWith(color: fg),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
