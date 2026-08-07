import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../bible_section_fields.dart';
import '../../moodboard_helpers.dart';
import '../../visual_bible_model.dart';
import 'section_scaffold.dart';

/// Aspect Ratio — layout Stitch (logic HUD + frame preview + intent).
class FormatSection extends ConsumerWidget {
  final VisualBibleData data;
  final int projectId;
  final String? sectionContentJson;
  final BibleChanged onChanged;

  const FormatSection({
    super.key,
    required this.data,
    required this.projectId,
    this.sectionContentJson,
    required this.onChanged,
  });

  Map<String, dynamic> _getCustomData() {
    if (sectionContentJson == null || sectionContentJson!.isEmpty) return {};
    try {
      final decoded = jsonDecode(sectionContentJson!);
      if (decoded is! Map<String, dynamic>) return {};
      final valuesRaw = decoded['values'] ?? decoded['_values'];
      if (valuesRaw is Map) {
        final vals = Map<String, dynamic>.from(valuesRaw);
        if (vals['formatData'] is String) {
          final parsed = jsonDecode(vals['formatData'] as String);
          if (parsed is Map<String, dynamic>) return parsed;
        }
        return vals;
      }
    } catch (_) {}
    return {};
  }

  Future<void> _updateCustomData(
    WidgetRef ref,
    Map<String, dynamic> update,
  ) async {
    final current = _getCustomData();
    final newData = {...current, ...update};
    final db = ref.read(databaseProvider);
    final def = await (db.select(db.bibleSectionDefinitions)
          ..where(
            (d) =>
                d.bibleId.equals(data.id) & d.id.equals(BibleSectionId.format),
          ))
        .getSingleOrNull();
    if (def == null) return;
    final fields = BibleSectionFieldsConfig.parse(
      def.contentJson,
      BibleSectionId.format,
    );
    final values = BibleSectionFieldsConfig.parseValues(def.contentJson);
    values['formatData'] = jsonEncode(newData);
    await db.upsertBibleSectionDefinition(
      def.copyWith(
        contentJson: drift.Value(
          BibleSectionFieldsConfig.encode(fields, values: values),
        ),
      ),
    );
  }

  /// Parsea "4:3" → 1.333, "16:9" → 1.778
  double? _parseRatio(String? raw) {
    if (raw == null) return null;
    final m = RegExp(r'(\d+(?:\.\d+)?)\s*[:/x×]\s*(\d+(?:\.\d+)?)')
        .firstMatch(raw.replaceAll(',', '.'));
    if (m == null) return null;
    final a = double.tryParse(m.group(1)!);
    final b = double.tryParse(m.group(2)!);
    if (a == null || b == null || b == 0) return null;
    return a / b;
  }

  double? _parseSqueeze(String? raw) {
    if (raw == null) return null;
    final m = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(raw);
    return m != null ? double.tryParse(m.group(1)!) : null;
  }

  String _formatRatio(double r) {
    // Common cinema ratios
    final known = <(double, String)>[
      (2.39, '2.39:1'),
      (2.40, '2.40:1'),
      (2.35, '2.35:1'),
      (1.85, '1.85:1'),
      (1.78, '1.78:1'),
      (1.66, '1.66:1'),
      (1.33, '1.33:1'),
      (1.0, '1:1'),
    ];
    for (final e in known) {
      if ((r - e.$1).abs() < 0.02) return e.$2;
    }
    return '${r.toStringAsFixed(2)}:1';
  }

  String _ratioLabel(String ratio) {
    if (ratio.contains('2.39') || ratio.contains('2.40')) {
      return 'Widescreen Cinemascope';
    }
    if (ratio.contains('1.85')) return 'Flat Theatrical';
    if (ratio.contains('1.78') || ratio.contains('16:9')) return 'HD / Broadcast';
    if (ratio.contains('1.33') || ratio.contains('4:3')) return 'Academy / Vintage';
    return 'Custom Format';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);
    final custom = _getCustomData();

