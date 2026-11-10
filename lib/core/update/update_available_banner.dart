import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cloud/cloud_providers.dart';
import '../cloud/cloud_runtime_config.dart';
import '../theme/app_colors.dart';
import '../theme/app_layout.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_release.dart';
import 'app_update_providers.dart';
import 'update_actions_row.dart';

/// Banner cuando hay una versión más nueva en GitHub (metadatos en Supabase).
class UpdateAvailableBanner extends ConsumerWidget {
  const UpdateAvailableBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!CloudRuntimeConfig.isActive) return const SizedBox.shrink();

    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final update = ref.watch(appUpdateProvider);
    final palette = context.palette;

    // Mac: se actualiza sola. Solo se dice cuando ya está lista, en una
    // línea; si no se pudo preparar, sale el aviso de siempre.
    if (!kIsWeb && Platform.isMacOS && update.prepareError == null) {
      final staged = update.staged;
      if (staged == null) return const SizedBox.shrink();
      return Material(
        color: palette.accent.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            children: [
              Icon(Icons.download_done, size: 16, color: palette.accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'IRIS ${staged.version} está lista: se instalará sola '
                  'al cerrar la app.',
                  style: AppTypography.caption(palette),
                ),
              ),
              TextButton(
                onPressed: () =>
                    ref.read(appUpdateProvider.notifier).restartNow(null),
                child: const Text('Reiniciar ahora'),
              ),
            ],
          ),
        ),
      );
    }

    final release = update.availableRelease;
    if (release == null) return const SizedBox.shrink();

    return UpdateAvailableCard(
      release: release,
      actions: UpdateActionsRow(release: release),
    );
  }
}

/// El aviso de versión nueva. Por debajo de [_sideBySideMinWidth] los botones
/// van debajo del texto: al lado le dejaban al texto una letra de ancho.
class UpdateAvailableCard extends StatelessWidget {
  final AppRelease release;
  final Widget actions;

  const UpdateAvailableCard({
    super.key,
    required this.release,
    required this.actions,
  });

  static const double _sideBySideMinWidth = 760;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nueva versión ${release.version} disponible',
          style: AppTypography.titleMedium(palette),
        ),
        Text(
          release.releaseNotes?.isNotEmpty == true
              ? release.releaseNotes!
              : Platform.isIOS
              ? 'El Mac la instala por ti. '
                    'Tus proyectos siguen en la nube.'
              : 'Descarga e instala la actualización. '
                    'Tus proyectos siguen en la nube.',
          style: AppTypography.caption(
            palette,
          ).copyWith(color: palette.textSecondary),
        ),
      ],
    );
    return Material(
      color: palette.accent.withValues(alpha: 0.12),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppLayout.gutter(context, regular: AppSpacing.xl),
          vertical: AppSpacing.md,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final sideBySide = constraints.maxWidth >= _sideBySideMinWidth;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.system_update_alt, color: palette.accent),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: sideBySide
                      ? text
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            text,
                            const SizedBox(height: AppSpacing.sm),
                            actions,
                          ],
                        ),
                ),
                if (sideBySide) ...[
                  const SizedBox(width: AppSpacing.md),
                  // Con límite de ancho, para que el Wrap pueda saltar de línea.
                  Flexible(child: actions),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
