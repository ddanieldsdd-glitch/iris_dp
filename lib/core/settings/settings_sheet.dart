import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cloud/cloud_providers.dart';
import '../cloud/cloud_session.dart';
import '../cloud/supabase_config.dart';
import '../storage/app_storage_config.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_theme_toggle.dart';
import '../update/settings_update_section.dart';
import 'settings_health_section.dart';
import 'user_templates_settings_section.dart';
import '../../features/onboarding/app_tutorial_store.dart';
import '../../features/onboarding/initial_tutorial_flow.dart';
import '../../features/onboarding/install_update_guide_screen.dart';
import '../../features/auth/auth_screen.dart';

/// Ajustes de la app.
class SettingsSheet extends ConsumerStatefulWidget {
  const SettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SettingsSheet(),
    );
  }

  @override
  ConsumerState<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<SettingsSheet> {
  String? _appDataPath;
  String? _documentsPath;

  @override
  void initState() {
    super.initState();
    final paths = AppStorageConfig.current;
    _appDataPath = paths?.appDataPath;
    _documentsPath = paths?.documentsPath;
  }

  Future<void> _pickAppData() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Datos técnicos de IRIS DP',
    );
    if (path == null || _documentsPath == null) return;
    await AppStorageConfig.save(
      StoragePaths(appDataPath: path, documentsPath: _documentsPath!),
    );
    setState(() => _appDataPath = path);
  }

  Future<void> _pickDocuments() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Documentos e imágenes del proyecto',
    );
    if (path == null || _appDataPath == null) return;
    await AppStorageConfig.save(
      StoragePaths(appDataPath: _appDataPath!, documentsPath: path),
    );
    setState(() => _documentsPath = path);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: palette.surfaceElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Ajustes', style: AppTypography.titleLarge(palette)),
              const SizedBox(height: AppSpacing.lg),
              Text('Apariencia', style: AppTypography.titleMedium(palette)),
              const SizedBox(height: AppSpacing.sm),
              const AppThemeToggle(),
              const SizedBox(height: AppSpacing.lg),
              Text('Almacenamiento', style: AppTypography.titleMedium(palette)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Reinicia la app tras cambiar las rutas. Los proyectos existentes '
                'conservan las rutas absolutas guardadas en la base de datos.',
                style: AppTypography.caption(palette),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_appDataPath != null)
                _StorageRow(
                  label: 'Datos técnicos',
                  path: _appDataPath!,
                  onPick: _pickAppData,
                ),
              const SizedBox(height: AppSpacing.sm),
              if (_documentsPath != null)
                _StorageRow(
                  label: 'Documentos del proyecto',
                  path: _documentsPath!,
                  onPick: _pickDocuments,
                ),
              if (SupabaseConfig.isConfigured) ...[
                const SizedBox(height: AppSpacing.lg),
                Text('Cuenta IRIS DP', style: AppTypography.titleMedium(palette)),
                const SizedBox(height: AppSpacing.sm),
                Consumer(
                  builder: (context, ref, _) {
                    final user = ref.watch(currentUserProvider);
                    if (user == null) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'No has iniciado sesión. Entra para sincronizar '
                            'proyectos con otros dispositivos.',
                            style: AppTypography.caption(palette),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          FilledButton.icon(
                            onPressed: () async {
                              Navigator.pop(context);
                              await openAuthScreen(context);
                            },
                            icon: const Icon(Icons.login),
                            label: const Text('Iniciar sesión'),
                          ),
                        ],
                      );
                    }
                    return FutureBuilder(
                      future: CloudSessionStore.workspaceName(),
                      builder: (context, snap) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.email ?? 'Sesión activa',
                              style: AppTypography.bodyMedium(palette),
                            ),
                            if (snap.data != null)
                              Text(
                                'Workspace: ${snap.data}',
                                style: AppTypography.caption(palette),
                              ),
                            TextButton.icon(
                              onPressed: () async {
                                final client = ref.read(supabaseClientProvider);
                                await client?.auth.signOut();
                                await CloudSessionStore.clear();
                                if (context.mounted) Navigator.pop(context);
                              },
                              icon: const Icon(Icons.logout),
                              label: const Text('Cerrar sesión'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                const UserTemplatesSettingsSection(),
                const SizedBox(height: AppSpacing.lg),
                const SettingsUpdateSection(),
                const SizedBox(height: AppSpacing.lg),
                const SettingsHealthSection(),
              ],
              const SizedBox(height: AppSpacing.lg),
              Text('Ayuda', style: AppTypography.titleMedium(palette)),
              const SizedBox(height: AppSpacing.sm),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.school_outlined, color: palette.accent),
                title: const Text('Ver tutorial inicial'),
                subtitle: Text(
                  'Configuración paso a paso desde el principio',
                  style: AppTypography.caption(palette),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await AppTutorialStore.resetAll();
                  if (!context.mounted) return;
                  await Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => const InitialTutorialFlow(
                        replayFromStart: true,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.menu_book_outlined, color: palette.accent),
                title: const Text('Instalación y actualización'),
                subtitle: Text(
                  'Cómo instalar y sincronizar tras actualizar la app',
                  style: AppTypography.caption(palette),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => const InstallUpdateGuideScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StorageRow extends StatelessWidget {
  final String label;
  final String path;
  final VoidCallback onPick;

  const _StorageRow({
    required this.label,
    required this.path,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.label(palette)),
          const SizedBox(height: 4),
          Text(
            path,
            style: AppTypography.caption(palette).copyWith(
              fontFamily: 'monospace',
            ),
          ),
          TextButton(onPressed: onPick, child: const Text('Cambiar carpeta…')),
        ],
      ),
    );
  }
}
