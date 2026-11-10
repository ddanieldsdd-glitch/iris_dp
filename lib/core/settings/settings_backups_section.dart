import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cloud/cloud_providers.dart';
import '../database/app_database.dart';
import '../database/database_provider.dart';
import '../database/local_database_backup.dart';
import '../sync/project_content_sync_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/user_error.dart';
import '../widgets/app_snackbar.dart';
import 'app_prefs.dart';
import 'settings_widgets.dart';

abstract final class BackupPrefs {
  static const folder = PrefKey<String>('backup.secondFolder', '');

  /// La segunda carpeta solo existe en el ordenador; en el iPad y el iPhone
  /// la app no puede escribir fuera de su espacio.
  static bool get supported => Platform.isMacOS || Platform.isWindows;

  static String? secondFolder() {
    if (!supported) return null;
    final value = AppPrefs.instance.globalValue(folder);
    return value.isEmpty ? null : value;
  }
}

String _when(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}

String _size(int bytes) => bytes < 1024 * 1024
    ? '${(bytes / 1024).round()} KB'
    : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

/// Copias de este equipo y versiones guardadas en la nube, y cómo volver a
/// una de ellas.
class SettingsBackupsSection extends ConsumerStatefulWidget {
  const SettingsBackupsSection({super.key});

  @override
  ConsumerState<SettingsBackupsSection> createState() =>
      _SettingsBackupsSectionState();
}

