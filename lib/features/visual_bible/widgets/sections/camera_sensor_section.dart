import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../equipment/widgets/equipment_picker.dart';
import '../../bible_section_fields.dart';
import '../../moodboard_helpers.dart';
import '../../visual_bible_model.dart';
import '../bible_form_widgets.dart';
import '../bible_moodboard_image_target.dart';
import 'section_scaffold.dart';

/// Cámara y sensor — layout Stitch (A-Cam + ISO + codec + DIT + refs).
class CameraSensorSection extends ConsumerWidget {
  final VisualBibleData data;
  final int projectId;
  final String? sectionContentJson;
  final BibleChanged onChanged;

  const CameraSensorSection({
    super.key,
    required this.data,
    required this.projectId,
    this.sectionContentJson,
    required this.onChanged,
  });

  Map<String, dynamic> _getCustom() {
    if (sectionContentJson == null || sectionContentJson!.isEmpty) return {};
    try {
      final decoded = jsonDecode(sectionContentJson!);
      if (decoded is! Map<String, dynamic>) return {};
      final valuesRaw = decoded['values'] ?? decoded['_values'];
      if (valuesRaw is Map) {
        final vals = Map<String, dynamic>.from(valuesRaw);
        if (vals['cameraData'] is String) {
          final parsed = jsonDecode(vals['cameraData'] as String);
          if (parsed is Map<String, dynamic>) return parsed;
        }
        return vals;
      }
    } catch (_) {}
    return {};
  }

  Future<void> _updateCustom(
    WidgetRef ref,
    Map<String, dynamic> update,
  ) async {
    final current = _getCustom();
    final newData = {...current, ...update};
    final db = ref.read(databaseProvider);
    final def = await (db.select(db.bibleSectionDefinitions)
          ..where(
            (d) =>
                d.bibleId.equals(data.id) &
                d.id.equals(BibleSectionId.camera),
          ))
        .getSingleOrNull();
    if (def == null) return;
    final fields = BibleSectionFieldsConfig.parse(
      def.contentJson,
      BibleSectionId.camera,
    );
    final values = BibleSectionFieldsConfig.parseValues(def.contentJson);
    values['cameraData'] = jsonEncode(newData);
    await db.upsertBibleSectionDefinition(
      def.copyWith(
        contentJson: drift.Value(
          BibleSectionFieldsConfig.encode(fields, values: values),
        ),
      ),
    );
  }

  List<Map<String, String>> _kvList(dynamic raw) {
    if (raw is! List) return [];
    return raw.map((e) {
      if (e is Map) {
        return {
          'label': e['label']?.toString() ?? '',
          'value': e['value']?.toString() ?? '',
        };
      }
      return {'label': e.toString(), 'value': ''};
    }).toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);
    final custom = _getCustom();

    final isoNote = custom['isoNote'] as String? ?? 'Base. Usar 3200 p/ noche ext.';
    final shutter = custom['shutterAngle'] as String? ?? '180°';
    final slowMo = custom['slowMoMax'] as String? ?? '40 fps';
    final colorSpace = custom['colorSpace'] as String? ??
        data.colorScienceNotes ??
        'LogC4 / ARRI Wide Gamut';
    final sensorLabel = custom['sensorLabel'] as String? ?? '';
    final mountLabel = custom['mountLabel'] as String? ?? '';
    final dynamicRange = custom['dynamicRange'] as String? ?? '';
    final bitDepth = custom['bitDepth'] as String? ?? '16';
    final pipeline = custom['pipeline'] as String? ?? 'ACES 1.3';
    final gamut = custom['gamut'] as String? ?? 'ARRI Wide Gamut 4';
    final noiseFloor = custom['noiseFloor'] as String? ?? '-65dB SNR';
    final dualIso = custom['dualIso'] as String? ?? '800 / 3200';
    final showLut =
        custom['showLut'] as String? ?? data.creativeLutName ?? 'Show LUT';
    final idt = custom['idt'] as String? ?? 'IDT';
    final setPreview =
        custom['setPreview'] as String? ?? 'Rec.709 ODT';

    final filters = _kvList(custom['filters']).isEmpty
        ? [
            {'label': 'ND IR FSND', 'value': '0.3 - 2.1'},
            {'label': 'Polarizador', 'value': 'RotaPola 138mm'},
            {'label': 'Difusión', 'value': 'Black Pro-Mist 1/8, 1/4'},
          ]
        : _kvList(custom['filters']);
    final media = _kvList(custom['media']).isEmpty
        ? [
            {'label': 'Tarjetas', 'value': 'Codex Compact Drive 2TB'},
            {'label': 'Lectores', 'value': 'Codex Reader (TB3)'},
            {'label': 'Ratio Offload', 'value': '3:1 (A) · 2:1 (B)'},
          ]
        : _kvList(custom['media']);
    final essentials = _kvList(custom['essentials']).isEmpty
        ? [
            {'label': 'Baterías', 'value': 'B-Mount 290Wh (x8)'},
            {'label': 'Rigging', 'value': 'ARRI SAM-4'},
            {'label': 'Cables', 'value': 'SDI 12G, LBUS'},
          ]
        : _kvList(custom['essentials']);

