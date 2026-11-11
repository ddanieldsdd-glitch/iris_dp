import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/settings/app_prefs.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/shot_reference_import.dart';
import '../../shared/rich_text/script_markup.dart';
import 'on_set_view_prefs.dart';
import 'shoot_day_order.dart';
import 'shoot_day_timeline.dart';
import 'shoot_day_widgets.dart';
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
        status:
            OnSetStatus.values
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
        // Cuándo se apuntó: si dos aparatos marcan distinto, gana la última.
        'at': DateTime.now().toUtc().toIso8601String(),
      };
    }
    return jsonEncode(all);
  }

  OnSetMark copyWith({OnSetStatus? status, String? note}) =>
      OnSetMark(status: status ?? this.status, note: note ?? this.note);
}

/// La jornada en el set: los planos en su orden de rodaje, en tarjetas para
/// leer de un vistazo y marcar cada uno hecho o descartado. En pantallas
/// anchas las tarjetas van en rejilla.
class ShootDayOnSetScreen extends ConsumerStatefulWidget {
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
  ConsumerState<ShootDayOnSetScreen> createState() =>
      _ShootDayOnSetScreenState();
}

class _ShootDayOnSetScreenState extends ConsumerState<ShootDayOnSetScreen> {
  late final AppDatabase _db = ref.read(databaseProvider);
  late final Stream<List<ShootDocument>> _days = _db
      .watchShootDocumentsForProject(widget.projectId);
  late final Stream<List<Scene>> _scenes = _db.watchScenesForProject(
    widget.projectId,
  );
  late final Stream<List<Shot>> _shots = _db.watchShotsForProject(
    widget.projectId,
  );

  ShootDocument? _lastSeen;
  int? _blocksDayId;
  Stream<List<ShootDocumentBlock>>? _blocks;

