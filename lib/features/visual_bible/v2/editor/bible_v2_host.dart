import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../visual_bible_model.dart';
import '../bible_engine_v2_flag.dart';
import '../commands/bible_document_history.dart';
import '../editor/bible_canvas_editor.dart';
import '../migration/legacy_to_document_migrator.dart';
import '../model/bible_document.dart';
import '../persistence/bible_document_store.dart';

/// Host no destructivo: carga documento v2 o migra desde legacy (lazy).
class BibleV2Host extends ConsumerStatefulWidget {
  final int projectId;
  final int bibleId;
  final VisualBibleData? data;

  const BibleV2Host({
    super.key,
    required this.projectId,
    required this.bibleId,
    this.data,
  });

  @override
  ConsumerState<BibleV2Host> createState() => _BibleV2HostState();
}

class _BibleV2HostState extends ConsumerState<BibleV2Host> {
  BibleDocumentHistory? _history;
  BibleDocumentAutosave? _autosave;
  bool _loading = true;
  String? _error;
  bool _preview = false;
  String _saveStatus = 'Guardado';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final db = ref.read(databaseProvider);
      final store = BibleDocumentStore(db);
      var doc = await store.loadForBible(widget.bibleId);
      if (doc == null) {
        doc = await _migrateFromLegacy(db);
        await store.save(doc);
        await store.snapshotVersion(
          bibleId: widget.bibleId,
          doc: doc,
          label: 'v2_initial_migration',
          note: 'Migración lazy legacy → document',
        );
      }
      _history = BibleDocumentHistory(doc);
      _autosave = BibleDocumentAutosave(
        persist: (d) async {
          setState(() => _saveStatus = 'Guardando…');
          await store.save(d.copyWith(updatedAt: DateTime.now().toUtc()));
          if (mounted) setState(() => _saveStatus = 'Guardado');
        },
      );
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<BibleDocument> _migrateFromLegacy(AppDatabase db) async {
    final groups = await (db.select(
      db.bibleSectionGroups,
    )..where((t) => t.bibleId.equals(widget.bibleId))).get();
    final sections = await (db.select(
      db.bibleSectionDefinitions,
    )..where((t) => t.bibleId.equals(widget.bibleId))).get();

    return LegacyToDocumentMigrator.migrate(
      projectId: widget.projectId,
      bibleId: widget.bibleId,
      groups: groups
          .map(
            (g) => LegacyBibleGroupSnapshot(
              id: g.id,
              label: g.label,
              sortOrder: g.sortOrder,
            ),
          )
          .toList(),
      sections: sections
          .map(
            (s) => LegacyBibleSectionSnapshot(
              id: s.id,
              groupId: s.groupId,
              label: s.label,
              iconKey: s.iconKey,
              sortOrder: s.sortOrder,
              isHidden: s.isHidden,
              template: s.template,
              contentJson: s.contentJson,
            ),
          )
          .toList(),
      data: widget.data,
    );
  }

  void _onDocChanged(BibleDocument doc) {
    setState(() => _saveStatus = 'Cambios pendientes');
    _autosave?.schedule(doc);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null || _history == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'No se pudo cargar el motor v2',
                style: AppTypography.titleMedium(palette),
              ),
              const SizedBox(height: 8),
              Text(
                _error ?? 'Error desconocido',
                style: AppTypography.bodyMedium(palette),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  await BibleEngineV2Flag.setEnabled(widget.projectId, false);
                  BibleEngineV2Flag.revision.notify();
                },
                child: const Text('Volver a Biblia clásica'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Material(
          color: palette.surfaceOverlay,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Text('BIBLE ENGINE v2', style: AppTypography.label(palette)),
                const SizedBox(width: 12),
                Text(_saveStatus, style: AppTypography.caption(palette)),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    await _autosave?.flush();
                    await BibleEngineV2Flag.setEnabled(widget.projectId, false);
                    BibleEngineV2Flag.revision.notify();
                  },
                  child: const Text('Modo clásico'),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: BibleCanvasEditor(
            document: _history!.current,
            history: _history!,
            previewMode: _preview,
            onTogglePreview: () => setState(() => _preview = !_preview),
            onDocumentChanged: _onDocChanged,
          ),
        ),
      ],
    );
  }
}

/// Toggle UI embebible en Settings (no toca Master Config pesado).
class BibleEngineV2ToggleCard extends StatefulWidget {
  final int projectId;

  const BibleEngineV2ToggleCard({super.key, required this.projectId});

  @override
  State<BibleEngineV2ToggleCard> createState() =>
      _BibleEngineV2ToggleCardState();
}

class _BibleEngineV2ToggleCardState extends State<BibleEngineV2ToggleCard> {
  bool? _enabled;

  @override
  void initState() {
    super.initState();
    BibleEngineV2Flag.isEnabled(widget.projectId).then((v) {
      if (mounted) setState(() => _enabled = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final enabled = _enabled ?? false;
    return Card(
      margin: const EdgeInsets.all(16),
      child: SwitchListTile(
        title: Text(
          'Motor modular v2 (experimental)',
          style: AppTypography.titleMedium(palette),
        ),
        subtitle: Text(
          'Editor Page→Block. Desactivable; no borra la Biblia clásica.',
          style: AppTypography.bodyMedium(palette),
        ),
        value: enabled,
        onChanged: (v) async {
          await BibleEngineV2Flag.setEnabled(widget.projectId, v);
          BibleEngineV2Flag.revision.notify();
          setState(() => _enabled = v);
        },
      ),
    );
  }
}
