import 'dart:convert';
import 'dart:io';

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
import '../bible_form_widgets.dart';
import '../bible_moodboard_image_target.dart';
import 'section_scaffold.dart';

/// Dirección — layout Stitch Visual Bible (glass bento).
class DirectionSection extends ConsumerWidget {
  final VisualBibleData data;
  final int projectId;
  final String? sectionContentJson;
  final BibleChanged onChanged;

  const DirectionSection({
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

      // Formato fields/values (actual)
      final valuesRaw = decoded['values'] ?? decoded['_values'];
      if (valuesRaw is Map) {
        final vals = Map<String, dynamic>.from(valuesRaw);
        if (vals['directionData'] is String) {
          final parsed = jsonDecode(vals['directionData'] as String);
          if (parsed is Map<String, dynamic>) return parsed;
        }
        // Valores sueltos legacy en values
        return vals;
      }

      // Flat legacy (antes de fields config)
      if (!decoded.containsKey('fields')) {
        return Map<String, dynamic>.from(decoded);
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
                d.bibleId.equals(data.id) &
                d.id.equals(BibleSectionId.direction),
          ))
        .getSingleOrNull();
    if (def == null) return;
    final fields = BibleSectionFieldsConfig.parse(
      def.contentJson,
      BibleSectionId.direction,
    );
    final values = BibleSectionFieldsConfig.parseValues(def.contentJson);
    values['directionData'] = jsonEncode(newData);
    await db.upsertBibleSectionDefinition(
      def.copyWith(
        contentJson: drift.Value(
          BibleSectionFieldsConfig.encode(fields, values: values),
        ),
      ),
    );
  }

  List<Map<String, String>> _tonePoints(Map<String, dynamic> custom) {
    final raw = custom['tonePoints'];
    if (raw is! List) return [];
    return raw.map((e) {
      if (e is Map) {
        return {
          'title': e['title']?.toString() ?? '',
          'body': e['body']?.toString() ?? e['desc']?.toString() ?? '',
        };
      }
      final s = e.toString();
      final parts = s.split(':');
      if (parts.length >= 2) {
        return {
          'title': parts.first.trim(),
          'body': parts.sublist(1).join(':').trim(),
        };
      }
      return {'title': s, 'body': ''};
    }).toList();
  }

  List<Map<String, String>> _transitions(Map<String, dynamic> custom) {
    final raw = custom['transitionLanguage'];
    if (raw is! List) return [];
    return raw.map((e) {
      if (e is Map) {
        return {
          'title': e['title']?.toString() ?? '',
          'body': e['body']?.toString() ?? '',
        };
      }
      return {'title': e.toString(), 'body': ''};
    }).toList();
  }

  List<Map<String, String>> _extraStrategies(Map<String, dynamic> custom) {
    final raw = custom['extraStrategies'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => {
              'title': e['title']?.toString() ?? '',
              'body': e['body']?.toString() ?? '',
            })
        .toList();
  }