  Stream<List<ShootDocumentBlock>> _blocksFor(int dayId) {
    if (_blocksDayId != dayId || _blocks == null) {
      _blocksDayId = dayId;
      _blocks = _db.watchBlocksForShootDocument(dayId);
    }
    return _blocks!;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: palette.surface,
        title: Text(
          'En set · ${widget.title}',
          style: AppTypography.titleMedium(palette),
        ),
      ),
      body: StreamBuilder<List<ShootDocument>>(
        stream: _days,
        builder: (context, daySnap) {
          if (!daySnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final day = resolveOpenShootDay(
            daySnap.data!,
            id: widget.documentId,
            lastSeen: _lastSeen,
          );
          if (day == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  'Esta jornada ya no existe en el proyecto.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium(palette),
                ),
              ),
            );
          }
          _lastSeen = day;
          return StreamBuilder<List<Scene>>(
            stream: _scenes,
            builder: (context, sceneSnap) => StreamBuilder<List<Shot>>(
              stream: _shots,
              builder: (context, shotSnap) =>
                  StreamBuilder<List<ShootDocumentBlock>>(
                    stream: _blocksFor(day.id),
                    builder: (context, blockSnap) {
                      if (!blockSnap.hasData || !shotSnap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return _body(
                        day,
                        sceneSnap.data ?? const [],
                        shotSnap.data!,
                        blockSnap.data!,
                      );
                    },
                  ),
            ),
          );
        },
      ),
    );
  }

  Widget _body(
    ShootDocument day,
    List<Scene> sceneRows,
    List<Shot> shotRows,
    List<ShootDocumentBlock> blockRows,
  ) {
    final scenes = {for (final s in sceneRows) s.id: s};
    final shots = {for (final s in shotRows) s.id: s};
    final blocks = [
      for (final b in blockRows)
        if (b.blockType == ShootBlockType.shot && shots.containsKey(b.shotId))
          b,
    ];
    final projectId = widget.projectId;
    final dayKey = OnSetViewPrefs.dayKey(day);
    return ListenableBuilder(
      listenable: AppPrefs.instance,
      builder: (context, _) {
        final hidden = OnSetViewPrefs.hiddenShots(projectId, dayKey);
        final hideFinished = OnSetViewPrefs.hideFinished(projectId);
        return OnSetList(
          blocks: blocks,
          shots: shots,
          scenes: scenes,
          strips: [
            for (final b in blockRows)
              if (ShootStrip.isStrip(b)) b,
          ],
          hideFinished: hideFinished,
          hiddenShots: hidden,
          onHideFinishedChanged: (v) =>
              OnSetViewPrefs.setHideFinished(projectId, v),
          onHideShot: (shot) => OnSetViewPrefs.setHiddenShots(
            projectId,
            dayKey,
            {...hidden, OnSetViewPrefs.shotKey(shot)},
          ),
          onShowHidden: () async {
            await OnSetViewPrefs.setHiddenShots(projectId, dayKey, const {});
            await OnSetViewPrefs.setHideFinished(projectId, false);
          },
          onMark: (block, mark) => _db.updateShootDocumentBlock(
            block.copyWith(
              contentOverridesJson: Value(
                mark.writeInto(block.contentOverridesJson),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// La lista de tarjetas, sin base de datos (para las pruebas). Lo oculto solo
/// cambia lo que se ve: la cuenta de hechos sigue siendo la de toda la jornada.
class OnSetList extends StatelessWidget {
  final List<ShootDocumentBlock> blocks;
  final Map<int, Shot> shots;
  final Map<int, Scene> scenes;
  final Future<void> Function(ShootDocumentBlock, OnSetMark) onMark;

  /// Montaje, comida… del día, para tenerlos a la vista. No cuentan como
  /// planos hechos.
  final List<ShootDocumentBlock> strips;
  final bool hideFinished;
  final Set<String> hiddenShots;
  final ValueChanged<bool>? onHideFinishedChanged;
  final ValueChanged<Shot>? onHideShot;
  final VoidCallback? onShowHidden;

  const OnSetList({
    super.key,
    required this.blocks,
    required this.shots,
    required this.scenes,
    required this.onMark,
    this.strips = const [],
    this.hideFinished = false,
    this.hiddenShots = const {},
    this.onHideFinishedChanged,
    this.onHideShot,
    this.onShowHidden,
  });

  /// Columnas de tarjetas según el ancho útil.
  static int columnsFor(double width) => width >= 1200
      ? 3
      : width >= 720
      ? 2
      : 1;

  bool _isVisible(ShootDocumentBlock block) {
    if (hiddenShots.contains(OnSetViewPrefs.shotKey(shots[block.shotId]!))) {
      return false;
    }
    return !hideFinished || OnSetMark.of(block).status == OnSetStatus.pending;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (blocks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            'La jornada aún no tiene planos. Añádelos desde la jornada.',
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
    final tracts = groupShootTracts([
      for (final b in blocks) b.id,
    ], (id) => shots[byId[id]!.shotId]!.sceneId);
    final hiddenCount = blocks.where((b) => !_isVisible(b)).length;
    final gutter = AppLayout.gutter(context);
    final columns = columnsFor(MediaQuery.sizeOf(context).width - 2 * gutter);
    var order = 0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth =
            (constraints.maxWidth -
                2 * gutter -
                (columns - 1) * AppSpacing.sm) /
            columns;
        return ListView(
          padding: EdgeInsets.fromLTRB(gutter, AppSpacing.md, gutter, 40),
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.sm,
              children: [
                Text(
                  '$done de ${blocks.length - dropped} hechos'
                  '${dropped > 0 ? ' · $dropped descartados' : ''}',
                  style: AppTypography.label(palette),
                ),
                if (onHideFinishedChanged case final onChanged?)
                  TextButton.icon(
                    onPressed: () => onChanged(!hideFinished),
                    icon: Icon(
                      hideFinished
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 16,
                    ),
                    label: Text(
                      hideFinished ? 'Mostrar hechos' : 'Ocultar hechos',
                    ),
                  ),
              ],
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
            if (strips.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final block in strips) _StripChip(block: block),
                  ],
                ),
              ),
            if (hiddenCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.sm,
                  children: [
                    Text(
                      hiddenCount == 1
                          ? '1 plano oculto en este aparato'
                          : '$hiddenCount planos ocultos en este aparato',
                      style: AppTypography.caption(palette),
                    ),
                    if (onShowHidden != null)
                      TextButton(
                        onPressed: onShowHidden,
                        child: const Text('Mostrar todo'),
                      ),
                  ],
                ),
              ),
            for (final tract in tracts)
              ..._tract(
                context,
                tract: tract,
                byId: byId,
                nextOrder: () => ++order,
                cardWidth: cardWidth,
              ),
          ],
        );
      },
    );
  }

  List<Widget> _tract(
    BuildContext context, {
    required ShootTract tract,
    required Map<int, ShootDocumentBlock> byId,
    required int Function() nextOrder,
    required double cardWidth,
  }) {
    final palette = context.palette;
    final cards = <Widget>[];
    for (final id in tract.blockIds) {
      // El número es el de rodaje: ocultar un plano no renumera los demás.
      final number = nextOrder();
      final block = byId[id]!;
      if (!_isVisible(block)) continue;
      final shot = shots[block.shotId]!;
      cards.add(
        SizedBox(
          width: cardWidth,
          child: OnSetShotCard(
            order: number,
            shot: shot,
            scene: scenes[tract.sceneId],
            mark: OnSetMark.of(block),
            time: ShotTime.of(block),
            onMark: (mark) => onMark(block, mark),
            onHide: onHideShot == null ? null : () => onHideShot!(shot),
          ),
        ),
      );
    }
    if (cards.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: 6),
        child: Text(
          _sceneTitle(scenes[tract.sceneId]),
          style: AppTypography.titleMedium(palette),
        ),
      ),
      Wrap(spacing: AppSpacing.sm, children: cards),
    ];
  }

  static String _sceneTitle(Scene? scene) => scene == null
      ? 'Escena'
      : 'ESC ${scene.label} · ${scene.locationCanonical}';
}

