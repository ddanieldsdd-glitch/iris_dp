import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_button.dart';
import 'app_storage_config.dart';

/// Pantalla inicial para elegir dónde guardar datos técnicos y documentos.
class StorageSetupScreen extends ConsumerStatefulWidget {
  final VoidCallback? onConfigured;

  const StorageSetupScreen({super.key, this.onConfigured});

  @override
  ConsumerState<StorageSetupScreen> createState() => _StorageSetupScreenState();
}

class _StorageSetupScreenState extends ConsumerState<StorageSetupScreen> {
  late String _appDataPath;
  late String _documentsPath;
  var _loading = true;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _initPaths();
  }

  Future<void> _initPaths() async {
    final defaults = await AppStorageConfig.defaultPaths();
    setState(() {
      _appDataPath = defaults.appDataPath;
      _documentsPath = defaults.documentsPath;
      _loading = false;
    });
  }

  Future<void> _pickAppDataPath() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Carpeta de datos técnicos de IRIS DP',
    );
    if (path != null) setState(() => _appDataPath = path);
  }

  Future<void> _pickDocumentsPath() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Carpeta de documentos e imágenes del proyecto',
    );
    if (path != null) setState(() => _documentsPath = path);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await AppStorageConfig.save(
      StoragePaths(
        appDataPath: _appDataPath,
        documentsPath: _documentsPath,
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    widget.onConfigured?.call();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Configurar almacenamiento',
                    style: AppTypography.titleLarge(palette),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Elige dos ubicaciones: una para la base técnica de la app '
                    '(base de datos, catálogos) y otra para los documentos e '
                    'imágenes que generes al trabajar en tus proyectos.',
                    style: AppTypography.bodyMedium(palette).copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _PathTile(
                    title: 'Datos técnicos de la app',
                    subtitle:
                        'Base de datos, biblia, equipamiento, metadatos…',
                    path: _appDataPath,
                    onPick: _pickAppDataPath,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _PathTile(
                    title: 'Documentos del proyecto',
                    subtitle:
                        'Imágenes, PDFs, guiones, moodboard, exports…',
                    path: _documentsPath,
                    onPick: _pickDocumentsPath,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: _saving ? 'Guardando…' : 'Continuar',
                    icon: Icons.check,
                    onTap: _saving ? null : _save,
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

class _PathTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String path;
  final VoidCallback onPick;

  const _PathTile({
    required this.title,
    required this.subtitle,
    required this.path,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: palette.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.titleMedium(palette)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppTypography.caption(palette).copyWith(
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            path,
            style: AppTypography.caption(palette).copyWith(
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.folder_open_outlined, size: 16),
            label: const Text('Elegir carpeta…'),
          ),
        ],
      ),
    );
  }
}