    final ditFlow = custom['ditFlow'] as String? ??
        data.workflowPipeline ??
        'Silverstack Lab / LiveGrade';
    final ditFlowNote = custom['ditFlowNote'] as String? ??
        'CDL en set, proxies ProRes 422 LT (Rec709) para editorial.';
    final transferProto =
        custom['transferProto'] as String? ?? 'Checksum xxHash64';
    final transferNote = custom['transferNote'] as String? ??
        'Verificación bit a bit. Formato solo con confirmación 3:2:1.';
    final backups = (custom['backups'] as List?)?.map((e) => e.toString()).toList() ??
        [
          '1x RAID 5 (Set)',
          '1x RAID 5 (Oficina)',
          '1x LTO-8 (Archivo)',
        ];

    return BibleSectionScaffold(
      sectionId: BibleSectionId.camera,
      projectId: projectId,
      data: data,
      onChanged: onChanged,
      sectionContentJson: sectionContentJson,
      narrativeHint:
          '¿Por qué esta cámara y sensor? Qué queremos contar con este formato…',
      sectionNumber: null,
      sectionTitle: 'Cámara y sensor',
      fieldWidgets: {
        'narrative': Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cámara y sensor',
              style: AppTypography.displayMedium(palette).copyWith(
                fontSize: 40,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 12),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 16),
            Text(
              'Especificaciones técnicas y decisiones creativas respecto al equipo de captura primario y secundario.',
              style: AppTypography.bodyMedium(palette).copyWith(
                fontSize: 16,
                color: palette.textSecondary,
              ),
            ),
            const SizedBox(height: 28),
            LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 800;
                final quote = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'INTENCIÓN NARRATIVA',
                      style: AppTypography.label(palette).copyWith(
                        color: palette.accent,
                        letterSpacing: 2,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 16),
                    BibleTextField(
                      label: '',
                      hint:
                          '"Buscamos una textura orgánica… Large Format…"',
                      maxLines: 6,
                      initialValue: data.cameraNarrativeIntent ?? '',
                      onChanged: (v) {
                        data.cameraNarrativeIntent = v;
                        onChanged(data);
                      },
                    ),
                  ],
                );
                final image = _EditorialRef(
                  projectId: projectId,
                  bibleId: data.id,
                  palette: palette,
                  caption: custom['editorialCaption'] as String? ?? 'EXT. NIGHT',
                  onEditCaption: () async {
                    final ctrl = TextEditingController(
                      text: custom['editorialCaption']?.toString() ?? 'EXT. NIGHT',
                    );
                    final v = await _prompt(context, 'Caption', ctrl);
                    if (v != null) {
                      await _updateCustom(ref, {'editorialCaption': v});
                    }
                  },
                );
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: quote),
                      const SizedBox(width: 32),
                      Expanded(child: image),
                    ],
                  );
                }
                return Column(
                  children: [
                    quote,
                    const SizedBox(height: 20),
                    image,
                  ],
                );
              },
            ),
          ],
        ),
        'cameraBody': StreamBuilder<List<Camera>>(
          stream: db.watchAllCameras(),
          builder: (context, snap) {
            final cameras = snap.data ?? [];
            Camera? selected;
            if (data.primaryCameraId != null) {
              for (final c in cameras) {
                if (c.id == data.primaryCameraId) {
                  selected = c;
                  break;
                }
              }
            }
            final camName = selected != null
                ? '${selected.brand} ${selected.model}'
                : 'Seleccionar cámara…';
            final sensor = sensorLabel.isNotEmpty
                ? sensorLabel
                : (selected != null
                    ? '${selected.sensorWidthMm.toStringAsFixed(1)}×${selected.sensorHeightMm.toStringAsFixed(1)} mm'
                    : '—');
            final mount = mountLabel.isNotEmpty
                ? mountLabel
                : (selected?.mountType ?? '—');
            final range = dynamicRange.isNotEmpty
                ? dynamicRange
                : (selected?.dynamicRangeStops != null
                    ? '${selected!.dynamicRangeStops!.toStringAsFixed(0)}+ Stops'
                    : '14+ Stops');

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, c) {
                    final wide = c.maxWidth >= 720;
                    final aCam = _GlassCard(
                      child: InkWell(
                        onTap: () => _editPrimaryCamera(
                          context,
                          ref,
                          cameras,
                          sensor: sensor,
                          mount: mount,
                          range: range,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'CÁMARA PRINCIPAL (A-CAM)',
                                        style: AppTypography.label(palette)
                                            .copyWith(
                                          fontSize: 11,
                                          letterSpacing: 1.2,
                                          color: palette.textTertiary,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        camName,
                                        style: AppTypography.displayMedium(
                                          palette,
                                        ).copyWith(fontSize: 28),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.videocam_outlined,
                                  size: 40,
                                  color: palette.accent.withValues(alpha: 0.45),
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),
                            Row(
                              children: [
                                Expanded(
                                  child: _SpecCol(
                                    label: 'Sensor',
                                    value: sensor,
                                    accent: true,
                                    palette: palette,
                                  ),
                                ),
                                Expanded(
                                  child: _SpecCol(
                                    label: 'Montura',
                                    value: mount,
                                    palette: palette,
                                  ),
                                ),
                                Expanded(
                                  child: _SpecCol(
                                    label: 'Rango Dinámico',
                                    value: range,
                                    palette: palette,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            EquipmentPicker(
                              projectId: projectId,
                              equipmentType: 'camera',
                              label: 'Cambiar A-Cam',
                              selectedId: data.primaryCameraId,
                              onSelected: (id) {
                                final cam =
                                    cameras.where((c) => c.id == id).firstOrNull;
                                data.primaryCameraId = id;
                                if (cam != null) {
                                  data.nativeIso ??= cam.nativeIso;
                                  data.colorScienceNotes ??= cam.colorScience;
                                }
                                onChanged(data);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                    final iso = _GlassCard(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'ISO NATIVO',
                            style: AppTypography.label(palette).copyWith(
                              fontSize: 11,
                              letterSpacing: 1.2,
                              color: palette.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onHorizontalDragUpdate: (d) {
                              final cur = data.nativeIso ?? 800;
                              final next = (cur + (d.delta.dx / 4).round())
                                  .clamp(100, 12800);
                              data.nativeIso = next;
                              onChanged(data);
                            },
                            onTap: () async {
                              final ctrl = TextEditingController(
                                text: '${data.nativeIso ?? 800}',
                              );
                              final v = await _prompt(context, 'ISO nativo', ctrl);
                              final n = int.tryParse(
                                v?.replaceAll(RegExp(r'[^0-9]'), '') ?? '',
                              );
                              if (n != null) {
                                data.nativeIso = n;
                                onChanged(data);
                              }
                            },
                            child: Text(
                              '${data.nativeIso ?? 800}',
                              style: AppTypography.mono(palette).copyWith(
                                fontSize: 56,
                                fontWeight: FontWeight.w500,
                                height: 1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () async {
                              final ctrl = TextEditingController(text: isoNote);
                              final v = await _prompt(context, 'Nota ISO', ctrl);
                              if (v != null) {
                                await _updateCustom(ref, {'isoNote': v});
                              }
                            },
                            child: Text(
                              isoNote,
                              textAlign: TextAlign.center,
                              style: AppTypography.mono(palette).copyWith(
                                fontSize: 12,
                                color: palette.textTertiary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 8, child: aCam),
                          const SizedBox(width: 16),
                          Expanded(flex: 4, child: iso),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        aCam,
                        const SizedBox(height: 16),
                        iso,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, c) {
                    final wide = c.maxWidth >= 700;
                    final format = _GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _eyebrow('Formato y Codec', palette),
                          const SizedBox(height: 20),
                          _kvRow(
                            'Resolución de captura',
                            data.captureResolution ?? '—',
                            palette,
                            accent: true,
                            onTap: () async {
                              final ctrl = TextEditingController(
                                text: data.captureResolution ?? '',
                              );
                              final v = await _prompt(
                                context,
                                'Resolución',
                                ctrl,
                              );
                              if (v == null) return;
                              data.captureResolution =
                                  v.isEmpty ? null : v;
                              onChanged(data);
                            },
                          ),
                          _kvRow(
                            'Codec',
                            data.codec ?? data.recordingFormat ?? '—',
                            palette,
                            onTap: () async {
                              final ctrl = TextEditingController(
                                text: data.codec ?? '',
                              );
                              final v =
                                  await _prompt(context, 'Codec', ctrl);
                              if (v == null) return;
                              data.codec = v.isEmpty ? null : v;
                              onChanged(data);
                            },
                          ),
                          _kvRow(
                            'Espacio de color',
                            colorSpace,
                            palette,
                            last: true,
                            onTap: () async {
                              final ctrl =
                                  TextEditingController(text: colorSpace);
                              final v = await _prompt(
                                context,
                                'Espacio de color',
                                ctrl,
                              );
                              if (v == null) return;
                              await _updateCustom(ref, {'colorSpace': v});
                              data.colorScienceNotes = v;
                              onChanged(data);
                            },
                          ),
                        ],
                      ),
                    );
                    final cadence = _GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _eyebrow('Cadencia y Obturación', palette),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: _MiniMetric(
                                  label: 'Frame Rate Base',
                                  value: data.frameRateNotes ?? '24 fps',
                                  palette: palette,
                                  onTap: () async {
                                    final ctrl = TextEditingController(
                                      text: data.frameRateNotes ?? '24 fps',
                                    );
                                    final v = await _prompt(
                                      context,
                                      'Frame rate',
                                      ctrl,
                                    );
                                    if (v == null) return;
                                    data.frameRateNotes =
                                        v.isEmpty ? null : v;
                                    onChanged(data);
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _MiniMetric(
                                  label: 'Obturador',
                                  value: shutter,
                                  palette: palette,
                                  onTap: () async {
                                    final ctrl =
                                        TextEditingController(text: shutter);
                                    final v = await _prompt(
                                      context,
                                      'Obturador',
                                      ctrl,
                                    );
                                    if (v != null) {
                                      await _updateCustom(
                                        ref,
                                        {'shutterAngle': v},
                                      );
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _MiniMetric(
                            label: 'Slow Motion Max',
                            value: slowMo,
                            palette: palette,
                            accent: true,
                            wide: true,
                            onTap: () async {
                              final ctrl =
                                  TextEditingController(text: slowMo);
                              final v = await _prompt(
                                context,
                                'Slow motion max',
                                ctrl,
                              );
                              if (v != null) {
                                await _updateCustom(ref, {'slowMoMax': v});
                              }
                            },
                          ),
                        ],
                      ),
                    );
                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: format),
                          const SizedBox(width: 16),
                          Expanded(child: cadence),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        format,
                        const SizedBox(height: 16),
                        cadence,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                // Color science complement
                LayoutBuilder(
                  builder: (context, c) {
                    final wide = c.maxWidth >= 720;
                    final reveal = _GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  data.colorScienceNotes?.isNotEmpty == true
                                      ? data.colorScienceNotes!
                                      : 'Color Science',
                                  style: AppTypography.titleMedium(palette)
                                      .copyWith(fontSize: 18),
                                ),
                              ),
                              Icon(
                                Icons.movie_filter_outlined,
                                color: palette.accent.withValues(alpha: 0.4),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: _SpecCol(
                                  label: 'Pipeline',
                                  value: pipeline,
                                  accent: true,
                                  palette: palette,
                                  onTap: () async {
                                    final ctrl =
                                        TextEditingController(text: pipeline);
                                    final v = await _prompt(
                                      context,
                                      'Pipeline',
                                      ctrl,
                                    );
                                    if (v != null) {
                                      await _updateCustom(
                                        ref,
                                        {'pipeline': v},
                                      );
                                    }
                                  },
                                ),
                              ),
                              Expanded(
                                child: _SpecCol(
                                  label: 'Gamut',
                                  value: gamut,
                                  palette: palette,
                                  onTap: () async {
                                    final ctrl =
                                        TextEditingController(text: gamut);
                                    final v = await _prompt(
                                      context,
                                      'Gamut',
                                      ctrl,
                                    );
                                    if (v != null) {
                                      await _updateCustom(ref, {'gamut': v});
                                    }
                                  },
                                ),
                              ),
                              Expanded(
                                child: _SpecCol(
                                  label: 'Mapeo',
                                  value: colorSpace.split('/').first.trim(),
                                  palette: palette,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                    final bit = _GlassCard(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'BIT DEPTH',
                            style: AppTypography.label(palette).copyWith(
                              fontSize: 11,
                              color: palette.textTertiary,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () async {
                              final ctrl =
                                  TextEditingController(text: bitDepth);
                              final v =
                                  await _prompt(context, 'Bit depth', ctrl);
                              if (v != null) {
                                await _updateCustom(ref, {'bitDepth': v});
                              }
                            },
                            child: Text(
                              bitDepth,
                              style: AppTypography.mono(palette).copyWith(
                                fontSize: 48,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            'Lineal, procesamiento interno',
                            textAlign: TextAlign.center,
                            style: AppTypography.mono(palette).copyWith(
                              fontSize: 11,
                              color: palette.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    );
                    if (wide) {
                      return Row(
                        children: [
                          Expanded(flex: 8, child: reveal),
                          const SizedBox(width: 16),
                          Expanded(flex: 4, child: bit),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        reveal,
                        const SizedBox(height: 16),
                        bit,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, c) {
                    final wide = c.maxWidth >= 700;
                    final analysis = _GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _eyebrow('Análisis de Sensor', palette),
                          const SizedBox(height: 16),
                          _kvRow('Rango Dinámico', range, palette,
                              accent: true),
                          _kvRow('Piso de Ruido', noiseFloor, palette,
                              onTap: () async {
                            final ctrl =
                                TextEditingController(text: noiseFloor);
                            final v =
                                await _prompt(context, 'Piso de ruido', ctrl);
                            if (v != null) {
                              await _updateCustom(ref, {'noiseFloor': v});
                            }
                          }),
                          _kvRow('Dual Native ISO', dualIso, palette,
                              last: true, onTap: () async {
                            final ctrl =
                                TextEditingController(text: dualIso);
                            final v =
                                await _prompt(context, 'Dual ISO', ctrl);
                            if (v != null) {
                              await _updateCustom(ref, {'dualIso': v});
                            }
                          }),
                        ],
                      ),
                    );
                    final luts = _GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _eyebrow('Pipeline de LUTs', palette),
                          const SizedBox(height: 12),
                          _LutMini(
                            label: 'Show LUT',
                            value: showLut,
                            palette: palette,
                            onTap: () async {
                              final ctrl =
                                  TextEditingController(text: showLut);
                              final v =
                                  await _prompt(context, 'Show LUT', ctrl);
                              if (v == null) return;
                              await _updateCustom(ref, {'showLut': v});
                              data.creativeLutName = v;
                              onChanged(data);
                            },
                          ),
                          const SizedBox(height: 8),
                          _LutMini(
                            label: 'IDT',
                            value: idt,
                            palette: palette,
                            onTap: () async {
                              final ctrl = TextEditingController(text: idt);
                              final v = await _prompt(context, 'IDT', ctrl);
                              if (v != null) {
                                await _updateCustom(ref, {'idt': v});
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () async {
                              final ctrl =
                                  TextEditingController(text: setPreview);
                              final v = await _prompt(
                                context,
                                'Preview en set',
                                ctrl,
                              );
                              if (v != null) {
                                await _updateCustom(ref, {'setPreview': v});
                              }
                            },
                            child: Text(
                              'Previsualización: $setPreview',
                              style: AppTypography.mono(palette).copyWith(
                                fontSize: 12,
                                color: palette.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: analysis),
                          const SizedBox(width: 16),
                          Expanded(child: luts),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        analysis,
                        const SizedBox(height: 16),
                        luts,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                _GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _eyebrow('Consumibles y Accesorios', palette),
                      const SizedBox(height: 20),
                      LayoutBuilder(
                        builder: (context, c) {
                          final cols = c.maxWidth >= 700 ? 3 : 1;
                          final sections = [
                            ('Filtros (Matte Box)', filters, 'filters'),
                            ('Media & Almacenamiento', media, 'media'),
                            ('Esenciales de Cámara', essentials, 'essentials'),
                          ];
                          if (cols == 1) {
                            return Column(
                              children: [
                                for (final s in sections) ...[
                                  _ConsumableCol(
                                    title: s.$1,
                                    items: s.$2,
                                    palette: palette,
                                    onEdit: () => _editKvList(
                                      context,
                                      ref,
                                      key: s.$3,
                                      title: s.$1,
                                      items: s.$2,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                ],
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (var i = 0; i < sections.length; i++) ...[
                                if (i > 0) const SizedBox(width: 24),
                                Expanded(
                                  child: _ConsumableCol(
                                    title: sections[i].$1,
                                    items: sections[i].$2,
                                    palette: palette,
                                    onEdit: () => _editKvList(
                                      context,
                                      ref,
                                      key: sections[i].$3,
                                      title: sections[i].$1,
                                      items: sections[i].$2,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _eyebrow('Gestión de Media (DIT / Data)', palette),
                      const SizedBox(height: 20),
                      LayoutBuilder(
                        builder: (context, c) {
                          final wide = c.maxWidth >= 700;
                          final cards = [
                            _DitTile(
                              label: 'Flujo DIT',
                              title: ditFlow,
                              body: ditFlowNote,
                              palette: palette,
                              onTap: () async {
                                final t =
                                    TextEditingController(text: ditFlow);
                                final n =
                                    TextEditingController(text: ditFlowNote);
                                final ok = await _promptPair(
                                  context,
                                  'Flujo DIT',
                                  t,
                                  n,
                                );
                                if (ok != true) return;
                                await _updateCustom(ref, {
                                  'ditFlow': t.text.trim(),
                                  'ditFlowNote': n.text.trim(),
                                });
                                data.workflowPipeline = t.text.trim();
                                onChanged(data);
                              },
                            ),
                            _DitTile(
                              label: 'Protocolo de Transferencia',
                              title: transferProto,
                              body: transferNote,
                              palette: palette,
                              onTap: () async {
                                final t = TextEditingController(
                                  text: transferProto,
                                );
                                final n = TextEditingController(
                                  text: transferNote,
                                );
                                final ok = await _promptPair(
                                  context,
                                  'Transferencia',
                                  t,
                                  n,
                                );
                                if (ok != true) return;
                                await _updateCustom(ref, {
                                  'transferProto': t.text.trim(),
                                  'transferNote': n.text.trim(),
                                });
                              },
                            ),
                            _BackupTile(
                              backups: backups,
                              palette: palette,
                              onEdit: () async {
                                final ctrl = TextEditingController(
                                  text: backups.join('\n'),
                                );
                                final v = await _prompt(
                                  context,
                                  'Backups (una por línea)',
                                  ctrl,
                                  maxLines: 5,
                                );
                                if (v == null) return;
                                await _updateCustom(ref, {
                                  'backups': v
                                      .split('\n')
                                      .map((e) => e.trim())
                                      .where((e) => e.isNotEmpty)
                                      .toList(),
                                });
                              },
                            ),
                          ];
                          if (wide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (var i = 0; i < cards.length; i++) ...[
                                  if (i > 0) const SizedBox(width: 12),
                                  Expanded(child: cards[i]),
                                ],
                              ],
                            );
                          }
                          return Column(
                            children: [
                              for (final card in cards) ...[
                                card,
                                const SizedBox(height: 12),
                              ],
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        'philosophy': BibleTextField(
          label: 'Filosofía de cámara',
          hint: '¿La cámara observa o participa?',
          maxLines: 3,
          initialValue: data.cameraPhilosophy ?? '',
          onChanged: (v) {
            data.cameraPhilosophy = v.isEmpty ? null : v;
            onChanged(data);
          },
        ),
        'movements': _CameraMovements(data: data, onChanged: onChanged),
        'specsReference': _TechRefs(
          projectId: projectId,
          bibleId: data.id,
          palette: palette,
        ),
      },
    );
  }

  Future<void> _editPrimaryCamera(
    BuildContext context,
    WidgetRef ref,
    List<Camera> cameras, {
    required String sensor,
    required String mount,
    required String range,
  }) async {
    final sensorC = TextEditingController(text: sensor);
    final mountC = TextEditingController(text: mount);
    final rangeC = TextEditingController(text: range);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('A-Cam specs'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: sensorC,
              decoration: const InputDecoration(labelText: 'Sensor'),
            ),
            TextField(
              controller: mountC,
              decoration: const InputDecoration(labelText: 'Montura'),
            ),
            TextField(
              controller: rangeC,
              decoration: const InputDecoration(labelText: 'Rango dinámico'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _updateCustom(ref, {
      'sensorLabel': sensorC.text.trim(),
      'mountLabel': mountC.text.trim(),
      'dynamicRange': rangeC.text.trim(),
    });
  }

  Future<void> _editKvList(
    BuildContext context,
    WidgetRef ref, {
    required String key,
    required String title,
    required List<Map<String, String>> items,
  }) async {
    final lines = items
        .map((e) => '${e['label']}|${e['value']}')
        .join('\n');
    final ctrl = TextEditingController(text: lines);
    final v = await _prompt(
      context,
      '$title (label|valor por línea)',
      ctrl,
      maxLines: 8,
    );
    if (v == null) return;
    final parsed = v
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map((e) {
          final parts = e.split('|');
          return {
            'label': parts.first.trim(),
            'value': parts.length > 1 ? parts.sublist(1).join('|').trim() : '',
          };
        })
        .toList();
    await _updateCustom(ref, {key: parsed});
  }

  static Future<String?> _prompt(
    BuildContext context,
    String title,
    TextEditingController c, {
    int maxLines = 1,
  }) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLines: maxLines,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  static Future<bool?> _promptPair(
    BuildContext context,
    String title,
    TextEditingController a,
    TextEditingController b,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: a,
              decoration: const InputDecoration(labelText: 'Título'),
            ),
            TextField(
              controller: b,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notas'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Widget _eyebrow(String text, AppPalette palette) {
    return Text(
      text.toUpperCase(),
      style: AppTypography.label(palette).copyWith(
        fontSize: 11,
        letterSpacing: 1.2,
        color: palette.textTertiary,
      ),
    );
  }

  Widget _kvRow(
    String label,
    String value,
    AppPalette palette, {
    bool accent = false,
    bool last = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(bottom: 14, top: 4),
        decoration: last
            ? null
            : BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTypography.bodyMedium(palette).copyWith(
                  color: palette.textPrimary.withValues(alpha: 0.9),
                ),
              ),
            ),
            Text(
              value,
              style: AppTypography.mono(palette).copyWith(
                fontSize: 13,
                color: accent ? palette.accent : palette.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }
}

class _SpecCol extends StatelessWidget {
  final String label;
  final String value;
  final AppPalette palette;
  final bool accent;
  final VoidCallback? onTap;

  const _SpecCol({
    required this.label,
    required this.value,
    required this.palette,
    this.accent = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTypography.label(palette).copyWith(
              fontSize: 10,
              letterSpacing: 1,
              color: palette.textTertiary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTypography.mono(palette).copyWith(
              fontSize: 13,
              color: accent ? palette.accent : palette.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;
  final AppPalette palette;
  final VoidCallback onTap;
  final bool accent;
  final bool wide;

  const _MiniMetric({
    required this.label,
    required this.value,
    required this.palette,
    required this.onTap,
    this.accent = false,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1C),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: wide
            ? Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: AppTypography.bodyMedium(palette).copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    value,
                    style: AppTypography.mono(palette).copyWith(
                      fontSize: 18,
                      color: accent ? palette.accent : palette.textPrimary,
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: AppTypography.label(palette).copyWith(
                      fontSize: 10,
                      color: palette.textTertiary.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    value,
                    style: AppTypography.mono(palette).copyWith(fontSize: 22),
                  ),
                ],
              ),
      ),
    );
  }
}

class _LutMini extends StatelessWidget {
  final String label;
  final String value;
  final AppPalette palette;
  final VoidCallback onTap;

  const _LutMini({
    required this.label,
    required this.value,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1C),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: AppTypography.label(palette).copyWith(
                fontSize: 9,
                color: palette.textTertiary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTypography.mono(palette).copyWith(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsumableCol extends StatelessWidget {
  final String title;
  final List<Map<String, String>> items;
  final AppPalette palette;
  final VoidCallback onEdit;

  const _ConsumableCol({
    required this.title,
    required this.items,
    required this.palette,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            child: Text(
              title,
              style: AppTypography.bodyMedium(palette).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item['label'] ?? '',
                      style: AppTypography.bodyMedium(palette).copyWith(
                        fontSize: 13,
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    item['value'] ?? '',
                    style: AppTypography.mono(palette).copyWith(
                      fontSize: 12,
                      color: palette.accent,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DitTile extends StatelessWidget {
  final String label;
  final String title;
  final String body;
  final AppPalette palette;
  final VoidCallback onTap;

  const _DitTile({
    required this.label,
    required this.title,
    required this.body,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1C),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: AppTypography.label(palette).copyWith(
                fontSize: 10,
                color: palette.textTertiary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: AppTypography.mono(palette).copyWith(fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: AppTypography.bodyMedium(palette).copyWith(
                fontSize: 13,
                color: palette.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackupTile extends StatelessWidget {
  final List<String> backups;
  final AppPalette palette;
  final VoidCallback onEdit;

  const _BackupTile({
    required this.backups,
    required this.palette,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1C),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ESTRATEGIA DE BACKUP (3:2:1)',
              style: AppTypography.label(palette).copyWith(
                fontSize: 10,
                color: palette.textTertiary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),
            for (final b in backups)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.dns_outlined, size: 16, color: palette.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        b,
                        style: AppTypography.mono(palette).copyWith(
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EditorialRef extends ConsumerWidget {
  final int projectId;
  final int bibleId;
  final AppPalette palette;
  final String caption;
  final VoidCallback onEditCaption;

  const _EditorialRef({
    required this.projectId,
    required this.bibleId,
    required this.palette,
    required this.caption,
    required this.onEditCaption,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    return StreamBuilder<List<MoodboardImage>>(
      stream: db.watchMoodboardImagesForSection(
        projectId,
        BibleSectionId.camera,
      ),
      builder: (context, snap) {
        final imgs = snap.data ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BibleMoodboardImageTarget(
              projectId: projectId,
              sectionId: BibleSectionId.camera,
              bibleId: bibleId,
              hint: 'Clic aquí → ⌘V para pegar hero de cámara',
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (imgs.isNotEmpty &&
                          File(imgs.first.imagePath).existsSync())
                        Image.file(
                          File(imgs.first.imagePath),
                          fit: BoxFit.cover,
                        )
                      else
                        ColoredBox(
                          color: palette.surfaceOverlay,
                          child: Icon(
                            Icons.image_outlined,
                            size: 48,
                            color: palette.textTertiary,
                          ),
                        ),
                      Positioned(
                        left: 12,
                        bottom: 12,
                        child: InkWell(
                          onTap: onEditCaption,
                          child: Text(
                            '— ${caption.toUpperCase()}',
                            style: AppTypography.mono(palette).copyWith(
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                await MoodboardHelpers.addManualImages(
                  db: db,
                  projectId: projectId,
                  bibleId: bibleId,
                  category: MoodboardCategory.reference,
                  assignedSections: [BibleSectionId.camera],
                );
              },
              icon: Icon(Icons.add_photo_alternate_outlined,
                  size: 16, color: palette.accent),
              label: Text(
                'Añadir imagen',
                style: TextStyle(color: palette.accent, fontSize: 12),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TechRefs extends ConsumerWidget {
  final int projectId;
  final int bibleId;
  final AppPalette palette;

  const _TechRefs({
    required this.projectId,
    required this.bibleId,
    required this.palette,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
          ),
          child: Text(
            'IMÁGENES DE REFERENCIA TÉCNICA',
            style: AppTypography.label(palette).copyWith(
              fontSize: 11,
              letterSpacing: 2,
              color: palette.textTertiary,
            ),
          ),
        ),
        const SizedBox(height: 20),
        StreamBuilder<List<MoodboardImage>>(
          stream: db.watchMoodboardImagesForSection(
            projectId,
            BibleSectionId.camera,
          ),
          builder: (context, snap) {
            final imgs = snap.data ?? [];
            return LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 640;
                final a = _refSlot(
                  image: imgs.isNotEmpty ? imgs.first : null,
                  label: 'REF: SETUP TÉCNICO A-CAM',
                  hint: 'Configuración de cámara principal en set.',
                  empty: false,
                  onAdd: () => MoodboardHelpers.addManualImages(
                    db: db,
                    projectId: projectId,
                    bibleId: bibleId,
                    category: MoodboardCategory.reference,
                  assignedSections: [BibleSectionId.camera],
                  ),
                );
                final b = _refSlot(
                  image: imgs.length > 1 ? imgs[1] : null,
                  label: 'REF: SEGUNDA UNIDAD',
                  hint: 'Espacio para B-Cam y rigs especiales.',
                  empty: imgs.length < 2,
                  onAdd: () => MoodboardHelpers.addManualImages(
                    db: db,
                    projectId: projectId,
                    bibleId: bibleId,
                    category: MoodboardCategory.reference,
                  assignedSections: [BibleSectionId.camera],
                  ),
                );
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: a),
                      const SizedBox(width: 32),
                      Expanded(child: b),
                    ],
                  );
                }
                return Column(
                  children: [
                    a,
                    const SizedBox(height: 24),
                    b,
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _refSlot({
    required MoodboardImage? image,
    required String label,
    required String hint,
    required bool empty,
    required VoidCallback onAdd,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: empty || image == null
              ? InkWell(
                  onTap: onAdd,
                  child: CustomPaint(
                    painter: _DashPainter(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 40,
                            color: palette.accent.withValues(alpha: 0.35),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'AÑADIR REFERENCIA B-CAM',
                            style: AppTypography.label(palette).copyWith(
                              fontSize: 10,
                              letterSpacing: 1.5,
                              color: palette.accent.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.file(
                    File(image.imagePath),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        ColoredBox(color: palette.surfaceOverlay),
                  ),
                ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: AppTypography.label(palette).copyWith(
            fontSize: 11,
            letterSpacing: 1.2,
            color: empty ? palette.textTertiary : palette.accent,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          hint,
          style: AppTypography.bodyMedium(palette).copyWith(
            fontSize: 13,
            color: palette.textSecondary.withValues(alpha: 0.8),
            fontStyle: empty ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ],
    );
  }
}

class _DashPainter extends CustomPainter {
  final Color color;
  _DashPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const dash = 6.0;
    const gap = 4.0;
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(4),
    );
    final path = Path()..addRRect(r);
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        final n = (d + dash).clamp(0.0, m.length);
        canvas.drawPath(m.extractPath(d, n), paint);
        d = n + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _CameraMovements extends StatelessWidget {
  final VisualBibleData data;
  final BibleChanged onChanged;

  const _CameraMovements({required this.data, required this.onChanged});

  static const _options = [
    'Estático',
    'Dolly',
    'Steadicam',
    'Mano',
    'Grúa',
    'Zoom',
    'Observacional',
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'MOVIMIENTOS DE CÁMARA',
                  style: AppTypography.label(palette).copyWith(
                    fontSize: 11,
                    letterSpacing: 1.2,
                    color: palette.textTertiary,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  data.cameraMovements.add({
                    'movement': 'Dolly',
                    'narrative': '',
                    'reference': '',
                  });
                  onChanged(data);
                },
                icon: Icon(Icons.add, size: 16, color: palette.accent),
                label: Text('Añadir', style: TextStyle(color: palette.accent)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          BibleDropdown(
            label: 'Estilo general',
            options: const ['Estático', 'Observacional', 'Participativo', 'Mixto'],
            value: data.movementStyle,
            onChanged: (v) {
              data.movementStyle = v;
              onChanged(data);
            },
          ),
          const SizedBox(height: 12),
          ...data.cameraMovements.asMap().entries.map((entry) {
            final i = entry.key;
            final mov = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1C),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: BibleDropdown(
                            label: 'Movimiento',
                            options: _options,
                            value: mov['movement'],
                            onChanged: (v) {
                              mov['movement'] = v ?? '';
                              onChanged(data);
                            },
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: palette.error),
                          onPressed: () {
                            data.cameraMovements.removeAt(i);
                            onChanged(data);
                          },
                        ),
                      ],
                    ),
                    BibleTextField(
                      label: 'Intención narrativa',
                      maxLines: 2,
                      initialValue: mov['narrative'],
                      onChanged: (v) {
                        mov['narrative'] = v;
                        onChanged(data);
                      },
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