class _SettingsBackupsSectionState
    extends ConsumerState<SettingsBackupsSection> {
  late Future<List<DatabaseCopy>> _copies = LocalDatabaseBackup.list();
  bool _restorePending = false;

  Future<bool> _confirm(String title, String message, String action) async {
    final palette = context.palette;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surfaceElevated,
        title: Text(title, style: AppTypography.titleMedium(palette)),
        content: Text(message, style: AppTypography.bodyMedium(palette)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _backupNow() async {
    try {
      await LocalDatabaseBackup.create(
        ref.read(databaseProvider),
        label: LocalDatabaseBackup.dailyLabel,
        kept: LocalDatabaseBackup.dailyKept,
      );
      if (!mounted) return;
      setState(() => _copies = LocalDatabaseBackup.list());
      AppSnackBar.show(context, 'Copia guardada.');
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, userFriendlyError(e));
    }
  }

  Future<void> _restore(DatabaseCopy copy) async {
    final ok = await _confirm(
      '¿Volver a esta copia?',
      'Todos los proyectos de este equipo volverán a como estaban el '
          '${_when(copy.when)}. Lo actual se guarda antes como otra copia. '
          'Si hay proyectos en la nube, IRIS te preguntará qué versión '
          'conservar de cada uno.\n\nSe aplica la próxima vez que abras IRIS.',
      'Volver a esta copia',
    );
    if (!ok) return;
    try {
      await LocalDatabaseBackup.scheduleRestore(copy);
      if (mounted) setState(() => _restorePending = true);
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, userFriendlyError(e));
    }
  }

  Future<void> _pickFolder() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Segunda carpeta para las copias',
    );
    if (path == null) return;
    await AppPrefs.instance.setIn(
      BackupPrefs.folder,
      const SettingsScope.global(),
      path,
    );
    if (mounted) setState(() {});
  }

  Future<void> _openVersions(Project project) async {
    final client = ref.read(supabaseClientProvider);
    if (client == null) return;
    final sync = ProjectContentSyncService(ref.read(databaseProvider), client);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.palette.surfaceElevated,
      builder: (sheet) => _CloudVersionsSheet(
        project: project,
        sync: sync,
        confirm: (version) => _confirm(
          '¿Volver a esta versión?',
          '«${project.name}» volverá a como estaba el '
              '${_when(version.savedAt)}, aquí y en la nube. Lo actual queda '
              'en el historial y en una copia de este equipo.',
          'Volver a esta versión',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final folder = BackupPrefs.secondFolder();
    final hasCloud = ref.watch(supabaseClientProvider) != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_restorePending) ...[
          SettingsGroupBox(
            children: [
              SettingsRow(
                title: 'Copia lista para restaurar',
                subtitle: 'Cierra IRIS y vuelve a abrirlo para aplicarla.',
                trailing: BackupPrefs.supported
                    ? TextButton(
                        key: const ValueKey('backup-quit'),
                        onPressed: () => exit(0),
                        child: const Text('Cerrar IRIS'),
                      )
                    : null,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        SettingsGroupBox(
          title: 'En este equipo',
          footer:
              'Una copia al día de los datos, las 7 últimas. Las imágenes se '
              'quedan en su carpeta y no entran en la copia.',
          children: [
            SettingsRow(
              title: 'Hacer una copia ahora',
              trailing: TextButton(
                key: const ValueKey('backup-now'),
                onPressed: _backupNow,
                child: const Text('Copiar'),
              ),
            ),
            if (BackupPrefs.supported)
              SettingsRow(
                title: 'Segunda carpeta',
                subtitle:
                    folder ?? 'Otra copia diaria en un disco o en iCloud Drive',
                trailing: TextButton(
                  onPressed: _pickFolder,
                  child: Text(folder == null ? 'Elegir…' : 'Cambiar…'),
                ),
              ),
            FutureBuilder<List<DatabaseCopy>>(
              future: _copies,
              builder: (context, snap) {
                final copies = snap.data;
                if (copies == null) return const SizedBox.shrink();
                if (copies.isEmpty) {
                  return const SettingsRow(title: 'Aún no hay copias');
                }
                return Column(
                  children: [
                    for (final copy in copies)
                      SettingsRow(
                        title: copy.title,
                        subtitle:
                            '${_when(copy.when)} · ${_size(copy.sizeBytes)}',
                        trailing: TextButton(
                          onPressed: () => _restore(copy),
                          child: const Text('Volver a esta'),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
        if (hasCloud) ...[
          const SizedBox(height: AppSpacing.lg),
          SettingsGroupBox(
            title: 'En la nube',
            footer:
                'La nube guarda una versión de cada proyecto cada media hora '
                'de trabajo, y siempre que un proyecto pierde planos. Se '
                'conservan las 20 últimas.',
            children: [
              StreamBuilder<List<Project>>(
                stream: ref.watch(databaseProvider).watchProjects(),
                builder: (context, snap) {
                  final linked = [
                    for (final p in snap.data ?? const <Project>[])
                      if (p.cloudId != null) p,
                  ];
                  if (linked.isEmpty) {
                    return Text(
                      'Ningún proyecto en la nube.',
                      style: AppTypography.caption(palette),
                    );
                  }
                  return Column(
                    children: [
                      for (final project in linked)
                        SettingsRow(
                          title: project.name,
                          trailing: TextButton(
                            onPressed: () => _openVersions(project),
                            child: const Text('Versiones…'),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _CloudVersionsSheet extends StatefulWidget {
  final Project project;
  final ProjectContentSyncService sync;
  final Future<bool> Function(CloudVersion version) confirm;

  const _CloudVersionsSheet({
    required this.project,
    required this.sync,
    required this.confirm,
  });

  @override
  State<_CloudVersionsSheet> createState() => _CloudVersionsSheetState();
}

class _CloudVersionsSheetState extends State<_CloudVersionsSheet> {
  late final _versions = widget.sync.listVersions(widget.project.cloudId!);
  bool _busy = false;

  Future<void> _restore(CloudVersion version) async {
    if (_busy || !await widget.confirm(version) || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.sync.restoreVersion(
        widget.project.id,
        widget.project.cloudId!,
        version.id,
      );
      if (!mounted) return;
      AppSnackBar.show(context, 'Versión restaurada.');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppSnackBar.showError(context, userFriendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.7,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Versiones de «${widget.project.name}»',
                style: AppTypography.titleMedium(palette),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: FutureBuilder<List<CloudVersion>?>(
                  future: _versions,
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Text(
                        userFriendlyError(snap.error!),
                        style: AppTypography.bodyMedium(palette),
                      );
                    }
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final versions = snap.data;
                    if (versions == null) {
                      return Text(
                        'Falta activar el historial en Supabase '
                        '(migración 013).',
                        style: AppTypography.bodyMedium(palette),
                      );
                    }
                    if (versions.isEmpty) {
                      return Text(
                        'Aún no hay versiones guardadas.',
                        style: AppTypography.bodyMedium(palette),
                      );
                    }
                    return ListView(
                      children: [
                        for (final v in versions)
                          SettingsRow(
                            title: _when(v.savedAt),
                            subtitle:
                                '${v.sceneCount} escenas · ${v.shotCount} planos'
                                '${v.device == null ? '' : ' · ${v.device}'}',
                            trailing: TextButton(
                              onPressed: _busy ? null : () => _restore(v),
                              child: const Text('Volver a esta'),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