/// Una franja del día en el set, solo para leerla.
class _StripChip extends StatelessWidget {
  final ShootDocumentBlock block;

  const _StripChip({required this.block});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final strip = ShootStrip.of(block);
    final color = shootStripColor(strip.kind, palette);
    final time = shootTimeRange(strip.from, strip.to);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(shootStripIcon(strip.kind), size: 13, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              [
                if (time.isNotEmpty) time,
                ShootStrip.titleOf(block),
              ].join(' · '),
              style: AppTypography.caption(
                palette,
              ).copyWith(color: palette.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un plano en el set: lo que hay que rodar y su estado. Sin [onMark] es
/// solo de lectura (el guion técnico en el iPhone).
class OnSetShotCard extends StatelessWidget {
  final int order;
  final Shot shot;
  final Scene? scene;
  final OnSetMark mark;

  /// Hora y apunte del plan de rodaje.
  final ShotTime time;
  final ValueChanged<OnSetMark>? onMark;

  /// Lo quita de la vista de este aparato.
  final VoidCallback? onHide;

  const OnSetShotCard({
    super.key,
    required this.order,
    required this.shot,
    required this.scene,
    this.mark = const OnSetMark(),
    this.time = const ShotTime(),
    this.onMark,
    this.onHide,
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
    final image = coverImageOf(shot);
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
                        if (!time.isEmpty) ...[
                          const SizedBox(height: 2),
                          ShotTimeText(time: time),
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
                          status: on
                              ? OnSetStatus.dropped
                              : OnSetStatus.pending,
                        ),
                      ),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.edit_note, size: 16),
                      label: Text(mark.note.isEmpty ? 'Nota' : 'Editar nota'),
                      onPressed: () => _editNote(context, onMark),
                    ),
                    if (onHide != null)
                      ActionChip(
                        avatar: const Icon(
                          Icons.visibility_off_outlined,
                          size: 16,
                        ),
                        label: const Text('Ocultar'),
                        onPressed: onHide,
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
