import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Snackbars legibles sobre fondo oscuro/claro de la app.
class AppSnackBar {
  AppSnackBar._();

  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    bool isError = false,
  }) {
    final palette = context.palette;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: AppTypography.snackBar(palette),
        ),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        backgroundColor: palette.surfaceOverlay,
        elevation: 6,
        margin: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.medium,
          side: BorderSide(
            color: isError
                ? palette.error.withValues(alpha: 0.55)
                : palette.borderBright,
            width: isError ? 1.2 : 1,
          ),
        ),
      ),
    );
  }

  static void showError(BuildContext context, String message) =>
      show(context, message, isError: true);
}
