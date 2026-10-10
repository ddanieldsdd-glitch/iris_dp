import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/catalog/equipment_facts.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/visual_bible/bible_table.dart';
import 'bible_point_panel.dart';

/// Lo que se sabe de una cámara: su fila de la base, completada con el
/// catálogo que viene con la app (códec y fps por modo, peso…).
Future<CameraFacts?> loadCameraFacts(
  AppDatabase db, {
  int? cameraId,
  String name = '',
}) async {
  final row = cameraId == null ? null : await db.getCameraById(cameraId);
  CameraFacts? fromDb;
  if (row != null) {
    List<CameraModeFacts> modes = const [];
    try {
      final decoded = jsonDecode(row.sensorModesJson ?? '[]');
      if (decoded is List) {
        modes = [
          for (final m in decoded)
            if (m is Map) CameraModeFacts.fromJson(m),
        ];
      }
    } catch (_) {}
    fromDb = CameraFacts(
      name: '${row.brand} ${row.model}',
      sensorWidthMm: row.sensorWidthMm,
      sensorHeightMm: row.sensorHeightMm,
      mount: (row.mountType ?? '').isEmpty ? null : row.mountType,
      dynamicRangeStops: row.dynamicRangeStops,
      nativeIso: row.nativeIso,
      logFormats: (row.logFormats ?? '').isEmpty ? null : row.logFormats,
      weightKg: row.weightKg,
      modes: modes,
    );
  }
  final parts = name.trim().split(' ');
  final fromCatalog = await EquipmentCatalog.camera(
    externalId: row?.externalId,
    brand: row?.brand ?? (parts.isEmpty ? '' : parts.first),
    model: row?.model ?? parts.skip(1).join(' '),
  );
  return fromDb?.mergedWith(fromCatalog) ?? fromCatalog;
}

/// Datos de una cámara por su identificador en la base y su nombre.
final cameraFactsProvider = FutureProvider.family<
  CameraFacts?,
  ({int? cameraId, String name})
>(
  (ref, key) => loadCameraFacts(
    ref.watch(databaseProvider),
    cameraId: key.cameraId,
    name: key.name,
  ),
);

Widget _notice(AppPalette palette, IconData icon, String text, {Color? color}) =>
    Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: (color ?? palette.highlightYellow).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (color ?? palette.highlightYellow).withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color ?? palette.highlightYellow),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppTypography.bodyMedium(palette))),
        ],
      ),
    );

/// Elige el modo de grabación entre los de la cámara y avisa de lo que
/// supone: si recorta el sensor y si la cadencia pedida no cabe en él.
class CameraModePicker extends StatelessWidget {
  final CameraFacts? facts;

  /// Nombre del modo elegido, o vacío.
  final String selected;

  /// Cadencias que se piden («24», «48 fps»): trabajo y cámara lenta.
  final List<String> wantedFps;
  final ValueChanged<CameraModeFacts> onSelected;

  const CameraModePicker({
    super.key,
    required this.facts,
    required this.selected,
    required this.onSelected,
    this.wantedFps = const [],
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final label = BiblePointPanel.labelStyle(palette);
    final caption = AppTypography.caption(palette);
    final cam = facts;
    if (cam == null || cam.modes.isEmpty) {
      return Text(
        cam == null
            ? 'Elige una cámara arriba para ver en qué puede grabar.'
            : 'El catálogo no tiene los modos de grabación de esta cámara: '
                  'escribe los datos a mano.',
        style: caption,
      );
    }
    final mode = cam.mode(selected);
    final warnings = <Widget>[];
    if (mode != null) {
      final crop = mode.cropWarning();
      if (crop != null) {
        warnings.add(_notice(palette, Icons.crop_outlined, crop));
      }
      for (final wanted in wantedFps) {
        final fps = firstNumber(wanted);
        if (fps == null || mode.fpsMax == null || fps <= mode.fpsMax!) continue;
        final others = cam.modesReaching(fps);
        warnings.add(
          _notice(
            palette,
            Icons.speed_outlined,
            others.isEmpty
                ? 'Este modo llega a ${mode.fpsLabel}: a ${wanted.trim()} no '
                      'graba, y el catálogo no tiene ningún modo de esta '
                      'cámara que llegue.'
                : 'Este modo llega a ${mode.fpsLabel}. Para ${wanted.trim()} '
                      'hay que pasar a ${others.first.name}'
                      '${others.first.crops ? ', que recorta el sensor al ${(others.first.cropFactor! * 100).round()} %' : ''}.',
            color: palette.error,
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('MODO DE GRABACIÓN · ${cam.name.toUpperCase()}', style: label),
        const SizedBox(height: 6),
        PopupMenuButton<CameraModeFacts>(
          tooltip: 'Elegir modo de grabación',
          onSelected: onSelected,
          itemBuilder: (_) => [
            for (final m in cam.modes)
              PopupMenuItem(
                value: m,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.name),
                    Text(
                      [
                        m.resolution,
                        m.codec,
                        m.fpsLabel == null ? null : 'hasta ${m.fpsLabel}',
                        m.crops
                            ? 'recorta al ${(m.cropFactor! * 100).round()} %'
                            : null,
                      ].whereType<String>().join(' · '),
                      style: caption,
                    ),
                  ],
                ),
              ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: palette.background.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: palette.borderBright),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    mode?.name ??
                        (selected.trim().isEmpty
                            ? 'Elegir entre ${cam.modes.length} modos…'
                            : selected),
                    style: AppTypography.bodyLarge(palette),
                  ),
                ),
                Icon(Icons.expand_more, color: palette.textSecondary),
              ],
            ),
          ),
        ),
        if (mode != null && (mode.codec == null || mode.fpsMax == null))
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Sin dato en el catálogo para este modo: '
              '${[if (mode.codec == null) 'códec', if (mode.fpsMax == null) 'fps máximos'].join(' y ')}.',
              style: caption,
            ),
          ),
        ...warnings,
      ],
    );
  }
}

