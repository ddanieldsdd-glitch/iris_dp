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
import '../../v2/model/bible_json_parse.dart';
import '../../moodboard_helpers.dart';
import '../../visual_bible_model.dart';
import '../bible_moodboard_image_target.dart';
import 'section_scaffold.dart';

/// Textura & Grain — layout Stitch (macro split + grain/diffusion + noise floor).
class TextureSection extends ConsumerWidget {
  final VisualBibleData data;
  final int projectId;
  final String? sectionContentJson;
  final BibleChanged onChanged;

  const TextureSection({
    super.key,
    required this.data,
    required this.projectId,
    this.sectionContentJson,
    required this.onChanged,
  });

  static const _grainPresets = [
    'Kodak Vision3 500T',
    'Kodak Vision3 250D',
    'Ilford HP5',
    'Custom',
  ];

  static const _diffusionFilters = [
    'Pro-Mist',
    'Black Magic',
    'Glimmerglass',
    'Hollywood Black',
  ];

  static const _densitySteps = ['1/8', '1/4', '1/2', '1', 'Full'];

  Map<String, dynamic> _getCustomData() {
    if (sectionContentJson == null || sectionContentJson!.isEmpty) return {};
    try {
      final decoded = jsonDecode(sectionContentJson!);
      if (decoded is! Map<String, dynamic>) return {};
      final valuesRaw = decoded['values'] ?? decoded['_values'];
      if (valuesRaw is Map) {
        final vals = Map<String, dynamic>.from(valuesRaw);
        if (vals['textureData'] is String) {
          final parsed = jsonDecode(vals['textureData'] as String);
          if (parsed is Map<String, dynamic>) return parsed;
        }
        return vals;
      }
    } catch (_) {}
    return {};
  }

  Future<void> _updateCustomData(
    WidgetRef ref,
    Map<String, dynamic> update, {
    bool syncBible = true,
  }) async {
    final current = _getCustomData();
    final newData = {...current, ...update};
    final db = ref.read(databaseProvider);
    final def = await (db.select(db.bibleSectionDefinitions)
          ..where(
            (d) =>
                d.bibleId.equals(data.id) &
                d.id.equals(BibleSectionId.texture),
          ))
        .getSingleOrNull();
    if (def == null) return;
    final fields = BibleSectionFieldsConfig.parse(
      def.contentJson,
      BibleSectionId.texture,
    );
    final values = BibleSectionFieldsConfig.parseValues(def.contentJson);
    values['textureData'] = jsonEncode(newData);
    await db.upsertBibleSectionDefinition(
      def.copyWith(
        contentJson: drift.Value(
          BibleSectionFieldsConfig.encode(fields, values: values),
        ),
      ),
    );

    if (!syncBible) return;
    _syncBibleFields(newData);
  }

  void _syncBibleFields(Map<String, dynamic> d) {
    var dirty = false;

    final preset = bibleJsonString(d['grainPreset']);
    if (preset != null && preset.isNotEmpty && data.grainLevel != preset) {
      data.grainLevel = preset;
      dirty = true;
    }

    final grainOn = bibleJsonBool(d['grainEnabled']) ?? false;
    final intensity = bibleJsonDouble(d['grainIntensity']);
    final sizeUm = bibleJsonDouble(d['grainSize']);
    if (grainOn && intensity != null) {
      final label =
          '${preset ?? 'Grain'} · ${sizeUm?.toStringAsFixed(1) ?? '—'}µm · ${(intensity * 100).round()}%';
      if (data.imageTexture != label) {
        data.imageTexture = label;
        dirty = true;
      }
    }

    final diffOn = bibleJsonBool(d['diffusionEnabled']) ?? false;
    final filter = bibleJsonString(d['diffusionFilter']);
    final density = bibleJsonString(d['diffusionDensity']);
    if (diffOn && filter != null) {
      final notes = '$filter ${density ?? ''}'.trim();
      if (data.diffusionNotes != notes) {
        data.diffusionNotes = notes;
        dirty = true;
      }
    }

    final hl = bibleJsonString(d['highlightBehavior']);
    if (hl != null && data.highlightBehavior != hl) {
      data.highlightBehavior = hl;
      dirty = true;
    }
    final sh = bibleJsonString(d['shadowBehavior']);
    if (sh != null && data.shadowBehavior != sh) {
      data.shadowBehavior = sh;
      dirty = true;
    }

    final pushPull = bibleJsonString(d['pushPullProcessing']);
    final chroma = bibleJsonString(d['shadowChromaNoise']);
    final fpn = bibleJsonString(d['fixedPatternNoise']);
    if (pushPull != null || chroma != null || fpn != null) {
      final parts = <String>[
        if (chroma != null && chroma.isNotEmpty) 'Chroma: $chroma',
        if (fpn != null && fpn.isNotEmpty) 'FPN: $fpn',
        if (pushPull != null && pushPull.isNotEmpty) 'Push/Pull: $pushPull',
      ];
      final joined = parts.join(' · ');
      if (joined.isNotEmpty && data.sensorShadowBehavior != joined) {
        data.sensorShadowBehavior = joined;
        dirty = true;
      }
    }

    if (dirty) onChanged(data);
  }

