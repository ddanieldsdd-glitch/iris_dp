import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_button.dart';
import 'sidestore_guide_sheet.dart';
import 'sidestore_install_store.dart';

/// Aviso en iPad cuando la firma SideStore puede estar próxima a caducar.
class SideStoreReminderBanner extends StatefulWidget {
  const SideStoreReminderBanner({super.key});

  @override
  State<SideStoreReminderBanner> createState() => _SideStoreReminderBannerState();
}

class _SideStoreReminderBannerState extends State<SideStoreReminderBanner> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!Platform.isIOS) return;
    final show = await SideStoreInstallStore.shouldShowRefreshReminder();
    if (mounted) setState(() => _visible = show);
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isIOS || !_visible) return const SizedBox.shrink();

    final palette = context.palette;

    return Material(
      color: palette.warning.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.schedule, color: palette.warning),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Refresca SideStore pronto',
                    style: AppTypography.titleMedium(palette),
                  ),
                  Text(
                    'La firma gratuita dura ~7 días. Abre SideStore en Wi‑Fi '
                    'para evitar que IRIS DP deje de abrir.',
                    style: AppTypography.caption(palette).copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            AppButton(
              label: 'Guía',
              variant: AppButtonVariant.secondary,
              onTap: () => SideStoreGuideSheet.show(context),
            ),
          ],
        ),
      ),
    );
  }
}
