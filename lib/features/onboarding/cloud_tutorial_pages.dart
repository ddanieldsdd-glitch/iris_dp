import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/cloud/cloud_link_panel.dart';
import '../../core/cloud/cloud_runtime_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'cloud_connection_widgets.dart';
import 'tutorial_shell.dart';

/// Paso: elegir vincular o desvincular Supabase al inicio.
class CloudLinkTutorialPage extends StatelessWidget {
  final int stepIndex;
  final int totalSteps;
  final VoidCallback? onBack;
  final VoidCallback onNext;
  final Future<void> Function({required bool active}) onCloudChanged;

  const CloudLinkTutorialPage({
    super.key,
    required this.stepIndex,
    required this.totalSteps,
    this.onBack,
    required this.onNext,
    required this.onCloudChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final active = CloudRuntimeConfig.isActive;
    final host = Uri.tryParse(CloudRuntimeConfig.url)?.host;

    return TutorialShell(
      stepIndex: stepIndex,
      totalSteps: totalSteps,
      title: 'Nube Supabase',
      onBack: onBack,
      onNext: onNext,
      nextLabel: active
          ? 'Siguiente: instalar o continuar'
          : 'Continuar sin nube',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            active ? Icons.cloud_done_outlined : Icons.cloud_outlined,
            size: 56,
            color: active ? palette.success : palette.accent,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            active ? 'Nube vinculada' : '¿Usar la nube?',
            style: AppTypography.titleLarge(palette),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            active
                ? 'Puedes seguir con Supabase o volver a modo solo local. '
                    'También puedes cambiarlo después en Ajustes.'
                : 'Con Supabase sincronizas proyectos entre Mac, Windows e iPad. '
                    'Sin nube, todo queda en este dispositivo.',
            style: AppTypography.bodyMedium(palette).copyWith(
              color: palette.textSecondary,
              height: 1.45,
            ),
          ),
          if (active && host != null && host.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            const CloudConnectionStatusCard(),
            const SizedBox(height: AppSpacing.sm),
            SelectableText(
              host,
              style: AppTypography.bodyMedium(palette).copyWith(
                fontFamily: 'monospace',
                color: palette.accent,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          CloudLinkPanel(
            promptRestart: false,
            showTitle: false,
            onCloudChanged: onCloudChanged,
          ),
        ],
      ),
    );
  }
}

/// Paso: cómo instalar IRIS DP en macOS (desarrollo vs .dmg).
class MacInstallTutorialPage extends StatelessWidget {
  final int stepIndex;
  final int totalSteps;
  final VoidCallback? onBack;
  final VoidCallback onNext;

  const MacInstallTutorialPage({
    super.key,
    required this.stepIndex,
    required this.totalSteps,
    this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onMac = Platform.isMacOS;

    return TutorialShell(
      stepIndex: stepIndex,
      totalSteps: totalSteps,
      title: 'Instalar en Mac',
      onBack: onBack,
      onNext: onNext,
      nextLabel: 'Siguiente: mi cuenta',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.laptop_mac_outlined, size: 56, color: palette.accent),
          const SizedBox(height: AppSpacing.lg),
          Text(
            onMac ? 'Estás en macOS' : 'Instalar en macOS',
            style: AppTypography.titleLarge(palette),
          ),
          const SizedBox(height: AppSpacing.md),
          if (onMac) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: palette.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Modo desarrollo (lo que usas ahora)',
                    style: AppTypography.titleMedium(palette),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'El comando flutter run abre la app pero NO la instala en '
                    'Aplicaciones. Es normal — sirve para probar mientras desarrollas.',
                    style: AppTypography.bodyMedium(palette).copyWith(
                      color: palette.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          Text(
            'Instalar como app de verdad (.dmg)',
            style: AppTypography.titleMedium(palette),
          ),
          const SizedBox(height: AppSpacing.sm),
          const TutorialNumberedSteps(
            steps: [
              'En Terminal: cd iris_dp && ./scripts/build_macos_dmg.sh',
              'Se genera IRIS-DP.dmg — ábrelo con doble clic',
              'Arrastra «IRIS DP» a la carpeta Aplicaciones',
              'Abre desde Launchpad o Aplicaciones (clic derecho → Abrir la primera vez)',
              'La app instalada debe compilarse con las mismas claves Supabase (--dart-define)',
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'En iPad u otro Mac: instala la misma versión, inicia sesión con '
            'el mismo email y pulsa el icono de nube para sincronizar.',
            style: AppTypography.bodyMedium(palette).copyWith(
              color: palette.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