  Future<void> _reset(WidgetRef ref, BuildContext context) async {
    final defaults = <String, dynamic>{
      'grainEnabled': false,
      'grainSize': 1.5,
      'grainIntensity': 0.45,
      'grainColorVariation': 0.3,
      'grainPreset': 'Kodak Vision3 500T',
      'diffusionEnabled': false,
      'diffusionFilter': 'Pro-Mist',
      'diffusionDensity': '1/4',
      'halationRadius': 0.35,
      'highlightBehavior': 'Soft roll-off',
      'shadowBehavior': 'Preserve detail',
      'lumaMap': false,
      'splitView': true,
      'zoomLabel': '100%',
      'shadowChromaNoise': 'Low',
      'fixedPatternNoise': 'Minimal',
      'pushPullProcessing': 'None',
    };
    await _updateCustomData(ref, defaults);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Textura restablecida')),
      );
    }
  }

  Future<void> _savePreset(WidgetRef ref, BuildContext context) async {
    final name =
        'Preset ${DateTime.now().month}/${DateTime.now().day} ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}';
    await _updateCustomData(ref, {'savedPresetName': name}, syncBible: false);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preset guardado localmente')),
      );
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);
    final custom = _getCustomData();

    final grainEnabled = bibleJsonBool(custom['grainEnabled']) ?? false;
    final grainSize = bibleJsonDouble(custom['grainSize']) ?? 1.5;
    final grainIntensity =
        bibleJsonDouble(custom['grainIntensity']) ?? 0.45;
    final grainColorVariation =
        bibleJsonDouble(custom['grainColorVariation']) ?? 0.3;
    var grainPreset =
        bibleJsonString(custom['grainPreset']) ?? data.grainLevel ?? 'Kodak Vision3 500T';
    if (!_grainPresets.contains(grainPreset)) {
      grainPreset = _grainPresets.contains(data.grainLevel)
          ? data.grainLevel!
          : 'Custom';
    }

    final diffusionEnabled = bibleJsonBool(custom['diffusionEnabled']) ?? false;
    var diffusionFilter = bibleJsonString(custom['diffusionFilter']) ?? 'Pro-Mist';
    if (!_diffusionFilters.contains(diffusionFilter)) {
      diffusionFilter = 'Pro-Mist';
    }
    var diffusionDensity = bibleJsonString(custom['diffusionDensity']) ?? '1/4';
    if (!_densitySteps.contains(diffusionDensity)) {
      diffusionDensity = '1/4';
    }
    final halationRadius =
        bibleJsonDouble(custom['halationRadius']) ?? 0.35;

    final highlightBehavior = bibleJsonString(custom['highlightBehavior']) ??
        data.highlightBehavior ??
        'Soft roll-off';
    final shadowBehavior = bibleJsonString(custom['shadowBehavior']) ??
        data.shadowBehavior ??
        'Preserve detail';

    final lumaMap = bibleJsonBool(custom['lumaMap']) ?? false;
    final splitView = bibleJsonBool(custom['splitView']) ?? true;
    final zoomLabel = bibleJsonString(custom['zoomLabel']) ?? '100%';

    final shadowChroma =
        bibleJsonString(custom['shadowChromaNoise']) ?? 'Low';
    final fixedPattern =
        bibleJsonString(custom['fixedPatternNoise']) ?? 'Minimal';
    final pushPull =
        bibleJsonString(custom['pushPullProcessing']) ?? 'None';
    final noiseDesc = bibleJsonString(custom['noiseFloorDesc']) ??
        data.sensorShadowBehavior ??
        'Caracterización del ruido nativo del sensor en sombras profundas y pushes.';
    final cameraLabelOverride = bibleJsonString(custom['cameraLabel']);
    final savedPreset = bibleJsonString(custom['savedPresetName']);

    final iso = data.nativeIso ?? 800;
    final digitalNoiseLabel =
        bibleJsonString(custom['digitalNoiseLabel']) ??
            'Digital Sensor Noise (ISO $iso)';

    final filmGrainWidget = _FilmGrainModule(
      enabled: grainEnabled,
      sizeUm: grainSize,
      intensity: grainIntensity,
      colorVariation: grainColorVariation,
      preset: grainPreset,
      palette: palette,
      onToggle: (v) => _updateCustomData(ref, {'grainEnabled': v}),
      onSizeEnd: (v) => _updateCustomData(ref, {'grainSize': v}),
      onIntensityEnd: (v) => _updateCustomData(ref, {'grainIntensity': v}),
      onColorVarEnd: (v) => _updateCustomData(ref, {'grainColorVariation': v}),
      onPreset: (v) {
        data.grainLevel = v;
        onChanged(data);
        _updateCustomData(ref, {'grainPreset': v});
      },
    );

    final diffusionWidget = _DiffusionOpticsModule(
      enabled: diffusionEnabled,
      filter: diffusionFilter,
      density: diffusionDensity,
      halationRadius: halationRadius,
      palette: palette,
      onToggle: (v) => _updateCustomData(ref, {'diffusionEnabled': v}),
      onFilter: (v) {
        final notes = '$v $diffusionDensity'.trim();
        data.diffusionNotes = notes;
        onChanged(data);
        _updateCustomData(ref, {'diffusionFilter': v});
      },
      onDensity: (v) {
        final notes = '$diffusionFilter $v'.trim();
        data.diffusionNotes = notes;
        onChanged(data);
        _updateCustomData(ref, {'diffusionDensity': v});
      },
      onHalationEnd: (v) => _updateCustomData(ref, {'halationRadius': v}),
    );

    Widget cameraSlot(String slot) => _TextureCameraSlot(
          slot: slot,
          db: db,
          data: data,
          projectId: projectId,
          onChanged: onChanged,
          palette: palette,
          iso: iso,
          grainPreset: grainPreset,
          digitalNoiseLabel: digitalNoiseLabel,
          highlightBehavior: highlightBehavior,
          shadowBehavior: shadowBehavior,
          zoomLabel: zoomLabel,
          lumaMap: lumaMap,
          splitView: splitView,
          noiseDesc: noiseDesc,
          cameraLabelOverride: cameraLabelOverride,
          shadowChroma: shadowChroma,
          fixedPattern: fixedPattern,
          pushPull: pushPull,
          grainEnabled: grainEnabled,
          grainSize: grainSize,
          grainIntensity: grainIntensity,
          grainColorVariation: grainColorVariation,
          diffusionEnabled: diffusionEnabled,
          diffusionFilter: diffusionFilter,
          diffusionDensity: diffusionDensity,
          halationRadius: halationRadius,
          updateCustomData: _updateCustomData,
          prompt: _prompt,
        );

    return BibleSectionScaffold(
      sectionId: BibleSectionId.texture,
      projectId: projectId,
      data: data,
      onChanged: onChanged,
      sectionContentJson: sectionContentJson,
      narrativeHint:
          '¿Qué textura de imagen refuerza el tono emocional y la calidad táctil?',
      sectionNumber: null,
      sectionTitle: 'Texture & Grain',
      fieldWidgets: {
        'narrative': _TextureHeader(
          palette: palette,
          subtitle: data.textureNarrativeIntent?.isNotEmpty == true
              ? data.textureNarrativeIntent!
              : 'Calidad táctil de la imagen: grano, difusión y ruido de sensor.',
          savedPreset: savedPreset,
          onReset: () => _reset(ref, context),
          onSavePreset: () => _savePreset(ref, context),
        ),
        'macroPreview': cameraSlot('macroPreview'),
        'filmGrain': filmGrainWidget,
        'diffusion': diffusionWidget,
        'sensorNoise': cameraSlot('sensorNoise'),
      },
    );
  }
}