    final sensorMode = custom['sensorMode'] as String? ?? '4:3';
    final sensorDetail =
        custom['sensorDetail'] as String? ?? 'Open Gate (2.8K)';
    final squeezeFactor = custom['squeezeFactor'] as String? ?? '2.0x';
    final squeezeDetail =
        custom['squeezeDetail'] as String? ?? 'Anamorphic S35';
    final ratioName =
        custom['ratioName'] as String? ?? _ratioLabel(data.aspectRatio ?? '');

    final sensorR = _parseRatio(sensorMode) ?? 4 / 3;
    final squeeze = _parseSqueeze(squeezeFactor) ?? 2.0;
    final calculated = sensorR * squeeze;
    final activeRatio = custom['activeRatio'] as String? ??
        data.aspectRatio ??
        _formatRatio(calculated);

    final intentNarrative = custom['intentNarrative'] as String? ??
        data.formatNarrativeIntent ??
        data.aspectRatioJustification ??
        '';
    final intentComposition = custom['intentComposition'] as String? ?? '';
    final intentReinforce = custom['intentReinforce'] as String? ?? '';

    final overlayCam =
        custom['overlayCam'] as String? ?? 'ARRI 35 | 40MM ANAMORPHIC';
    final imageCircle = custom['imageCircle'] as String? ?? '';
    final cropFactor = custom['cropFactor'] as String? ?? '';
    final resolutionOverride = custom['resolution'] as String? ?? '';
    final sensorDimsOverride = custom['sensorDims'] as String? ?? '';

