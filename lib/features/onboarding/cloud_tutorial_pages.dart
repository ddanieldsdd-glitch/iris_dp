import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/cloud/supabase_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'cloud_connection_widgets.dart';
import 'tutorial_shell.dart';

/// Paso: Supabase ya vinculado — la app detectó las credenciales.
class CloudConnectedTutorialPage extends StatelessWidget {
  final int stepIndex;
  final int totalSteps;
  final VoidCallback? onBack;
  final VoidCallback onNext;

  const CloudConnectedTutorialPage({
    super.key,
    required this.stepIndex,
    required this.totalSteps,
    this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final host = Uri.tryParse(SupabaseConfig.url)?.host ?? SupabaseConfig.url;

    return TutorialShell(
      stepIndex: stepIndex,
      totalSteps: totalSteps,
      title: 'Nube conectada',
      onBack: onBack,
      onNext: onNext,
      nextLabel: 'Siguiente: instalar o continuar',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_done_outlined, size: 56, color: palette.success),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '¡Supabase ya está vinculado!',
            style: AppTypography.titleLarge(palette),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Has arrancado IRIS DP con las credenciales correctas. '
            'La app ya puede hablar con tu proyecto en la nube.',
            style: AppTypography.bodyMedium(palette).copyWith(
              color: palette.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const CloudConnectionStatusCard(),
          const SizedBox(height: AppSpacing.lg),
          Text('Proyecto activo', style: AppTypography.titleMedium(palette)),
          const SizedBox(height: AppSpacing.sm),
          SelectableText(
            host,
            style: AppTypography.bodyMedium(palette).copyWith(
              fontFamily: 'monospace',
              color: palette.accent,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Lo siguiente: crear tu cuenta o iniciar sesión. '
            'No hace falta pegar claves dentro de la app — eso ya está hecho.',
            style: AppTypography.bodyMedium(palette),
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