  List<Map<String, dynamic>> _refsMeta(Map<String, dynamic> custom) {
    final raw = custom['refsMetadata'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);
    final custom = _getCustomData();

    final sceneTag =
        custom['sceneTag'] as String? ?? 'SCENE 01 / INT. APARTMENT';
    final emotionTags = (custom['emotionTags'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        <String>[];
    final tonePoints = _tonePoints(custom);
    final transitions = _transitions(custom);
    final extras = _extraStrategies(custom);

    final act1Phase = custom['act1Phase'] as String? ?? 'ESTABLECIMIENTO';
    final act2Phase = custom['act2Phase'] as String? ?? 'DESESTABILIZACIÓN';
    final act3Phase = custom['act3Phase'] as String? ?? 'RESOLUCIÓN';
    final act1Title = custom['act1Title'] as String? ?? 'Orden y Rigidez';
    final act2Title = custom['act2Title'] as String? ?? 'Fragmentación';
    final act3Title = custom['act3Title'] as String? ?? 'Abstracción';
    final act1Desc = custom['act1Desc'] as String? ?? '';
    final act2Desc = custom['act2Desc'] as String? ?? '';
    final act3Desc = custom['act3Desc'] as String? ?? '';

    final keyFrame = (custom['keyFrame'] as Map?)?.cast<String, String>() ??
        {
          'focal': '35mm',
          'aperture': 'T1.4',
          'filmStock': 'Kodak Vision3 500T',
          'preset': 'CINEMATIC',
          'exposure': '-1.5 EV',
          'wb': '2800K',
          'shutter': '1/50',
        };
    final keyFrameIntent = custom['keyFrameIntent'] as String? ?? '';

    return Builder(
      builder: (context) {
            final header = _DirectionHeader(
              sceneTag: sceneTag,
              palette: palette,
              onEditScene: () async {
                final c = TextEditingController(text: sceneTag);
                final v = await _promptText(
                  context,
                  title: 'Escena',
                  controller: c,
                );
                if (v != null) {
                  await _updateCustomData(ref, {'sceneTag': v});
                }
              },
              onEditNotes: () {
                // Foco visual: el campo narrativo está debajo.
              },
            );

            final intentCard = _GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TechLabel(
                    icon: Icons.psychology_outlined,
                    label: 'Intención Narrativa',
                    palette: palette,
                  ),
                  const SizedBox(height: 16),
                  BibleTextField(
                    label: '',
                    hint:
                        '"La película explora… La cámara debe sentirse como…"',
                    maxLines: 5,
                    initialValue: data.directionNarrativeIntent ?? '',
                    onChanged: (v) {
                      data.directionNarrativeIntent = v;
                      onChanged(data);
                    },
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in emotionTags)
                        _EmotionChip(
                          label: tag,
                          danger: _isDangerTag(tag),
                          palette: palette,
                          onDelete: () {
                            final next = List<String>.from(emotionTags)
                              ..remove(tag);
                            _updateCustomData(ref, {'emotionTags': next});
                          },
                        ),
                      ActionChip(
                        avatar:
                            Icon(Icons.add, size: 14, color: palette.accent),
                        label: Text(
                          'TAG',
                          style: AppTypography.mono(palette).copyWith(
                            fontSize: 10,
                            color: palette.accent,
                          ),
                        ),
                        onPressed: () async {
                          final picked = await showModalBottomSheet<String>(
                            context: context,
                            builder: (ctx) {
                              const opts = [
                                'Tensión',
                                'Claustrofobia',
                                'Esperanza',
                                'Melancolía',
                                'Euforia',
                                'Soledad',
                                'Peligro',
                                'Calma',
                                'Ambigüedad',
                                'Amor',
                                'Pérdida',
                                'Poder',
                              ];
                              return SafeArea(
                                child: ListView(
                                  shrinkWrap: true,
                                  children: [
                                    for (final o in opts)
                                      ListTile(
                                        title: Text(o.toUpperCase()),
                                        onTap: () => Navigator.pop(ctx, o),
                                      ),
                                    ListTile(
                                      title: const Text('Personalizado…'),
                                      onTap: () async {
                                        Navigator.pop(ctx);
                                        final c = TextEditingController();
                                        final v = await _promptText(
                                          context,
                                          title: 'Tag',
                                          controller: c,
                                        );
                                        if (v != null && v.isNotEmpty) {
                                          await _updateCustomData(ref, {
                                            'emotionTags': [
                                              ...emotionTags,
                                              v,
                                            ],
                                          });
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                          if (picked == null || picked.isEmpty) return;
                          if (emotionTags.contains(picked)) return;
                          await _updateCustomData(ref, {
                            'emotionTags': [...emotionTags, picked],
                          });
                        },
                        backgroundColor: Colors.transparent,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );

            final toneCard = _GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TechLabel(
                    icon: Icons.blur_on,
                    label: 'Tono y Atmósfera',
                    palette: palette,
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < tonePoints.length; i++) ...[
                    InkWell(
                      onTap: () async {
                        final t = TextEditingController(
                          text: tonePoints[i]['title'],
                        );
                        final b = TextEditingController(
                          text: tonePoints[i]['body'],
                        );
                        final ok = await _promptPair(
                          context,
                          title: 'Punto de tono',
                          titleC: t,
                          bodyC: b,
                        );
                        if (ok != true) return;
                        final next =
                            List<Map<String, String>>.from(tonePoints);
                        next[i] = {
                          'title': t.text.trim(),
                          'body': b.text.trim(),
                        };
                        await _updateCustomData(ref, {'tonePoints': next});
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.only(bottom: 12),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.white.withValues(alpha: 0.06),
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tonePoints[i]['title']!.isEmpty
                                  ? 'Sin título'
                                  : tonePoints[i]['title']!,
                              style: AppTypography.titleMedium(palette)
                                  .copyWith(fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tonePoints[i]['body']!.isEmpty
                                  ? 'Toca para editar…'
                                  : tonePoints[i]['body']!,
                              style: AppTypography.mono(palette).copyWith(
                                fontSize: 12,
                                color: palette.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  OutlinedButton.icon(
                    onPressed: () async {
                      final t = TextEditingController();
                      final b = TextEditingController();
                      final ok = await _promptPair(
                        context,
                        title: 'Añadir punto',
                        titleC: t,
                        bodyC: b,
                      );
                      if (ok != true) return;
                      await _updateCustomData(ref, {
                        'tonePoints': [
                          ...tonePoints,
                          {
                            'title': t.text.trim(),
                            'body': b.text.trim(),
                          },
                        ],
                      });
                    },
                    icon: Icon(Icons.add, size: 16, color: palette.accent),
                    label: Text(
                      'AÑADIR PUNTO',
                      style: AppTypography.mono(palette).copyWith(
                        fontSize: 11,
                        color: palette.textSecondary,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.2),
                        style: BorderStyle.solid,
                      ),
                      minimumSize: const Size.fromHeight(40),
                    ),
                  ),
                ],
              ),
            );

            final strategyCard = _GlassPanel(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TechLabel(
                    icon: Icons.visibility_outlined,
                    label: 'Estrategia Visual',
                    palette: palette,
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, c) {
                      final w = c.maxWidth.isFinite ? c.maxWidth : MediaQuery.sizeOf(context).width;
                      final cols = w >= 720
                          ? 4
                          : (w >= 480 ? 2 : 1);
                      final items = <Widget>[
                        _StrategyPillar(
                          icon: Icons.videocam_outlined,
                          title: 'Cámara',
                          body: data.cameraPhilosophy ?? '',
                          palette: palette,
                          onEdit: () async {
                            final ctrl = TextEditingController(
                              text: data.cameraPhilosophy ?? '',
                            );
                            final v = await _promptText(
                              context,
                              title: 'Cámara',
                              controller: ctrl,
                              maxLines: 5,
                            );
                            if (v == null) return;
                            data.cameraPhilosophy = v;
                            onChanged(data);
                          },
                        ),
                        _StrategyPillar(
                          icon: Icons.person_pin_outlined,
                          title: 'Blocking',
                          body: data.stagingApproach ?? '',
                          palette: palette,
                          onEdit: () async {
                            final ctrl = TextEditingController(
                              text: data.stagingApproach ?? '',
                            );
                            final v = await _promptText(
                              context,
                              title: 'Blocking',
                              controller: ctrl,
                              maxLines: 5,
                            );
                            if (v == null) return;
                            data.stagingApproach = v;
                            onChanged(data);
                          },
                        ),
                        _StrategyPillar(
                          icon: Icons.center_focus_strong,
                          title: 'POV',
                          body: data.pointOfView ?? '',
                          palette: palette,
                          onEdit: () async {
                            final ctrl = TextEditingController(
                              text: data.pointOfView ?? '',
                            );
                            final v = await _promptText(
                              context,
                              title: 'POV',
                              controller: ctrl,
                              maxLines: 5,
                            );
                            if (v == null) return;
                            data.pointOfView = v;
                            onChanged(data);
                          },
                        ),
                        for (var i = 0; i < extras.length; i++)
                          _StrategyPillar(
                            icon: Icons.auto_awesome_outlined,
                            title: extras[i]['title']!.isEmpty
                                ? 'Estrategia'
                                : extras[i]['title']!,
                            body: extras[i]['body'] ?? '',
                            palette: palette,
                            onEdit: () async {
                              final t = TextEditingController(
                                text: extras[i]['title'],
                              );
                              final b = TextEditingController(
                                text: extras[i]['body'],
                              );
                              final ok = await _promptPair(
                                context,
                                title: 'Estrategia',
                                titleC: t,
                                bodyC: b,
                              );
                              if (ok != true) return;
                              final next =
                                  List<Map<String, String>>.from(extras);
                              next[i] = {
                                'title': t.text.trim(),
                                'body': b.text.trim(),
                              };
                              await _updateCustomData(
                                ref,
                                {'extraStrategies': next},
                              );
                            },
                          ),
                        _AddDashedCard(
                          label: 'AÑADIR ESTRATEGIA',
                          icon: Icons.add_circle_outline,
                          palette: palette,
                          onTap: () async {
                            final t = TextEditingController();
                            final b = TextEditingController();
                            final ok = await _promptPair(
                              context,
                              title: 'Nueva estrategia',
                              titleC: t,
                              bodyC: b,
                            );
                            if (ok != true) return;
                            await _updateCustomData(ref, {
                              'extraStrategies': [
                                ...extras,
                                {
                                  'title': t.text.trim(),
                                  'body': b.text.trim(),
                                },
                              ],
                            });
                          },
                        ),
                      ];
                      return GridView.count(
                        crossAxisCount: cols,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: cols >= 3 ? 0.95 : 1.2,
                        children: items,
                      );
                    },
                  ),
                ],
              ),
            );

            final actsCard = _GlassPanel(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TechLabel(
                    icon: Icons.timeline,
                    label: 'Intención Visual por Acto',
                    palette: palette,
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, c) {
                      final w = c.maxWidth.isFinite ? c.maxWidth : MediaQuery.sizeOf(context).width;
                      final cols = w >= 700 ? 3 : 1;
                      final acts = [
                        (act1Phase, act1Title, act1Desc, '1'),
                        (act2Phase, act2Title, act2Desc, '2'),
                        (act3Phase, act3Title, act3Desc, '3'),
                      ];
                      return GridView.count(
                        crossAxisCount: cols,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: cols == 1 ? 2.4 : 1.15,
                        children: [
                          for (final a in acts)
                            _ActColumn(
                              phase: a.$1,
                              title: a.$2,
                              body: a.$3,
                              palette: palette,
                              onEdit: () async {
                                final phase =
                                    TextEditingController(text: a.$1);
                                final title =
                                    TextEditingController(text: a.$2);
                                final body =
                                    TextEditingController(text: a.$3);
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text('Acto ${a.$4}'),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextField(
                                          controller: phase,
                                          decoration: const InputDecoration(
                                            labelText: 'Fase',
                                          ),
                                        ),
                                        TextField(
                                          controller: title,
                                          decoration: const InputDecoration(
                                            labelText: 'Título',
                                          ),
                                        ),
                                        TextField(
                                          controller: body,
                                          maxLines: 4,
                                          decoration: const InputDecoration(
                                            labelText: 'Intención',
                                          ),
                                        ),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancelar'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('Guardar'),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok != true) return;
                                await _updateCustomData(ref, {
                                  'act${a.$4}Phase': phase.text.trim(),
                                  'act${a.$4}Title': title.text.trim(),
                                  'act${a.$4}Desc': body.text.trim(),
                                });
                              },
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            );

            final keyFrameCard = _KeyFrameAnalysisCard(
              projectId: projectId,
              palette: palette,
              tech: keyFrame,
              intent: keyFrameIntent,
              onEditTech: () async {
                final focal =
                    TextEditingController(text: keyFrame['focal'] ?? '');
                final aperture =
                    TextEditingController(text: keyFrame['aperture'] ?? '');
                final stock =
                    TextEditingController(text: keyFrame['filmStock'] ?? '');
                final preset =
                    TextEditingController(text: keyFrame['preset'] ?? '');
                final exp =
                    TextEditingController(text: keyFrame['exposure'] ?? '');
                final wb = TextEditingController(text: keyFrame['wb'] ?? '');
                final shutter =
                    TextEditingController(text: keyFrame['shutter'] ?? '');
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Key Frame HUD'),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: focal,
                            decoration:
                                const InputDecoration(labelText: 'Focal'),
                          ),
                          TextField(
                            controller: aperture,
                            decoration:
                                const InputDecoration(labelText: 'Aperture'),
                          ),
                          TextField(
                            controller: stock,
                            decoration:
                                const InputDecoration(labelText: 'Film stock'),
                          ),
                          TextField(
                            controller: preset,
                            decoration:
                                const InputDecoration(labelText: 'Preset'),
                          ),
                          TextField(
                            controller: exp,
                            decoration:
                                const InputDecoration(labelText: 'Exposure'),
                          ),
                          TextField(
                            controller: wb,
                            decoration: const InputDecoration(labelText: 'WB'),
                          ),
                          TextField(
                            controller: shutter,
                            decoration:
                                const InputDecoration(labelText: 'Shutter'),
                          ),
                        ],
                      ),
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
                await _updateCustomData(ref, {
                  'keyFrame': {
                    'focal': focal.text.trim(),
                    'aperture': aperture.text.trim(),
                    'filmStock': stock.text.trim(),
                    'preset': preset.text.trim(),
                    'exposure': exp.text.trim(),
                    'wb': wb.text.trim(),
                    'shutter': shutter.text.trim(),
                  },
                });
              },
              onEditIntent: () async {
                final c = TextEditingController(text: keyFrameIntent);
                final v = await _promptText(
                  context,
                  title: "Director's Intent",
                  controller: c,
                  maxLines: 5,
                );
                if (v == null) return;
                await _updateCustomData(ref, {'keyFrameIntent': v});
              },
            );

            final transitionsCard = _GlassPanel(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TechLabel(
                    icon: Icons.animation,
                    label: 'Lenguaje de Transiciones',
                    palette: palette,
                  ),
                  const SizedBox(height: 20),
                  for (var i = 0; i < transitions.length; i++) ...[
                    InkWell(
                      onTap: () async {
                        final t = TextEditingController(
                          text: transitions[i]['title'],
                        );
                        final b = TextEditingController(
                          text: transitions[i]['body'],
                        );
                        final ok = await _promptPair(
                          context,
                          title: 'Transición',
                          titleC: t,
                          bodyC: b,
                        );
                        if (ok != true) return;
                        final next =
                            List<Map<String, String>>.from(transitions);
                        next[i] = {
                          'title': t.text.trim(),
                          'body': b.text.trim(),
                        };
                        await _updateCustomData(
                          ref,
                          {'transitionLanguage': next},
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.keyboard_double_arrow_right,
                              color: palette.accent,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    transitions[i]['title']!.isEmpty
                                        ? 'Sin título'
                                        : transitions[i]['title']!,
                                    style: AppTypography.titleMedium(palette)
                                        .copyWith(fontSize: 15),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    transitions[i]['body']!.isEmpty
                                        ? 'Toca para editar…'
                                        : transitions[i]['body']!,
                                    style: AppTypography.bodyMedium(palette)
                                        .copyWith(
                                      color: palette.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  TextButton.icon(
                    onPressed: () async {
                      final t = TextEditingController();
                      final b = TextEditingController();
                      final ok = await _promptPair(
                        context,
                        title: 'Nueva transición',
                        titleC: t,
                        bodyC: b,
                      );
                      if (ok != true) return;
                      await _updateCustomData(ref, {
                        'transitionLanguage': [
                          ...transitions,
                          {
                            'title': t.text.trim(),
                            'body': b.text.trim(),
                          },
                        ],
                      });
                    },
                    icon: Icon(Icons.add, color: palette.accent, size: 16),
                    label: Text(
                      'Añadir transición',
                      style: TextStyle(color: palette.accent),
                    ),
                  ),
                ],
              ),
            );

        return BibleSectionScaffold(
      sectionId: BibleSectionId.direction,
      projectId: projectId,
      data: data,
      onChanged: onChanged,
      sectionContentJson: sectionContentJson,
      narrativeHint:
          '¿Cuál es la intención global de la fotografía respecto a la historia?',
      sectionNumber: null,
      sectionTitle: 'Dirección',
      fieldWidgets: {
        'header': header,
        'narrative': intentCard,
        'toneStrategies': Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            toneCard,
            const SizedBox(height: 16),
            strategyCard,
          ],
        ),
        'acts': actsCard,
        'keyFrame': keyFrameCard,
        'transitions': transitionsCard,
      },
    );
      },
    );
  }

  static bool _isDangerTag(String tag) {
    final t = tag.toLowerCase();
    return t.contains('tens') ||
        t.contains('peligro') ||
        t.contains('claustro') ||
        t.contains('paranoia');
  }

  static Future<String?> _promptText(
    BuildContext context, {
    required String title,
    required TextEditingController controller,
    int maxLines = 1,
  }) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: maxLines,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  static Future<bool?> _promptPair(
    BuildContext context, {
    required String title,
    required TextEditingController titleC,
    required TextEditingController bodyC,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleC,
              decoration: const InputDecoration(labelText: 'Título'),
            ),
            TextField(
              controller: bodyC,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Descripción'),
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

  static Future<Map<String, dynamic>?> _editRefMeta(
    BuildContext context,
    Map<String, dynamic> initial,
  ) async {
    final refLabel =
        TextEditingController(text: initial['refLabel']?.toString() ?? '');
    final title =
        TextEditingController(text: initial['title']?.toString() ?? '');
    final body =
        TextEditingController(text: initial['body']?.toString() ?? '');
    final lens =
        TextEditingController(text: initial['lens']?.toString() ?? '');
    final tech2Label =
        TextEditingController(text: initial['tech2Label']?.toString() ?? 'APERTURE');
    final tech2Value =
        TextEditingController(text: initial['tech2Value']?.toString() ?? '');
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ficha de referencia'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: refLabel,
                decoration: const InputDecoration(
                  labelText: 'REF label (FINCHER / SE7EN)',
                ),
              ),
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Título'),
              ),
              TextField(
                controller: body,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Notas'),
              ),
              TextField(
                controller: lens,
                decoration: const InputDecoration(labelText: 'Lens'),
              ),
              TextField(
                controller: tech2Label,
                decoration:
                    const InputDecoration(labelText: 'Tech 2 label'),
              ),
              TextField(
                controller: tech2Value,
                decoration:
                    const InputDecoration(labelText: 'Tech 2 value'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, {
              'refLabel': refLabel.text.trim(),
              'title': title.text.trim(),
              'body': body.text.trim(),
              'lens': lens.text.trim(),
              'tech2Label': tech2Label.text.trim(),
              'tech2Value': tech2Value.text.trim(),
            }),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

class _DirectionHeader extends StatelessWidget {
  final String sceneTag;
  final AppPalette palette;
  final VoidCallback onEditScene;
  final VoidCallback onEditNotes;

  const _DirectionHeader({
    required this.sceneTag,
    required this.palette,
    required this.onEditScene,
    required this.onEditNotes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: onEditScene,
                  child: Text(
                    sceneTag.toUpperCase(),
                    style: AppTypography.mono(palette).copyWith(
                      fontSize: 11,
                      letterSpacing: 1.2,
                      color: palette.accent,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Dirección',
                  style: AppTypography.displayMedium(palette).copyWith(
                    fontSize: 40,
                    letterSpacing: -0.8,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: onEditNotes,
            icon: Icon(Icons.edit, size: 14, color: palette.accent),
            label: Text(
              'EDIT NOTES',
              style: AppTypography.mono(palette).copyWith(
                fontSize: 12,
                color: palette.accent,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: palette.accent.withValues(alpha: 0.3)),
              backgroundColor: palette.accent.withValues(alpha: 0.08),
            ),
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
    this.padding = const EdgeInsets.all(24),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xB31A1A1C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.08),
            blurRadius: 0,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _TechLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final AppPalette palette;

  const _TechLabel({
    required this.icon,
    required this.label,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: palette.accent),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: AppTypography.mono(palette).copyWith(
            fontSize: 11,
            letterSpacing: 1.2,
            color: palette.accent,
          ),
        ),
      ],
    );
  }
}

class _EmotionChip extends StatelessWidget {
  final String label;
  final bool danger;
  final AppPalette palette;
  final VoidCallback onDelete;

  const _EmotionChip({
    required this.label,
    required this.danger,
    required this.palette,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final fg = danger ? const Color(0xFFFFB4AB) : const Color(0xFFBBC7DF);
    final bg = danger
        ? const Color(0x3393000A)
        : const Color(0x333E495E);
    return InputChip(
      label: Text(
        label.toUpperCase(),
        style: AppTypography.mono(palette).copyWith(fontSize: 10, color: fg),
      ),
      onDeleted: onDelete,
      backgroundColor: bg,
      side: BorderSide(color: fg.withValues(alpha: 0.35)),
      deleteIconColor: fg.withValues(alpha: 0.7),
    );
  }
}

class _StrategyPillar extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final AppPalette palette;
  final VoidCallback onEdit;

  const _StrategyPillar({
    required this.icon,
    required this.title,
    required this.body,
    required this.palette,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.surfaceElevated,
            ),
            child: Icon(icon, color: palette.accent, size: 20),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: AppTypography.titleMedium(palette).copyWith(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              body.isEmpty ? 'Toca para definir…' : body,
              style: AppTypography.bodyMedium(palette).copyWith(
                color: palette.textSecondary,
                height: 1.4,
              ),
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddDashedCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final AppPalette palette;
  final VoidCallback onTap;

  const _AddDashedCard({
    required this.label,
    required this.icon,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: Colors.white.withValues(alpha: 0.12),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: palette.textTertiary, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: AppTypography.mono(palette).copyWith(
                  fontSize: 11,
                  color: palette.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;

  _DashedBorderPainter({required this.color});

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
      const Radius.circular(12),
    );
    final path = Path()..addRRect(r);
    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        final next = (dist + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(dist, next), paint);
        dist = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _ActColumn extends StatelessWidget {
  final String phase;
  final String title;
  final String body;
  final AppPalette palette;
  final VoidCallback onEdit;

  const _ActColumn({
    required this.phase,
    required this.title,
    required this.body,
    required this.palette,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.only(left: 14),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: palette.accent.withValues(alpha: 0.35),
              width: 4,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              phase.toUpperCase(),
              style: AppTypography.mono(palette).copyWith(
                fontSize: 11,
                letterSpacing: 1.1,
                color: palette.accent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: AppTypography.titleMedium(palette).copyWith(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                body.isEmpty ? 'Toca para definir…' : body,
                style: AppTypography.bodyMedium(palette).copyWith(
                  color: palette.textSecondary,
                ),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeyFrameAnalysisCard extends ConsumerWidget {
  final int projectId;
  final AppPalette palette;
  final Map<String, String> tech;
  final String intent;
  final VoidCallback onEditTech;
  final VoidCallback onEditIntent;

  const _KeyFrameAnalysisCard({
    required this.projectId,
    required this.palette,
    required this.tech,
    required this.intent,
    required this.onEditTech,
    required this.onEditIntent,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    return _GlassPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            child: _TechLabel(
              icon: Icons.center_focus_weak,
              label: 'Key Frame Analysis',
              palette: palette,
            ),
          ),
          StreamBuilder<List<MoodboardImage>>(
            stream: db.watchMoodboardImagesForSection(
              projectId,
              BibleSectionId.direction,
            ),
            builder: (context, snap) {
              final images = snap.data ?? [];
              final hero = images.isNotEmpty ? images.first : null;
              return BibleMoodboardImageTarget(
                projectId: projectId,
                sectionId: BibleSectionId.direction,
                hint: 'Clic aquí → ⌘V para pegar key frame',
                child: AspectRatio(
                  aspectRatio: 21 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (hero != null)
                      Builder(
                        builder: (_) {
                          final model = MoodboardImageModel.fromRow(hero);
                          final file = File(model.imagePath);
                          return file.existsSync()
                              ? Image.file(file, fit: BoxFit.cover)
                              : ColoredBox(color: palette.surfaceOverlay);
                        },
                      )
                    else
                      ColoredBox(
                        color: palette.surfaceOverlay,
                        child: Center(
                          child: TextButton.icon(
                            onPressed: () => MoodboardHelpers.addManualImages(
                              db: db,
                              projectId: projectId,
                              category: MoodboardCategory.framing,
                              assignedSections: [BibleSectionId.direction],
                            ),
                            icon: Icon(Icons.add_photo_alternate_outlined,
                                color: palette.accent),
                            label: Text(
                              'Añadir key frame',
                              style: TextStyle(color: palette.accent),
                            ),
                          ),
                        ),
                      ),
                    Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 28,
                      bottom: 24,
                      child: InkWell(
                        onTap: onEditTech,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _hud('FOCAL LENGTH: ${tech['focal'] ?? '—'}'),
                            _hud('APERTURE: ${tech['aperture'] ?? '—'}'),
                            _hud('FILM STOCK: ${tech['filmStock'] ?? '—'}'),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      right: 28,
                      top: 24,
                      child: InkWell(
                        onTap: onEditTech,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _hud('[PRESET: ${tech['preset'] ?? '—'}]'),
                            _hud('[EXP: ${tech['exposure'] ?? '—'}]'),
                            _hud('[WB: ${tech['wb'] ?? '—'}]'),
                            _hud('[SHUTTER: ${tech['shutter'] ?? '—'}]'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, c) {
                final sideBySide = c.maxWidth >= 640;
                final intentPanel = InkWell(
                  onTap: onEditIntent,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.edit_note, size: 16, color: palette.accent),
                          const SizedBox(width: 6),
                          Text(
                            "DIRECTOR'S INTENT",
                            style: AppTypography.mono(palette).copyWith(
                              fontSize: 11,
                              color: palette.accent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        intent.isEmpty
                            ? 'Toca para definir la intención del key frame…'
                            : intent,
                        style: AppTypography.bodyMedium(palette).copyWith(
                          color: palette.textSecondary,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                );
                final thumbs = StreamBuilder<List<MoodboardImage>>(
                  stream: db.watchMoodboardImagesForSection(
                    projectId,
                    BibleSectionId.direction,
                  ),
                  builder: (context, snap) {
                    final imgs = (snap.data ?? []).skip(1).take(2).toList();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.photo_library_outlined,
                              size: 16,
                              color: palette.accent,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'VISUAL REFERENCES',
                              style: AppTypography.mono(palette).copyWith(
                                fontSize: 11,
                                color: palette.accent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            for (var i = 0; i < 2; i++) ...[
                              if (i > 0) const SizedBox(width: 10),
                              Expanded(
                                child: AspectRatio(
                                  aspectRatio: 16 / 10,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: i < imgs.length
                                        ? Builder(
                                            builder: (_) {
                                              final m =
                                                  MoodboardImageModel.fromRow(
                                                imgs[i],
                                              );
                                              final f = File(m.imagePath);
                                              return f.existsSync()
                                                  ? Image.file(
                                                      f,
                                                      fit: BoxFit.cover,
                                                    )
                                                  : ColoredBox(
                                                      color: palette
                                                          .surfaceOverlay,
                                                    );
                                            },
                                          )
                                        : ColoredBox(
                                            color: palette.surfaceOverlay,
                                            child: Icon(
                                              Icons.image_outlined,
                                              color: palette.textTertiary,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    );
                  },
                );
                if (sideBySide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: intentPanel),
                      const SizedBox(width: 20),
                      Expanded(child: thumbs),
                    ],
                  );
                }
                return Column(
                  children: [
                    intentPanel,
                    const SizedBox(height: 16),
                    thumbs,
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _hud(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: AppTypography.mono(palette).copyWith(
          fontSize: 11,
          color: Colors.white.withValues(alpha: 0.9),
          shadows: const [
            Shadow(blurRadius: 4, color: Colors.black87),
          ],
        ),
      ),
    );
  }
}

class _DirectionRefsGrid extends ConsumerWidget {
  final int projectId;
  final int bibleId;
  final AppPalette palette;
  final List<Map<String, dynamic>> meta;
  final VoidCallback onAddImage;
  final VoidCallback onAddMeta;
  final void Function(int index) onEditMeta;
  final VoidCallback onOpenMoodboard;

  const _DirectionRefsGrid({
    required this.projectId,
    required this.bibleId,
    required this.palette,
    required this.meta,
    required this.onAddImage,
    required this.onAddMeta,
    required this.onEditMeta,
    required this.onOpenMoodboard,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    return StreamBuilder<List<MoodboardImage>>(
      stream: db.watchMoodboardImagesForSection(
        projectId,
        BibleSectionId.direction,
      ),
      builder: (context, snap) {
        final images = snap.data ?? [];
        final count = images.isEmpty
            ? meta.length
            : (images.length > meta.length ? images.length : meta.length);

        return LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth >= 700 ? 2 : 1;
            return Column(
              children: [
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: count,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.95,
                  ),
                  itemBuilder: (context, i) {
                    final img = i < images.length ? images[i] : null;
                    final m = i < meta.length ? meta[i] : null;
                    return _RefCard(
                      image: img,
                      meta: m,
                      palette: palette,
                      onEditMeta: m != null ? () => onEditMeta(i) : onAddMeta,
                    );
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 120,
                  child: Row(
                    children: [
                      Expanded(
                        child: _AddDashedCard(
                          label: 'Añadir Referencia',
                          icon: Icons.add_photo_alternate_outlined,
                          palette: palette,
                          onTap: onAddImage,
                        ),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: onOpenMoodboard,
                        child: Text(
                          'Moodboard',
                          style: TextStyle(color: palette.accent),
                        ),
                      ),
                      TextButton(
                        onPressed: onAddMeta,
                        child: Text(
                          'Ficha',
                          style: TextStyle(color: palette.accent),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _RefCard extends StatelessWidget {
  final MoodboardImage? image;
  final Map<String, dynamic>? meta;
  final AppPalette palette;
  final VoidCallback onEditMeta;

  const _RefCard({
    required this.image,
    required this.meta,
    required this.palette,
    required this.onEditMeta,
  });

  @override
  Widget build(BuildContext context) {
    final model =
        image != null ? MoodboardImageModel.fromRow(image!) : null;
    final file =
        model != null ? File(model.imagePath) : null;
    final refLabel = meta?['refLabel']?.toString().isNotEmpty == true
        ? meta!['refLabel'].toString()
        : (model?.filmReference ?? 'REF');
    final title = meta?['title']?.toString().isNotEmpty == true
        ? meta!['title'].toString()
        : (model?.caption ?? 'Referencia');
    final body = meta?['body']?.toString() ?? '';
    final lens = meta?['lens']?.toString() ?? '—';
    final tech2Label = meta?['tech2Label']?.toString() ?? 'APERTURE';
    final tech2Value = meta?['tech2Value']?.toString() ?? '—';

    return _GlassPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (file != null && file.existsSync())
                  Image.file(file, fit: BoxFit.cover)
                else
                  ColoredBox(color: palette.surfaceOverlay),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xCC131315),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Text(
                      'REF: ${refLabel.toUpperCase()}',
                      style: AppTypography.mono(palette).copyWith(
                        fontSize: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: InkWell(
              onTap: onEditMeta,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.titleMedium(palette)
                          .copyWith(fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Text(
                        body.isEmpty ? 'Toca para añadir notas…' : body,
                        style: AppTypography.bodyMedium(palette).copyWith(
                          color: palette.textSecondary,
                          fontSize: 13,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.only(top: 10),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          _tech('LENS', lens),
                          const SizedBox(width: 24),
                          _tech(tech2Label, tech2Value),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tech(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.mono(palette).copyWith(
            fontSize: 10,
            letterSpacing: 1,
            color: palette.textTertiary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTypography.mono(palette).copyWith(
            fontSize: 13,
            color: palette.textPrimary,
          ),
        ),
      ],
    );
  }
}