/// Slots que dependen de la cámara activa (preview macro, noise floor, layout legacy).
class _TextureCameraSlot extends ConsumerWidget {
  final String slot;
  final AppDatabase db;
  final VisualBibleData data;
  final int projectId;
  final BibleChanged onChanged;
  final AppPalette palette;
  final int iso;
  final String grainPreset;
  final String digitalNoiseLabel;
  final String highlightBehavior;
  final String shadowBehavior;
  final String zoomLabel;
  final bool lumaMap;
  final bool splitView;
  final String noiseDesc;
  final String? cameraLabelOverride;
  final String shadowChroma;
  final String fixedPattern;
  final String pushPull;
  final bool grainEnabled;
  final double grainSize;
  final double grainIntensity;
  final double grainColorVariation;
  final bool diffusionEnabled;
  final String diffusionFilter;
  final String diffusionDensity;
  final double halationRadius;
  final Future<void> Function(WidgetRef ref, Map<String, dynamic> update,
      {bool syncBible})
      updateCustomData;
  final Future<String?> Function(
    BuildContext context,
    String title,
    TextEditingController c, {
    int maxLines,
  }) prompt;

  const _TextureCameraSlot({
    required this.slot,
    required this.db,
    required this.data,
    required this.projectId,
    required this.onChanged,
    required this.palette,
    required this.iso,
    required this.grainPreset,
    required this.digitalNoiseLabel,
    required this.highlightBehavior,
    required this.shadowBehavior,
    required this.zoomLabel,
    required this.lumaMap,
    required this.splitView,
    required this.noiseDesc,
    required this.cameraLabelOverride,
    required this.shadowChroma,
    required this.fixedPattern,
    required this.pushPull,
    required this.grainEnabled,
    required this.grainSize,
    required this.grainIntensity,
    required this.grainColorVariation,
    required this.diffusionEnabled,
    required this.diffusionFilter,
    required this.diffusionDensity,
    required this.halationRadius,
    required this.updateCustomData,
    required this.prompt,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<Camera>>(
      stream: db.watchAllCameras(),
      builder: (context, camSnap) {
        final cameras = camSnap.data ?? [];
        Camera? cam;
        if (data.primaryCameraId != null) {
          for (final c in cameras) {
            if (c.id == data.primaryCameraId) {
              cam = c;
              break;
            }
          }
        }
        final cameraBadge = cameraLabelOverride?.isNotEmpty == true
            ? cameraLabelOverride!
            : (cam != null
                ? '${cam.brand} ${cam.model}'
                : 'Cámara no asignada');
        final baseIso = cam?.nativeIso ?? data.nativeIso ?? iso;

        final preview = _MacroSplitPreview(
          projectId: projectId,
          leftLabel: grainPreset.contains('Emulation')
              ? grainPreset
              : '$grainPreset Emulation',
          rightLabel: digitalNoiseLabel,
          highlightBehavior: highlightBehavior,
          shadowBehavior: shadowBehavior,
          zoomLabel: zoomLabel,
          lumaMap: lumaMap,
          splitView: splitView,
          palette: palette,
          onEditHighlight: () async {
            final c = TextEditingController(text: highlightBehavior);
            final v = await prompt(context, 'Highlight Roll-off', c, maxLines: 2);
            if (v == null || v.isEmpty) return;
            data.highlightBehavior = v;
            onChanged(data);
            await updateCustomData(ref, {'highlightBehavior': v});
          },
          onEditShadow: () async {
            final c = TextEditingController(text: shadowBehavior);
            final v = await prompt(context, 'Shadow Detail', c, maxLines: 2);
            if (v == null || v.isEmpty) return;
            data.shadowBehavior = v;
            onChanged(data);
            await updateCustomData(ref, {'shadowBehavior': v});
          },
          onToggleLuma: () => updateCustomData(ref, {'lumaMap': !lumaMap}),
          onToggleSplit: () => updateCustomData(ref, {'splitView': !splitView}),
          onEditZoom: () async {
            final c = TextEditingController(text: zoomLabel);
            final v = await prompt(context, 'Zoom', c);
            if (v == null || v.isEmpty) return;
            await updateCustomData(ref, {'zoomLabel': v});
          },
          onEditDigitalLabel: () async {
            final c = TextEditingController(text: digitalNoiseLabel);
            final v = await prompt(context, 'Etiqueta ruido digital', c);
            if (v == null || v.isEmpty) return;
            await updateCustomData(ref, {'digitalNoiseLabel': v});
          },
        );

        final noiseFloor = _SensorNoiseFloor(
          description: noiseDesc,
          cameraBadge: cameraBadge,
          baseIso: baseIso,
          shadowChroma: shadowChroma,
          fixedPattern: fixedPattern,
          pushPull: pushPull,
          palette: palette,
          onEditDesc: () async {
            final c = TextEditingController(text: noiseDesc);
            final v = await prompt(context, 'Sensor Noise Floor', c, maxLines: 3);
            if (v == null) return;
            data.sensorShadowBehavior = v;
            onChanged(data);
            await updateCustomData(ref, {'noiseFloorDesc': v});
          },
          onEditCamera: () async {
            final c = TextEditingController(text: cameraBadge);
            final v = await prompt(context, 'Cámara', c);
            if (v == null) return;
            await updateCustomData(ref, {'cameraLabel': v});
          },
          onEditChroma: () async {
            final c = TextEditingController(text: shadowChroma);
            final v = await prompt(context, 'Shadow Chroma Noise', c);
            if (v == null || v.isEmpty) return;
            await updateCustomData(ref, {'shadowChromaNoise': v});
          },
          onEditFpn: () async {
            final c = TextEditingController(text: fixedPattern);
            final v = await prompt(context, 'Fixed Pattern Noise', c);
            if (v == null || v.isEmpty) return;
            await updateCustomData(ref, {'fixedPatternNoise': v});
          },
          onEditPushPull: () async {
            final c = TextEditingController(text: pushPull);
            final v = await prompt(context, 'Push/Pull Processing', c);
            if (v == null || v.isEmpty) return;
            await updateCustomData(ref, {'pushPullProcessing': v});
          },
          onCalibrate: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Dark frame calibrado')),
            );
          },
        );

        if (slot == 'macroPreview') return preview;
        if (slot == 'sensorNoise') return noiseFloor;

        final controls = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FilmGrainModule(
              enabled: grainEnabled,
              sizeUm: grainSize,
              intensity: grainIntensity,
              colorVariation: grainColorVariation,
              preset: grainPreset,
              palette: palette,
              onToggle: (v) => updateCustomData(ref, {'grainEnabled': v}),
              onSizeEnd: (v) => updateCustomData(ref, {'grainSize': v}),
              onIntensityEnd: (v) =>
                  updateCustomData(ref, {'grainIntensity': v}),
              onColorVarEnd: (v) =>
                  updateCustomData(ref, {'grainColorVariation': v}),
              onPreset: (v) {
                data.grainLevel = v;
                onChanged(data);
                updateCustomData(ref, {'grainPreset': v});
              },
            ),
            const SizedBox(height: 14),
            _DiffusionOpticsModule(
              enabled: diffusionEnabled,
              filter: diffusionFilter,
              density: diffusionDensity,
              halationRadius: halationRadius,
              palette: palette,
              onToggle: (v) => updateCustomData(ref, {'diffusionEnabled': v}),
              onFilter: (v) {
                final notes = '$v $diffusionDensity'.trim();
                data.diffusionNotes = notes;
                onChanged(data);
                updateCustomData(ref, {'diffusionFilter': v});
              },
              onDensity: (v) {
                final notes = '$diffusionFilter $v'.trim();
                data.diffusionNotes = notes;
                onChanged(data);
                updateCustomData(ref, {'diffusionDensity': v});
              },
              onHalationEnd: (v) =>
                  updateCustomData(ref, {'halationRadius': v}),
            ),
          ],
        );

        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 960;
            if (wide) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 3, child: preview),
                        const SizedBox(width: 14),
                        Expanded(flex: 2, child: controls),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  noiseFloor,
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                preview,
                const SizedBox(height: 14),
                controls,
                const SizedBox(height: 14),
                noiseFloor,
              ],
            );
          },
        );
      },
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _TextureHeader extends StatelessWidget {
  final AppPalette palette;
  final String subtitle;
  final String? savedPreset;
  final VoidCallback onReset;
  final VoidCallback onSavePreset;

  const _TextureHeader({
    required this.palette,
    required this.subtitle,
    required this.savedPreset,
    required this.onReset,
    required this.onSavePreset,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Texture & Grain',
                style: AppTypography.displayMedium(palette).copyWith(
                  fontSize: 32,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: AppTypography.bodyMedium(palette).copyWith(
                  color: palette.textSecondary,
                  height: 1.4,
                ),
              ),
              if (savedPreset != null && savedPreset!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Preset: $savedPreset',
                  style: AppTypography.mono(palette).copyWith(
                    fontSize: 11,
                    color: palette.accent,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        TextButton(
          onPressed: onReset,
          child: Text(
            'Reset',
            style: AppTypography.mono(palette).copyWith(fontSize: 12),
          ),
        ),
        const SizedBox(width: 4),
        FilledButton.tonal(
          onPressed: onSavePreset,
          child: Text(
            'Save Preset',
            style: AppTypography.mono(palette).copyWith(fontSize: 12),
          ),
        ),
      ],
    );
  }
}

// ─── Macro split preview ─────────────────────────────────────────────────────

class _MacroSplitPreview extends ConsumerWidget {
  final int projectId;
  final String leftLabel;
  final String rightLabel;
  final String highlightBehavior;
  final String shadowBehavior;
  final String zoomLabel;
  final bool lumaMap;
  final bool splitView;
  final AppPalette palette;
  final VoidCallback onEditHighlight;
  final VoidCallback onEditShadow;
  final VoidCallback onToggleLuma;
  final VoidCallback onToggleSplit;
  final VoidCallback onEditZoom;
  final VoidCallback onEditDigitalLabel;

  const _MacroSplitPreview({
    required this.projectId,
    required this.leftLabel,
    required this.rightLabel,
    required this.highlightBehavior,
    required this.shadowBehavior,
    required this.zoomLabel,
    required this.lumaMap,
    required this.splitView,
    required this.palette,
    required this.onEditHighlight,
    required this.onEditShadow,
    required this.onToggleLuma,
    required this.onToggleSplit,
    required this.onEditZoom,
    required this.onEditDigitalLabel,
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
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ChipButton(
                  label: 'Highlight Roll-off',
                  value: highlightBehavior,
                  palette: palette,
                  onTap: onEditHighlight,
                ),
                _ChipButton(
                  label: 'Shadow Detail',
                  value: shadowBehavior,
                  palette: palette,
                  onTap: onEditShadow,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          BibleMoodboardImageTarget(
            projectId: projectId,
            sectionId: BibleSectionId.texture,
            hint: 'Clic aquí → ⌘V para pegar textura',
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: ColoredBox(
                color: Colors.black,
                child: StreamBuilder<List<MoodboardImage>>(
                stream: db.watchMoodboardImagesForSection(
                  projectId,
                  BibleSectionId.texture,
                ),
                builder: (context, snap) {
                  final imgs = snap.data ?? [];
                  final left = imgs.isNotEmpty ? imgs.first : null;
                  final right =
                      imgs.length > 1 ? imgs[1] : left;

                  Widget half(MoodboardImage? img, {required bool leftSide}) {
                    Widget content;
                    if (img != null && File(img.imagePath).existsSync()) {
                      content = Image.file(
                        File(img.imagePath),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      );
                    } else {
                      content = ColoredBox(
                        color: const Color(0xFF121214),
                        child: Center(
                          child: TextButton.icon(
                            onPressed: () => MoodboardHelpers.addManualImages(
                              db: db,
                              projectId: projectId,
                              category: MoodboardCategory.texture,
                              assignedSections: [BibleSectionId.texture],
                            ),
                            icon: Icon(Icons.add_photo_alternate_outlined,
                                color: palette.accent, size: 20),
                            label: Text(
                              'Añadir textura',
                              style: TextStyle(
                                color: palette.accent,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    if (lumaMap) {
                      content = ColorFiltered(
                        colorFilter: const ColorFilter.matrix(<double>[
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0, 0, 0, 1, 0,
                        ]),
                        child: content,
                      );
                    }

                    // Slight warm cast on film side vs cooler digital side.
                    if (!lumaMap && leftSide) {
                      content = ColorFiltered(
                        colorFilter: const ColorFilter.mode(
                          Color(0x22C4A574),
                          BlendMode.softLight,
                        ),
                        child: content,
                      );
                    } else if (!lumaMap && !leftSide) {
                      content = ColorFiltered(
                        colorFilter: const ColorFilter.mode(
                          Color(0x183A5A80),
                          BlendMode.softLight,
                        ),
                        child: content,
                      );
                    }

                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        content,
                        Positioned(
                          left: 10,
                          right: 10,
                          bottom: 10,
                          child: Align(
                            alignment: leftSide
                                ? Alignment.bottomLeft
                                : Alignment.bottomRight,
                            child: InkWell(
                              onTap: leftSide
                                  ? null
                                  : onEditDigitalLabel,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  leftSide ? leftLabel : rightLabel,
                                  style: AppTypography.mono(palette).copyWith(
                                    fontSize: 10,
                                    letterSpacing: 0.4,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  if (!splitView) {
                    return half(left, leftSide: true);
                  }

                  return Row(
                    children: [
                      Expanded(child: half(left, leftSide: true)),
                      Container(
                        width: 1.5,
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                      Expanded(child: half(right, leftSide: false)),
                    ],
                  );
                },
              ),
            ),
          ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1B1D),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: onEditZoom,
                  child: Row(
                    children: [
                      Icon(Icons.zoom_in,
                          size: 14, color: palette.textTertiary),
                      const SizedBox(width: 6),
                      Text(
                        'Zoom $zoomLabel',
                        style: AppTypography.mono(palette).copyWith(
                          fontSize: 11,
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                _ToolbarToggle(
                  label: 'Luma Map',
                  active: lumaMap,
                  palette: palette,
                  onTap: onToggleLuma,
                ),
                const SizedBox(width: 8),
                _ToolbarToggle(
                  label: 'Split View',
                  active: splitView,
                  palette: palette,
                  onTap: onToggleSplit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipButton extends StatelessWidget {
  final String label;
  final String value;
  final AppPalette palette;
  final VoidCallback onTap;

  const _ChipButton({
    required this.label,
    required this.value,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF1F1F21),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: AppTypography.mono(palette).copyWith(
                fontSize: 9,
                letterSpacing: 1.0,
                color: palette.textTertiary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: AppTypography.mono(palette).copyWith(
                fontSize: 11,
                color: palette.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolbarToggle extends StatelessWidget {
  final String label;
  final bool active;
  final AppPalette palette;
  final VoidCallback onTap;

  const _ToolbarToggle({
    required this.label,
    required this.active,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? palette.accent.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active
                ? palette.accent.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: AppTypography.mono(palette).copyWith(
            fontSize: 10,
            color: active ? palette.accent : palette.textTertiary,
          ),
        ),
      ),
    );
  }
}

// ─── Film Grain ──────────────────────────────────────────────────────────────

class _FilmGrainModule extends StatelessWidget {
  final bool enabled;
  final double sizeUm;
  final double intensity;
  final double colorVariation;
  final String preset;
  final AppPalette palette;
  final ValueChanged<bool> onToggle;
  final ValueChanged<double> onSizeEnd;
  final ValueChanged<double> onIntensityEnd;
  final ValueChanged<double> onColorVarEnd;
  final ValueChanged<String> onPreset;

  const _FilmGrainModule({
    required this.enabled,
    required this.sizeUm,
    required this.intensity,
    required this.colorVariation,
    required this.preset,
    required this.palette,
    required this.onToggle,
    required this.onSizeEnd,
    required this.onIntensityEnd,
    required this.onColorVarEnd,
    required this.onPreset,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.grain, size: 16, color: palette.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Film Grain',
                  style: AppTypography.titleMedium(palette)
                      .copyWith(fontSize: 16),
                ),
              ),
              Switch(
                value: enabled,
                onChanged: onToggle,
                activeThumbColor: palette.accent,
              ),
            ],
          ),
          if (enabled) ...[
            const SizedBox(height: 12),
            _PersistSlider(
              label: 'Size',
              unit: 'µm',
              value: sizeUm.clamp(0.2, 5.0),
              min: 0.2,
              max: 5.0,
              divisions: 48,
              display: (v) => v.toStringAsFixed(1),
              palette: palette,
              onChangeEnd: onSizeEnd,
            ),
            _PersistSlider(
              label: 'Intensity',
              unit: '%',
              value: (intensity * 100).clamp(0, 100),
              min: 0,
              max: 100,
              divisions: 100,
              display: (v) => '${v.round()}',
              palette: palette,
              onChangeEnd: (v) => onIntensityEnd(v / 100),
            ),
            _PersistSlider(
              label: 'Color Variation',
              unit: '%',
              value: (colorVariation * 100).clamp(0, 100),
              min: 0,
              max: 100,
              divisions: 100,
              display: (v) => '${v.round()}',
              palette: palette,
              onChangeEnd: (v) => onColorVarEnd(v / 100),
            ),
            const SizedBox(height: 8),
            Text(
              'STOCK EMULATION',
              style: AppTypography.mono(palette).copyWith(
                fontSize: 10,
                letterSpacing: 1.2,
                color: palette.textTertiary,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: ValueKey(preset),
              initialValue: TextureSection._grainPresets.contains(preset)
                  ? preset
                  : 'Custom',
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: const Color(0xFF1F1F21),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              dropdownColor: const Color(0xFF1F1F21),
              style: AppTypography.mono(palette).copyWith(fontSize: 12),
              items: [
                for (final p in TextureSection._grainPresets)
                  DropdownMenuItem(value: p, child: Text(p)),
              ],
              onChanged: (v) {
                if (v != null) onPreset(v);
              },
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Diffusion Optics ────────────────────────────────────────────────────────

class _DiffusionOpticsModule extends StatelessWidget {
  final bool enabled;
  final String filter;
  final String density;
  final double halationRadius;
  final AppPalette palette;
  final ValueChanged<bool> onToggle;
  final ValueChanged<String> onFilter;
  final ValueChanged<String> onDensity;
  final ValueChanged<double> onHalationEnd;

  const _DiffusionOpticsModule({
    required this.enabled,
    required this.filter,
    required this.density,
    required this.halationRadius,
    required this.palette,
    required this.onToggle,
    required this.onFilter,
    required this.onDensity,
    required this.onHalationEnd,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.blur_on, size: 16, color: palette.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Diffusion Optics',
                  style: AppTypography.titleMedium(palette)
                      .copyWith(fontSize: 16),
                ),
              ),
              Switch(
                value: enabled,
                onChanged: onToggle,
                activeThumbColor: palette.accent,
              ),
            ],
          ),
          if (enabled) ...[
            const SizedBox(height: 12),
            Text(
              'FILTER TYPE',
              style: AppTypography.mono(palette).copyWith(
                fontSize: 10,
                letterSpacing: 1.2,
                color: palette.textTertiary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final f in TextureSection._diffusionFilters)
                  _SelectChip(
                    label: f,
                    selected: filter == f,
                    palette: palette,
                    onTap: () => onFilter(f),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'STRENGTH DENSITY',
              style: AppTypography.mono(palette).copyWith(
                fontSize: 10,
                letterSpacing: 1.2,
                color: palette.textTertiary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final d in TextureSection._densitySteps) ...[
                  if (d != TextureSection._densitySteps.first)
                    const SizedBox(width: 4),
                  Expanded(
                    child: _SelectChip(
                      label: d,
                      selected: density == d,
                      palette: palette,
                      compact: true,
                      onTap: () => onDensity(d),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            _PersistSlider(
              label: 'Halation Radius',
              unit: '',
              value: halationRadius.clamp(0, 1),
              min: 0,
              max: 1,
              divisions: 100,
              display: (v) => '${(v * 100).round()}%',
              palette: palette,
              onChangeEnd: onHalationEnd,
            ),
          ],
        ],
      ),
    );
  }
}

class _SelectChip extends StatelessWidget {
  final String label;
  final bool selected;
  final AppPalette palette;
  final VoidCallback onTap;
  final bool compact;

  const _SelectChip({
    required this.label,
    required this.selected,
    required this.palette,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: compact ? double.infinity : null,
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 4 : 10,
          vertical: compact ? 8 : 7,
        ),
        decoration: BoxDecoration(
          color: selected
              ? palette.accent.withValues(alpha: 0.18)
              : const Color(0xFF1F1F21),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected
                ? palette.accent.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.mono(palette).copyWith(
            fontSize: compact ? 10 : 11,
            color: selected ? palette.accent : palette.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─── Sensor Noise Floor ──────────────────────────────────────────────────────

class _SensorNoiseFloor extends StatelessWidget {
  final String description;
  final String cameraBadge;
  final int baseIso;
  final String shadowChroma;
  final String fixedPattern;
  final String pushPull;
  final AppPalette palette;
  final VoidCallback onEditDesc;
  final VoidCallback onEditCamera;
  final VoidCallback onEditChroma;
  final VoidCallback onEditFpn;
  final VoidCallback onEditPushPull;
  final VoidCallback onCalibrate;

  const _SensorNoiseFloor({
    required this.description,
    required this.cameraBadge,
    required this.baseIso,
    required this.shadowChroma,
    required this.fixedPattern,
    required this.pushPull,
    required this.palette,
    required this.onEditDesc,
    required this.onEditCamera,
    required this.onEditChroma,
    required this.onEditFpn,
    required this.onEditPushPull,
    required this.onCalibrate,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sensors, size: 16, color: palette.accent),
              const SizedBox(width: 8),
              Text(
                'Sensor Noise Floor',
                style: AppTypography.titleMedium(palette)
                    .copyWith(fontSize: 16),
              ),
              const Spacer(),
              InkWell(
                onTap: onEditCamera,
                child: _Badge(label: cameraBadge, palette: palette),
              ),
              const SizedBox(width: 8),
              _Badge(label: 'Base ISO $baseIso', palette: palette, accent: true),
            ],
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: onEditDesc,
            child: Text(
              description.isEmpty
                  ? 'Toca para describir el comportamiento del ruido…'
                  : description,
              style: AppTypography.bodyMedium(palette).copyWith(
                color: palette.textSecondary,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth >= 720 ? 3 : (c.maxWidth >= 420 ? 2 : 1);
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: cols == 1
                        ? c.maxWidth
                        : (c.maxWidth - 10 * (cols - 1)) / cols,
                    child: _NoiseCard(
                      title: 'Shadow Chroma Noise',
                      value: shadowChroma,
                      palette: palette,
                      onTap: onEditChroma,
                    ),
                  ),
                  SizedBox(
                    width: cols == 1
                        ? c.maxWidth
                        : (c.maxWidth - 10 * (cols - 1)) / cols,
                    child: _NoiseCard(
                      title: 'Fixed Pattern Noise',
                      value: fixedPattern,
                      palette: palette,
                      onTap: onEditFpn,
                    ),
                  ),
                  SizedBox(
                    width: cols == 1
                        ? c.maxWidth
                        : (c.maxWidth - 10 * (cols - 1)) / cols,
                    child: _NoiseCard(
                      title: 'Push/Pull Processing',
                      value: pushPull,
                      palette: palette,
                      onTap: onEditPushPull,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: onCalibrate,
              icon: Icon(Icons.dark_mode_outlined,
                  size: 16, color: palette.accent),
              label: Text(
                'Calibrate Dark Frame',
                style: AppTypography.mono(palette).copyWith(
                  fontSize: 11,
                  color: palette.accent,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: palette.accent.withValues(alpha: 0.4),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final AppPalette palette;
  final bool accent;

  const _Badge({
    required this.label,
    required this.palette,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent
            ? palette.accent.withValues(alpha: 0.12)
            : const Color(0xFF1F1F21),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: accent
              ? palette.accent.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Text(
        label,
        style: AppTypography.mono(palette).copyWith(
          fontSize: 10,
          color: accent ? palette.accent : palette.textSecondary,
        ),
      ),
    );
  }
}

class _NoiseCard extends StatelessWidget {
  final String title;
  final String value;
  final AppPalette palette;
  final VoidCallback onTap;

  const _NoiseCard({
    required this.title,
    required this.value,
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
              title.toUpperCase(),
              style: AppTypography.mono(palette).copyWith(
                fontSize: 10,
                letterSpacing: 1.0,
                color: palette.textTertiary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: AppTypography.titleMedium(palette).copyWith(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Persist slider ──────────────────────────────────────────────────────────

class _PersistSlider extends StatefulWidget {
  final String label;
  final String unit;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String Function(double) display;
  final AppPalette palette;
  final ValueChanged<double> onChangeEnd;

  const _PersistSlider({
    required this.label,
    required this.unit,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.palette,
    required this.onChangeEnd,
    this.divisions,
  });

  @override
  State<_PersistSlider> createState() => _PersistSliderState();
}

class _PersistSliderState extends State<_PersistSlider> {
  late double _local;

  @override
  void initState() {
    super.initState();
    _local = widget.value;
  }

  @override
  void didUpdateWidget(covariant _PersistSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _local = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              widget.label,
              style: AppTypography.mono(palette).copyWith(
                fontSize: 11,
                color: palette.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              '${widget.display(_local)}${widget.unit.isEmpty ? '' : ' ${widget.unit}'}',
              style: AppTypography.mono(palette).copyWith(
                fontSize: 11,
                color: palette.accent,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: Slider(
            value: _local.clamp(widget.min, widget.max),
            min: widget.min,
            max: widget.max,
            divisions: widget.divisions,
            activeColor: palette.accent,
            inactiveColor: Colors.white12,
            onChanged: (v) => setState(() => _local = v),
            onChangeEnd: widget.onChangeEnd,
          ),
        ),
      ],
    );
  }
}

// ─── Glass panel ─────────────────────────────────────────────────────────────

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
