import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cloud/cloud_providers.dart';
import '../../core/cloud/cloud_session.dart';
import '../../core/cloud/supabase_config.dart';
import '../../core/database/database_provider.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';

/// Asistente para subir proyectos locales existentes a la nube.
class CloudMigrationWizard extends ConsumerStatefulWidget {
  final VoidCallback onComplete;
  final VoidCallback onSkip;

  const CloudMigrationWizard({
    super.key,
    required this.onComplete,
    required this.onSkip,
  });

  @override
  ConsumerState<CloudMigrationWizard> createState() =>
      _CloudMigrationWizardState();
}

class _CloudMigrationWizardState extends ConsumerState<CloudMigrationWizard> {
  var _running = false;
  String? _status;
  SyncResult? _result;

  Future<void> _migrate() async {
    if (!SupabaseConfig.isConfigured) {
      widget.onSkip();
      return;
    }

    setState(() {
      _running = true;
      _status = 'Subiendo proyectos…';
    });

    try {
      final result = await ref.read(syncEngineProvider).syncApplyDefaults();
      await CloudSessionStore.setMigrationComplete(true);
      if (mounted) {
        setState(() {
          _result = result;
          _status = 'Migración completada';
          _running = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Error: $e';
          _running = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Subir a la nube',
                    style: AppTypography.titleLarge(palette),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Detectamos proyectos en tu carpeta local. '
                    '¿Quieres sincronizarlos con tu cuenta IRIS DP?',
                    style: AppTypography.bodyMedium(palette).copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (_running)
                    const LinearProgressIndicator()
                  else if (_result != null) ...[
                    Text('Proyectos subidos: ${_result!.pushed}'),
                    Text('Proyectos descargados: ${_result!.pulled}'),
                    Text('Imágenes sync: ${_result!.mediaSynced}'),
                  ] else
                    FutureBuilder(
                      future: ref.read(databaseProvider).watchProjects().first,
                      builder: (context, snap) {
                        final count = snap.data?.length ?? 0;
                        return Text(
                          '$count proyecto(s) en cache local',
                          style: AppTypography.caption(palette),
                        );
                      },
                    ),
                  if (_status != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(_status!, style: AppTypography.caption(palette)),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: _running
                        ? 'Migrando…'
                        : (_result != null ? 'Continuar' : 'Subir a la nube'),
                    icon: Icons.cloud_upload_outlined,
                    onTap: _running
                        ? null
                        : (_result != null
                            ? widget.onComplete
                            : _migrate),
                  ),
                  TextButton(
                    onPressed: _running ? null : widget.onSkip,
                    child: const Text('Omitir por ahora'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