/// Matriz de grabación: todos los modos de la cámara, y se marcan los que
/// se van a usar. Los marcados son las filas de la tabla que se guarda.
class CameraRecordingMatrix extends StatelessWidget {
  final CameraFacts? facts;
  final BibleTableValue value;
  final ValueChanged<BibleTableValue> onChanged;

  const CameraRecordingMatrix({
    super.key,
    required this.facts,
    required this.value,
    required this.onChanged,
  });

  static const columns = [
    'Modo',
    'Resolución',
    'Relación',
    'Sensor usado',
    'Códec',
    'fps máx.',
    'Para qué',
  ];

  static List<String> rowOf(CameraModeFacts m, {String use = ''}) => [
    m.name,
    m.resolution ?? '',
    m.aspectRatio ?? '',
    m.cropFactor == null ? '' : '${(m.cropFactor! * 100).round()} %',
    m.codec ?? '',
    m.fpsLabel ?? '',
    use,
  ];

  /// La tabla con las columnas de la matriz, conservando lo que tuviera.
  BibleTableValue get _table {
    if (value.columns.length == columns.length &&
        value.columns.first == columns.first) {
      return value;
    }
    return BibleTableValue(
      columns: columns,
      rows: [
        for (final row in value.filledRows)
          [
            for (var i = 0; i < columns.length; i++)
              i < row.length ? row[i] : '',
          ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final caption = AppTypography.caption(palette);
    final mono = AppTypography.mono(palette).copyWith(fontSize: 12);
    final cam = facts;
    final table = _table;
    final chosen = {
      for (var i = 0; i < table.rows.length; i++)
        table.rows[i].first.trim().toLowerCase(): i,
    };
    if (cam == null || cam.modes.isEmpty) {
      return Text(
        cam == null
            ? 'Elige una cámara para ver todo lo que puede grabar.'
            : 'El catálogo no tiene los modos de esta cámara.',
        style: caption,
      );
    }

    Widget cell(String text, {int flex = 2, TextStyle? style}) => Expanded(
      flex: flex,
      child: Text(
        text.isEmpty ? '—' : text,
        style: style ?? mono,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Todo lo que graba la ${cam.name}. Marca lo que vais a usar: es lo '
          'que sale en el PDF.',
          style: caption,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const SizedBox(width: 40),
            for (final (title, flex) in const [
              ('MODO', 3),
              ('RESOLUCIÓN', 2),
              ('RELACIÓN', 1),
              ('SENSOR', 1),
              ('CÓDEC', 2),
              ('FPS MÁX.', 1),
            ])
              cell(title, flex: flex, style: BiblePointPanel.labelStyle(palette)),
            Expanded(
              flex: 3,
              child: Text('PARA QUÉ', style: BiblePointPanel.labelStyle(palette)),
            ),
          ],
        ),
        for (final m in cam.modes)
          () {
            final index = chosen[m.name.toLowerCase()];
            final on = index != null;
            return Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: palette.divider)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Checkbox(
                      value: on,
                      visualDensity: VisualDensity.compact,
                      onChanged: (v) => onChanged(
                        v == true
                            ? BibleTableValue(
                                columns: columns,
                                rows: [...table.rows, rowOf(m)],
                              )
                            : table.removeRow(index!),
                      ),
                    ),
                  ),
                  cell(
                    m.name,
                    flex: 3,
                    style: AppTypography.bodyMedium(palette).copyWith(
                      color: on ? palette.textPrimary : palette.textSecondary,
                    ),
                  ),
                  cell(m.resolution ?? ''),
                  cell(m.aspectRatio ?? '', flex: 1),
                  cell(
                    m.cropFactor == null
                        ? ''
                        : '${(m.cropFactor! * 100).round()} %',
                    flex: 1,
                    style: mono.copyWith(
                      color: m.crops ? palette.highlightYellow : null,
                    ),
                  ),
                  cell(m.codec ?? ''),
                  cell(m.fpsLabel ?? '', flex: 1),
                  Expanded(
                    flex: 3,
                    child: on
                        ? TextFormField(
                            key: ValueKey('matrix_use_${m.name}'),
                            initialValue: table.rows[index].last,
                            style: AppTypography.bodyMedium(palette),
                            decoration: InputDecoration(
                              hintText: 'Principal, cámara lenta…',
                              hintStyle: caption,
                              isDense: true,
                              filled: false,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 6,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                            onChanged: (text) => onChanged(
                              table.withCell(index, columns.length - 1, text),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            );
          }(),
        if (cam.modes.every((m) => m.codec == null && m.fpsMax == null))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'El catálogo no tiene el códec ni los fps de esta cámara: '
              'faltan en el Excel.',
              style: caption,
            ),
          ),
      ],
    );
  }
}
