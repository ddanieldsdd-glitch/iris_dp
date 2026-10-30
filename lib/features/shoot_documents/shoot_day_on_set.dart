import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/shot_reference_import.dart';
import '../../shared/rich_text/script_markup.dart';
import 'shoot_day_order.dart';
import 'shoot_document_block_types.dart';

/// Cómo va un plano en el rodaje del día.
enum OnSetStatus {
  pending('Pendiente'),
  done('Hecho'),
  dropped('Descartado');

  final String label;
  const OnSetStatus(this.label);
}

/// Lo que se apunta en el set sobre un plano de la jornada (IP.2.4): si está
/// hecho o descartado y una nota rápida. Va en `contentOverridesJson` del
/// bloque, bajo `onSet`, así que viaja con la jornada sin tocar el esquema.
class OnSetMark {
  final OnSetStatus status;
  final String note;

  const OnSetMark({this.status = OnSetStatus.pending, this.note = ''});

  static const _key = 'onSet';

  static OnSetMark of(ShootDocumentBlock block) {
    final raw = block.contentOverridesJson;
    if (raw == null || raw.isEmpty) return const OnSetMark();
    try {
      final decoded = jsonDecode(raw);
      final m = decoded is Map ? decoded[_key] : null;
      if (m is! Map) return const OnSetMark();
      return OnSetMark(
        status: OnSetStatus.values
                .where((s) => s.name == m['status'])
                .firstOrNull ??
            OnSetStatus.pending,
        note: m['note'] as String? ?? '',
      );
    } catch (_) {
      return const OnSetMark();
    }
  }

  /// El JSON del bloque con esta marca, sin perder lo demás que tenga.
  String writeInto(String? json) {
    Map<String, dynamic> all = {};
    if (json != null && json.isNotEmpty) {
      try {
        final decoded = jsonDecode(json);
        if (decoded is Map) all = Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    if (status == OnSetStatus.pending && note.trim().isEmpty) {
      all.remove(_key);
    } else {
      all[_key] = {
        'status': status.name,
        if (note.trim().isNotEmpty) 'note': note.trim(),
      };
    }
    return jsonEncode(all);
  }

  OnSetMark copyWith({OnSetStatus? status, String? note}) =>
      OnSetMark(status: status ?? this.status, note: note ?? this.note);
}

/// La jornada en el set: los planos en su orden de rodaje, en tarjetas para
/// leer de un vistazo en el iPhone, y marcar cada uno hecho o descartado.
class ShootDayOnSetScreen extends ConsumerWidget {
  final int projectId;
  final int documentId;
  final String title;

  const ShootDayOnSetScreen({
    super.key,
    required this.projectId,
    required this.documentId,
    required this.title,
  });

  static Future<void> open(
    BuildContext context, {
    required int projectId,
    required int documentId,
    required String title,
  }) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ShootDayOnSetScreen(
        projectId: projectId,
        documentId: documentId,
        title: title,
      ),
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: palette.surface,
        title: Text('En set · $title', style: AppTypography.titleMedium(palette)),
      ),
      body: StreamBuilder<List<Scene>>(
        stream: db.watchScenesForProject(projectId),
        builder: (context, sceneSnap) => StreamBuilder<List<Shot>>(
          stream: db.watchShotsForProject(projectId),
          builder: (context, shotSnap) =>
              StreamBuilder<List<ShootDocumentBlock>>(
                stream: db.watchBlocksForShootDocument(documentId),
                builder: (context, blockSnap) {
                  if (!blockSnap.hasData || !shotSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final scenes = {
                    for (final s in sceneSnap.data ?? const <Scene>[]) s.id: s,
                  };
                  final shots = {for (final s in shotSnap.data!) s.id: s};
                  final blocks = [
                    for (final b in blockSnap.data!)
                      if (b.blockType == ShootBlockType.shot &&
                          shots.containsKey(b.shotId))
                        b,
                  ];
                  return OnSetList(
                    blocks: blocks,
                    shots: shots,
                    scenes: scenes,
                    onMark: (block, mark) => db.updateShootDocumentBlock(
                      block.copyWith(
                        contentOverridesJson: Value(
                          mark.writeInto(block.contentOverridesJson),
                        ),
                      ),
                    ),
                  );
                },
              ),
        ),
      ),
    );
  }
}

/// La lista de tarjetas, sin base de datos (para las pruebas).
class OnSetList extends StatelessWidget {
  final List<ShootDocumentBlock> blocks;
  final Map<int, Shot> shots;
  final Map<int, Scene> scenes;
  final Future<void> Function(ShootDocumentBlock, OnSetMark) onMark;