    return BibleSectionScaffold(
      sectionId: BibleSectionId.format,
      projectId: projectId,
      data: data,
      onChanged: onChanged,
      sectionContentJson: sectionContentJson,
      narrativeHint:
          '¿Cómo afecta el encuadre a la relación del personaje con el espacio?',
      sectionNumber: null,
      sectionTitle: 'Aspect Ratio',
      fieldWidgets: {
        'narrative': Text(
          'Cámara, Sensor & Aspect Ratio',
          style: AppTypography.displayMedium(palette).copyWith(
            fontSize: 32,
            letterSpacing: -0.6,
          ),
        ),
        'formatSettings': StreamBuilder<List<Camera>>(
          stream: db.watchAllCameras(),
          builder: (context, snap) {
            final cameras = snap.data ?? [];
            Camera? cam;
            if (data.primaryCameraId != null) {
              for (final c in cameras) {
                if (c.id == data.primaryCameraId) {
                  cam = c;
                  break;
                }
              }
            }

            final body = cam != null
                ? '${cam.brand} ${cam.model}'
                : (custom['cameraBody'] as String? ?? '—');
            final mount = cam?.mountType ??
                (custom['lensMount'] as String? ?? '—');
            final sensorDims = sensorDimsOverride.isNotEmpty
                ? sensorDimsOverride
                : (cam != null
                    ? '${cam.sensorWidthMm.toStringAsFixed(2)} × ${cam.sensorHeightMm.toStringAsFixed(2)} mm'
                    : '—');
            final resolution = resolutionOverride.isNotEmpty
                ? resolutionOverride
                : (data.captureResolution ?? '—');
            final circle = imageCircle.isNotEmpty
                ? imageCircle
                : (cam != null
                    ? '${math.sqrt(cam.sensorWidthMm * cam.sensorWidthMm + cam.sensorHeightMm * cam.sensorHeightMm).toStringAsFixed(2)} mm'
                    : '—');
            final crop = cropFactor.isNotEmpty
                ? cropFactor
                : (cam != null
                    ? '${(43.3 / math.sqrt(cam.sensorWidthMm * cam.sensorWidthMm + cam.sensorHeightMm * cam.sensorHeightMm)).toStringAsFixed(2)}x'
                    : '—');

            return LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 1000;

                final logicCard = _GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.analytics_outlined,
                              size: 16, color: palette.accent),
                          const SizedBox(width: 8),
                          Text(
                            'SENSOR & OPTICS LOGIC',
                            style: AppTypography.label(palette).copyWith(
                              fontSize: 11,
                              letterSpacing: 1.5,
                              color: palette.textTertiary,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: palette.surfaceElevated,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                            ),
                            child: Text(
                              'ACTIVE',
                              style: AppTypography.mono(palette).copyWith(
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _LogicTile(
                              eyebrow: 'SENSOR MODE',
                              title: sensorMode,
                              detail: sensorDetail,
                              palette: palette,
                              onTap: () async {
                                final t =
                                    TextEditingController(text: sensorMode);
                                final d =
                                    TextEditingController(text: sensorDetail);
                                final ok = await _promptPair(
                                  context,
                                  'Sensor Mode',
                                  t,
                                  d,
                                  aLabel: 'Ratio (4:3)',
                                  bLabel: 'Detalle',
                                );
                                if (ok != true) return;
                                await _updateCustomData(ref, {
                                  'sensorMode': t.text.trim(),
                                  'sensorDetail': d.text.trim(),
                                });
                                _syncCalculatedRatio(
                                  ref,
                                  t.text.trim(),
                                  squeezeFactor,
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _LogicTile(
                              eyebrow: 'LENS SQUEEZE',
                              title: squeezeFactor,
                              detail: squeezeDetail,
                              palette: palette,
                              onTap: () async {
                                final t = TextEditingController(
                                  text: squeezeFactor,
                                );
                                final d = TextEditingController(
                                  text: squeezeDetail,
                                );
                                final ok = await _promptPair(
                                  context,
                                  'Lens Squeeze',
                                  t,
                                  d,
                                  aLabel: 'Factor (2.0x)',
                                  bLabel: 'Detalle',
                                );
                                if (ok != true) return;
                                await _updateCustomData(ref, {
                                  'squeezeFactor': t.text.trim(),
                                  'squeezeDetail': d.text.trim(),
                                });
                                _syncCalculatedRatio(
                                  ref,
                                  sensorMode,
                                  t.text.trim(),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Icon(
                          Icons.add,
                          color: palette.textTertiary.withValues(alpha: 0.4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final r =
                              TextEditingController(text: activeRatio);
                          final n =
                              TextEditingController(text: ratioName);
                          final ok = await _promptPair(
                            context,
                            'Aspect Ratio',
                            r,
                            n,
                            aLabel: 'Ratio (2.39:1)',
                            bLabel: 'Nombre',
                          );
                          if (ok != true) return;
                          final ratio = r.text.trim();
                          await _updateCustomData(ref, {
                            'activeRatio': ratio,
                            'ratioName': n.text.trim(),
                          });
                          data.aspectRatio = ratio;
                          onChanged(data);
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 20,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color: palette.surfaceElevated,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: palette.accent.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'CALCULATED ASPECT RATIO',
                                style: AppTypography.mono(palette).copyWith(
                                  fontSize: 10,
                                  letterSpacing: 1.5,
                                  color: palette.textTertiary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                activeRatio,
                                style: AppTypography.displayMedium(palette)
                                    .copyWith(
                                  fontSize: 44,
                                  color: palette.accent,
                                  letterSpacing: -1.5,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                ratioName.isEmpty
                                    ? _ratioLabel(activeRatio)
                                    : ratioName,
                                style: AppTypography.mono(palette).copyWith(
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );

                final specsCard = _GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.memory, size: 16, color: palette.textTertiary),
                          const SizedBox(width: 8),
                          Text(
                            'SYSTEM SPECIFICATIONS',
                            style: AppTypography.label(palette).copyWith(
                              fontSize: 11,
                              letterSpacing: 1.5,
                              color: palette.textTertiary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _SpecRow(
                        label: 'Camera Body',
                        value: body,
                        palette: palette,
                        onTap: () async {
                          final c = TextEditingController(
                            text: custom['cameraBody']?.toString() ?? body,
                          );
                          final v = await _prompt(context, 'Camera Body', c);
                          if (v != null) {
                            await _updateCustomData(
                              ref,
                              {'cameraBody': v},
                            );
                          }
                        },
                      ),
                      _SpecRow(
                        label: 'Lens Mount',
                        value: mount,
                        palette: palette,
                        onTap: () async {
                          final c = TextEditingController(
                            text: custom['lensMount']?.toString() ?? mount,
                          );
                          final v = await _prompt(context, 'Lens Mount', c);
                          if (v != null) {
                            await _updateCustomData(ref, {'lensMount': v});
                          }
                        },
                      ),
                      _SpecRow(
                        label: 'Sensor Dims',
                        value: sensorDims,
                        accent: true,
                        palette: palette,
                        onTap: () async {
                          final c =
                              TextEditingController(text: sensorDims);
                          final v =
                              await _prompt(context, 'Sensor Dims', c);
                          if (v != null) {
                            await _updateCustomData(
                              ref,
                              {'sensorDims': v},
                            );
                          }
                        },
                      ),
                      _SpecRow(
                        label: 'Resolution',
                        value: resolution,
                        accent: true,
                        palette: palette,
                        onTap: () async {
                          final c =
                              TextEditingController(text: resolution);
                          final v =
                              await _prompt(context, 'Resolution', c);
                          if (v != null) {
                            await _updateCustomData(ref, {'resolution': v});
                            data.captureResolution = v.isEmpty ? null : v;
                            onChanged(data);
                          }
                        },
                      ),
                      _SpecRow(
                        label: 'Image Circle',
                        value: circle,
                        palette: palette,
                        onTap: () async {
                          final c = TextEditingController(text: circle);
                          final v =
                              await _prompt(context, 'Image Circle', c);
                          if (v != null) {
                            await _updateCustomData(
                              ref,
                              {'imageCircle': v},
                            );
                          }
                        },
                      ),
                      _SpecRow(
                        label: 'Crop Factor',
                        value: crop,
                        palette: palette,
                        last: true,
                        onTap: () async {
                          final c = TextEditingController(text: crop);
                          final v =
                              await _prompt(context, 'Crop Factor', c);
                          if (v != null) {
                            await _updateCustomData(
                              ref,
                              {'cropFactor': v},
                            );
                          }
                        },
                      ),
                    ],
                  ),
                );

                final preview = _FramePreview(
                  projectId: projectId,
                  bibleId: data.id,
                  aspectRatio: activeRatio,
                  overlayCam: overlayCam,
                  palette: palette,
                  onEditOverlay: () async {
                    final c = TextEditingController(text: overlayCam);
                    final v = await _prompt(
                      context,
                      'Overlay (cámara | lente)',
                      c,
                    );
                    if (v != null) {
                      await _updateCustomData(ref, {'overlayCam': v});
                    }
                  },
                );

                final intent = _GlassPanel(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.edit_note,
                              size: 16, color: palette.textTertiary),
                          const SizedBox(width: 8),
                          Text(
                            "DIRECTOR'S INTENT",
                            style: AppTypography.label(palette).copyWith(
                              fontSize: 11,
                              letterSpacing: 1.5,
                              color: palette.textTertiary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      LayoutBuilder(
                        builder: (context, c) {
                          final cols = c.maxWidth >= 560 ? 3 : 1;
                          final items = [
                            (
                              'Narrativa',
                              intentNarrative,
                              'intentNarrative',
                              true
                            ),
                            (
                              'Composición',
                              intentComposition,
                              'intentComposition',
                              false
                            ),
                            (
                              'Refuerzo de Imagen',
                              intentReinforce,
                              'intentReinforce',
                              false
                            ),
                          ];
                          if (cols == 1) {
                            return Column(
                              children: [
                                for (final it in items) ...[
                                  _IntentCol(
                                    title: it.$1,
                                    body: it.$2,
                                    narrative: it.$4,
                                    palette: palette,
                                    onTap: () => _editIntent(
                                      context,
                                      ref,
                                      key: it.$3,
                                      title: it.$1,
                                      value: it.$2,
                                      syncNarrative: it.$4,
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
                              for (var i = 0; i < items.length; i++) ...[
                                if (i > 0) const SizedBox(width: 24),
                                Expanded(
                                  child: _IntentCol(
                                    title: items[i].$1,
                                    body: items[i].$2,
                                    narrative: items[i].$4,
                                    palette: palette,
                                    onTap: () => _editIntent(
                                      context,
                                      ref,
                                      key: items[i].$3,
                                      title: items[i].$1,
                                      value: items[i].$2,
                                      syncNarrative: items[i].$4,
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
                );

                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: Column(
                          children: [
                            logicCard,
                            const SizedBox(height: 16),
                            specsCard,
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 7,
                        child: Column(
                          children: [
                            preview,
                            const SizedBox(height: 16),
                            intent,
                          ],
                        ),
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    logicCard,
                    const SizedBox(height: 16),
                    preview,
                    const SizedBox(height: 16),
                    specsCard,
                    const SizedBox(height: 16),
                    intent,
                  ],
                );
              },
            );
          },
        ),
      },
    );
  }

  void _syncCalculatedRatio(
    WidgetRef ref,
    String sensorMode,
    String squeezeFactor,
  ) {
    final sensorR = _parseRatio(sensorMode);
    final squeeze = _parseSqueeze(squeezeFactor);
    if (sensorR == null || squeeze == null) return;
    final ratio = _formatRatio(sensorR * squeeze);
    _updateCustomData(ref, {'activeRatio': ratio});
    data.aspectRatio = ratio;
    onChanged(data);
  }

  Future<void> _editIntent(
    BuildContext context,
    WidgetRef ref, {
    required String key,
    required String title,
    required String value,
    required bool syncNarrative,
  }) async {
    final c = TextEditingController(text: value);
    final v = await _prompt(context, title, c, maxLines: 5);
    if (v == null) return;
    await _updateCustomData(ref, {key: v});
    if (syncNarrative) {
      data.formatNarrativeIntent = v;
      data.aspectRatioJustification = v;
      onChanged(data);
    }
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
    TextEditingController b, {
    String aLabel = 'Título',
    String bLabel = 'Detalle',
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: a,
              decoration: InputDecoration(labelText: aLabel),
            ),
            TextField(
              controller: b,
              decoration: InputDecoration(labelText: bLabel),
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
}

class _GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xB31A1A1C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: child,
    );
  }
}

class _LogicTile extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String detail;
  final AppPalette palette;
  final VoidCallback onTap;

  const _LogicTile({
    required this.eyebrow,
    required this.title,
    required this.detail,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1F1F21),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow,
              style: AppTypography.mono(palette).copyWith(
                fontSize: 11,
                color: palette.textTertiary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: AppTypography.titleMedium(palette).copyWith(fontSize: 22),
            ),
            const SizedBox(height: 4),
            Text(
              detail,
              style: AppTypography.mono(palette).copyWith(
                fontSize: 12,
                color: palette.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpecRow extends StatelessWidget {
  final String label;
  final String value;
  final AppPalette palette;
  final bool accent;
  final bool last;
  final VoidCallback onTap;

  const _SpecRow({
    required this.label,
    required this.value,
    required this.palette,
    required this.onTap,
    this.accent = false,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
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
                style: AppTypography.mono(palette).copyWith(
                  fontSize: 12,
                  color: palette.textTertiary,
                ),
              ),
            ),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: AppTypography.mono(palette).copyWith(
                  fontSize: 12,
                  color: accent ? palette.accent : palette.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntentCol extends StatelessWidget {
  final String title;
  final String body;
  final bool narrative;
  final AppPalette palette;
  final VoidCallback onTap;

  const _IntentCol({
    required this.title,
    required this.body,
    required this.narrative,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: AppTypography.mono(palette).copyWith(
              fontSize: 11,
              letterSpacing: 1.2,
              color: palette.accent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body.isEmpty ? 'Toca para definir…' : body,
            style: (narrative
                    ? AppTypography.bodyMedium(palette).copyWith(
                        fontSize: 16,
                        height: 1.5,
                        color: palette.textPrimary.withValues(alpha: 0.9),
                      )
                    : AppTypography.bodyMedium(palette).copyWith(
                        color: palette.textSecondary,
                        height: 1.45,
                      )),
          ),
        ],
      ),
    );
  }
}

class _FramePreview extends ConsumerWidget {
  final int projectId;
  final int bibleId;
  final String aspectRatio;
  final String overlayCam;
  final AppPalette palette;
  final VoidCallback onEditOverlay;

  const _FramePreview({
    required this.projectId,
    required this.bibleId,
    required this.aspectRatio,
    required this.overlayCam,
    required this.palette,
    required this.onEditOverlay,
  });

  double _parseAspect(String raw) {
    final parts = raw.split(':');
    if (parts.length == 2) {
      final w = double.tryParse(parts[0].trim());
      final h = double.tryParse(parts[1].trim());
      if (w != null && h != null && h != 0) return w / h;
    }
    return 2.39;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final ar = _parseAspect(aspectRatio);

    return _GlassPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1B1D),
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.visibility_outlined,
                    size: 16, color: palette.textTertiary),
                const SizedBox(width: 8),
                Text(
                  'FRAME PREVIEW ($aspectRatio)',
                  style: AppTypography.label(palette).copyWith(
                    fontSize: 11,
                    letterSpacing: 1.4,
                    color: palette.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(
              color: Colors.black,
              child: Center(
                child: AspectRatio(
                  aspectRatio: ar,
                  child: StreamBuilder<List<MoodboardImage>>(
                    stream: db.watchMoodboardImagesForSection(
                      projectId,
                      BibleSectionId.format,
                    ),
                    builder: (context, snap) {
                      final imgs = snap.data ?? [];
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          if (imgs.isNotEmpty &&
                              File(imgs.first.imagePath).existsSync())
                            ColorFiltered(
                              colorFilter: const ColorFilter.matrix(<double>[
                                0.9, 0.05, 0.05, 0, 0,
                                0.05, 0.9, 0.05, 0, 0,
                                0.05, 0.05, 0.95, 0, 0,
                                0, 0, 0, 1, 0,
                              ]),
                              child: Image.file(
                                File(imgs.first.imagePath),
                                fit: BoxFit.cover,
                              ),
                            )
                          else
                            ColoredBox(
                              color: palette.surfaceOverlay,
                              child: Center(
                                child: TextButton.icon(
                                  onPressed: () =>
                                      MoodboardHelpers.addManualImages(
                                    db: db,
                                    projectId: projectId,
                                    bibleId: bibleId,
                                    category: MoodboardCategory.reference,
                                  ),
                                  icon: Icon(
                                    Icons.add_photo_alternate_outlined,
                                    color: palette.accent,
                                  ),
                                  label: Text(
                                    'Añadir frame',
                                    style: TextStyle(color: palette.accent),
                                  ),
                                ),
                              ),
                            ),
                          // Rule of thirds
                          CustomPaint(painter: _ThirdsPainter(palette.accent)),
                          Positioned(
                            top: 8,
                            left: 8,
                            child: InkWell(
                              onTap: onEditOverlay,
                              child: Text(
                                overlayCam.toUpperCase(),
                                style: AppTypography.mono(palette).copyWith(
                                  fontSize: 10,
                                  letterSpacing: 1.2,
                                  color: palette.accent.withValues(alpha: 0.75),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 8,
                            bottom: 8,
                            child: Text(
                              'FILM BIBLE',
                              style: AppTypography.mono(palette).copyWith(
                                fontSize: 10,
                                letterSpacing: 1.2,
                                color: Colors.white54,
                              ),
                            ),
                          ),
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFFFFB4AB),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'REC',
                                  style: AppTypography.mono(palette).copyWith(
                                    fontSize: 10,
                                    letterSpacing: 1.2,
                                    color: const Color(0xFFFFB4AB)
                                        .withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThirdsPainter extends CustomPainter {
  final Color color;
  _ThirdsPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..strokeWidth = 0.8;
    final dx = size.width / 3;
    final dy = size.height / 3;
    canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), paint);
    canvas.drawLine(Offset(dx * 2, 0), Offset(dx * 2, size.height), paint);
    canvas.drawLine(Offset(0, dy), Offset(size.width, dy), paint);
    canvas.drawLine(Offset(0, dy * 2), Offset(size.width, dy * 2), paint);
  }

  @override
  bool shouldRepaint(covariant _ThirdsPainter oldDelegate) =>
      oldDelegate.color != color;
}
