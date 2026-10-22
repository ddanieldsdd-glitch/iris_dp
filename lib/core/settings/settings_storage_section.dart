import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../storage/app_storage_config.dart';
import '../storage/legacy_storage_discovery.dart';
import '../storage/storage_relocation_dialog.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'settings_widgets.dart';

/// Carpetas de datos y documentos, y la búsqueda de datos que quedaron en
/// otras ubicaciones.
class SettingsStorageSection extends StatefulWidget {
  const SettingsStorageSection({super.key});

  @override
  State<SettingsStorageSection> createState() => _SettingsStorageSectionState();
}

class _SettingsStorageSectionState extends State<SettingsStorageSection> {
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
      dialogTitle: 'Datos técnicos de IRIS',
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

  Future<void> _scanLegacyStorage() async {
    final proposal = await LegacyStorageDiscovery.findRelocationProposal();
    if (!mounted) return;
    if (proposal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay datos en otras ubicaciones que mover.'),
        ),
      );
      return;
    }
    await runStorageRelocationFlow(context, proposal);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroupBox(
          title: 'Carpetas',
          footer:
              'Reinicia la app tras cambiar las rutas. Los proyectos existentes '
              'conservan las rutas absolutas guardadas en la base de datos.',
          children: [
            if (_appDataPath != null)
              SettingsRow(
                title: 'Datos técnicos',
                subtitle: _appDataPath,
                trailing: TextButton(
                  onPressed: _pickAppData,
                  child: const Text('Cambiar…'),
                ),
              ),
            if (_documentsPath != null)
              SettingsRow(
                title: 'Documentos del proyecto',
                subtitle: _documentsPath,
                trailing: TextButton(
                  onPressed: _pickDocuments,
                  child: const Text('Cambiar…'),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        SettingsGroupBox(
          title: 'Datos antiguos',
          children: [
            SettingsRow(
              title: 'Buscar datos en otras ubicaciones',
              subtitle:
                  'Por si quedaron proyectos en carpetas de versiones '
                  'anteriores de la app',
              trailing: Icon(Icons.chevron_right, color: palette.textTertiary),
              onTap: _scanLegacyStorage,
            ),
          ],
        ),
      ],
    );
  }
}