  const OnSetList({
    super.key,
    required this.blocks,
    required this.shots,
    required this.scenes,
    required this.onMark,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (blocks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            'La jornada aún no tiene planos. Añádelos desde el iPad o el Mac.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium(palette),
          ),
        ),
      );
    }
    final marks = [for (final b in blocks) OnSetMark.of(b)];
    final done = marks.where((m) => m.status == OnSetStatus.done).length;
    final dropped = marks.where((m) => m.status == OnSetStatus.dropped).length;
    final byId = {for (final b in blocks) b.id: b};
    final tracts = groupShootTracts(
      [for (final b in blocks) b.id],
      (id) => shots[byId[id]!.shotId]!.sceneId,
    );
    final gutter = AppLayout.gutter(context);
    var order = 0;
    return ListView(
      padding: EdgeInsets.fromLTRB(gutter, AppSpacing.md, gutter, 40),
      children: [
        Text(
          '$done de ${blocks.length - dropped} hechos'
          '${dropped > 0 ? ' · $dropped descartados' : ''}',
          style: AppTypography.label(palette),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            minHeight: 6,
            value: blocks.length == dropped
                ? 1
                : done / (blocks.length - dropped),
          ),
        ),
        for (final tract in tracts) ...[
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: 6),
            child: Text(
              _sceneTitle(scenes[tract.sceneId]),
              style: AppTypography.titleMedium(palette),
            ),
          ),
          for (final id in tract.blockIds)
            OnSetShotCard(
              order: ++order,
              shot: shots[byId[id]!.shotId]!,
              scene: scenes[tract.sceneId],
              mark: OnSetMark.of(byId[id]!),
              onMark: (mark) => onMark(byId[id]!, mark),
            ),
        ],
      ],
    );
  }

  static String _sceneTitle(Scene? scene) => scene == null
      ? 'Escena'
      : 'ESC ${scene.label} · ${scene.locationCanonical}';
}

/// Un plano en el set: lo que hay que rodar y su estado. Sin [onMark] es
/// solo de lectura (el guion técnico en el iPhone).
class OnSetShotCard extends StatelessWidget {
  final int order;
  final Shot shot;
  final Scene? scene;
  final OnSetMark mark;
  final ValueChanged<OnSetMark>? onMark;

  const OnSetShotCard({
    super.key,
    required this.order,
    required this.shot,
    required this.scene,
    this.mark = const OnSetMark(),
    this.onMark,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final body = AppTypography.bodyMedium(
      palette,
    ).copyWith(color: palette.textPrimary);
    final caption = AppTypography.caption(palette);
    final optics = [
      shot.lens,
      shot.angle,
      shot.movement,
      shot.fStop,
    ].where((v) => v != null && v.trim().isNotEmpty).join(' · ');
    final image = referenceImageOf(shot);
    final done = mark.status == OnSetStatus.done;
    final dropped = mark.status == OnSetStatus.dropped;
    return Opacity(
      opacity: dropped ? 0.5 : 1,
      child: Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        color: done
            ? palette.accent.withValues(alpha: 0.12)
            : palette.surfaceElevated,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: done ? palette.accent : palette.surface,
                    child: done
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : Text('$order', style: caption),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Esc. ${scene?.label ?? '—'} · Plano ${shot.number}'
                          '${(shot.framing ?? '').trim().isEmpty ? '' : ' · ${scriptMarkupToPlain(shot.framing)}'}',
                          style: body.copyWith(
                            fontWeight: FontWeight.w600,
                            decoration: dropped
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        if (optics.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(optics, style: AppTypography.mono(palette)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (image != null && File(image).existsSync()) ...[
                const SizedBox(height: AppSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.file(
                      File(image),
                      fit: BoxFit.cover,
                      cacheWidth: 900,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ],
              if ((shot.action ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(scriptMarkupToPlain(shot.action), style: body),
              ],
              if ((shot.notes ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(scriptMarkupToPlain(shot.notes), style: caption),
              ],
              if (mark.note.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Nota de set: ${mark.note}', style: caption),
              ],
              if (onMark case final onMark?) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  FilterChip(
                    avatar: const Icon(Icons.check, size: 16),
                    label: const Text('Hecho'),
                    selected: done,
                    onSelected: (on) => onMark(
                      mark.copyWith(
                        status: on ? OnSetStatus.done : OnSetStatus.pending,
                      ),
                    ),
                  ),
                  FilterChip(
                    avatar: const Icon(Icons.block, size: 16),
                    label: const Text('Descartar'),
                    selected: dropped,
                    onSelected: (on) => onMark(
                      mark.copyWith(
                        status: on ? OnSetStatus.dropped : OnSetStatus.pending,
                      ),
                    ),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.edit_note, size: 16),
                    label: Text(mark.note.isEmpty ? 'Nota' : 'Editar nota'),
                    onPressed: () => _editNote(context, onMark),
                  ),
                ],
              ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editNote(
    BuildContext context,
    ValueChanged<OnSetMark> onMark,
  ) async {
    final ctrl = TextEditingController(text: mark.note);
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Nota · plano ${shot.number}'),
        content: SizedBox(
          width: AppLayout.dialogWidth(ctx, 420),
          child: TextField(
            controller: ctrl,
            autofocus: true,
            maxLines: 4,
            minLines: 2,
            decoration: const InputDecoration(
              hintText: 'Toma buena la 3, falta el inserto…',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (note != null) onMark(mark.copyWith(note: note));
  }
}
