import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/visual_bible/format_pilot_resolve.dart';
import '../../bible_section_fields.dart';
import '../../moodboard_helpers.dart';
import '../../visual_bible_model.dart';
import '../bible_form_widgets.dart';
import '../bible_moodboard_image_target.dart';
import '../bible_visual_color_sheet.dart';
import '../moodboard_strip.dart';
import 'section_scaffold.dart';

/// Concepto de imagen — Stitch Production + Visual Bible (glass bento).
class ConceptSection extends ConsumerWidget {
  final VisualBibleData data;
  final int projectId;
  final String? sectionContentJson;
  final String? formatSectionContentJson;
  final BibleChanged onChanged;

  const ConceptSection({
    super.key,
    required this.data,
    required this.projectId,
    this.sectionContentJson,
    this.formatSectionContentJson,
    required this.onChanged,
  });

  Map<String, dynamic> _getCustomData() {
    if (sectionContentJson == null) return {};
    try {
      final decoded = jsonDecode(sectionContentJson!);
      if (decoded is Map<String, dynamic> && decoded.containsKey('_values')) {
        final vals = decoded['_values'] as Map<String, dynamic>;
        if (vals.containsKey('conceptData')) {
          return jsonDecode(vals['conceptData'] as String)
              as Map<String, dynamic>;
        }
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
                d.id.equals(BibleSectionId.concept),
          ))
        .getSingleOrNull();
    if (def != null) {
      final fields = BibleSectionFieldsConfig.parse(
        def.contentJson,
        BibleSectionId.concept,
      );
      final values = BibleSectionFieldsConfig.parseValues(def.contentJson);
      values['conceptData'] = jsonEncode(newData);
      await db.upsertBibleSectionDefinition(
        def.copyWith(
          contentJson: drift.Value(
            BibleSectionFieldsConfig.encode(fields, values: values),
          ),
        ),
      );
    }
  }

  Color? _parseHex(String? hex) {
    if (hex == null) return null;
    var h = hex.trim();
    if (h.startsWith('#')) h = h.substring(1);
    if (h.length != 6) return null;
    final v = int.tryParse(h, radix: 16);
    if (v == null) return null;
    return Color(0xFF000000 | v);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    return BibleSectionScaffold(
      sectionId: BibleSectionId.concept,
      projectId: projectId,
      data: data,
      onChanged: onChanged,
      sectionContentJson: sectionContentJson,
      narrativeHint: '¿Qué debe sentir el ojo del espectador en cada acto?',
      sectionNumber: null,
      sectionTitle: 'Concepto de Imagen',
      fieldWidgets: {
        'colorPalette': _ConceptStitchModule(
          slot: 'colorPalette',
          data: data,
          projectId: projectId,
          palette: palette,
          db: db,
          onChanged: onChanged,
          sectionContentJson: sectionContentJson,
          formatSectionContentJson: formatSectionContentJson,
          parseHex: _parseHex,
          updateCustomData: _updateCustomData,
        ),
        'colorSymbolism': _ConceptStitchModule(
          slot: 'colorSymbolism',
          data: data,
          projectId: projectId,
          palette: palette,
          db: db,
          onChanged: onChanged,
          sectionContentJson: sectionContentJson,
          formatSectionContentJson: formatSectionContentJson,
          parseHex: _parseHex,
          updateCustomData: _updateCustomData,
        ),
        'lightPhilosophy': _ConceptStitchModule(
          slot: 'lightPhilosophy',
          data: data,
          projectId: projectId,
          palette: palette,
          db: db,
          onChanged: onChanged,
          sectionContentJson: sectionContentJson,
          formatSectionContentJson: formatSectionContentJson,
          parseHex: _parseHex,
          updateCustomData: _updateCustomData,
        ),
        'keyFrame': _ConceptStitchModule(
          slot: 'keyFrame',
          data: data,
          projectId: projectId,
          palette: palette,
          db: db,
          onChanged: onChanged,
          sectionContentJson: sectionContentJson,
          formatSectionContentJson: formatSectionContentJson,
          parseHex: _parseHex,
          updateCustomData: _updateCustomData,
        ),
        'shadowTreatment': _ConceptStitchModule(
          slot: 'shadowTreatment',
          data: data,
          projectId: projectId,
          palette: palette,
          db: db,
          onChanged: onChanged,
          sectionContentJson: sectionContentJson,
          formatSectionContentJson: formatSectionContentJson,
          parseHex: _parseHex,
          updateCustomData: _updateCustomData,
        ),
        'actComposition': _ConceptStitchModule(
          slot: 'actComposition',
          data: data,
          projectId: projectId,
          palette: palette,
          db: db,
          onChanged: onChanged,
          sectionContentJson: sectionContentJson,
          formatSectionContentJson: formatSectionContentJson,
          parseHex: _parseHex,
          updateCustomData: _updateCustomData,
        ),
        'actNotes': _ConceptStitchModule(
          slot: 'actNotes',
          data: data,
          projectId: projectId,
          palette: palette,
          db: db,
          onChanged: onChanged,
          sectionContentJson: sectionContentJson,
          formatSectionContentJson: formatSectionContentJson,
          parseHex: _parseHex,
          updateCustomData: _updateCustomData,
        ),
      },
    );
  }

  Future<Map<String, dynamic>?> _editSymbolDialog(
    BuildContext context, {
    required String name,
    required String meaning,
    required String hex,
  }) async {
    final picked = await BibleVisualColorSheet.show(
      context,
      title: 'Simbología de color',
      initialName: name,
      initialColor: _parseHex(hex) ?? const Color(0xFF1B3A4B),
      nameHint: 'Nombre poético del color',
      includeMeaning: true,
      initialMeaning: meaning,
    );
    if (picked == null || picked.delete) return null;
    return {
      'poeticName': picked.name,
      'hex': picked.hex,
      'narrativeMeaning': picked.meaning ?? '',
    };
  }

  Future<Map<String, dynamic>?> _editRefDialog(
    BuildContext context,
    Map<String, dynamic> initial,
  ) async {
    final film = TextEditingController(text: initial['film']?.toString() ?? '');
    final dp = TextEditingController(text: initial['dp']?.toString() ?? '');
    final dir =
        TextEditingController(text: initial['director']?.toString() ?? '');
    final tone = TextEditingController(text: initial['tone']?.toString() ?? '');
    final intent =
        TextEditingController(text: initial['intent']?.toString() ?? '');
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Referencia'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: film,
                decoration: const InputDecoration(labelText: 'Película'),
              ),
              TextField(
                controller: dp,
                decoration: const InputDecoration(labelText: 'DP'),
              ),
              TextField(
                controller: dir,
                decoration: const InputDecoration(labelText: 'Director'),
              ),
              TextField(
                controller: tone,
                decoration: const InputDecoration(labelText: 'Tono'),
              ),
              TextField(
                controller: intent,
                decoration: const InputDecoration(labelText: 'Intención'),
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
              'film': film.text.trim(),
              'dp': dp.text.trim(),
              'director': dir.text.trim(),
              'tone': tone.text.trim(),
              'intent': intent.text.trim(),
            }),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

class _ConceptIntro extends StatelessWidget {
  final VisualBibleData data;
  final BibleChanged onChanged;
  final String sceneTag;
  final ValueChanged<String> onSceneTagEdit;

  const _ConceptIntro({
    required this.data,
    required this.onChanged,
    required this.sceneTag,
    required this.onSceneTagEdit,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text(
              'Concepto de Imagen',
              style: AppTypography.displayMedium(palette).copyWith(
                fontSize: 40,
                letterSpacing: -0.8,
              ),
            ),
            Material(
              color: palette.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                onTap: () async {
                  final c = TextEditingController(text: sceneTag);
                  final v = await showDialog<String>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Escena / contexto'),
                      content: TextField(
                        controller: c,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'SCENE 4A — THE DUNE',
                        ),
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
                  if (v != null) onSceneTagEdit(v);
                },
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text(
                    sceneTag.isEmpty ? '+ ESCENA' : sceneTag.toUpperCase(),
                    style: AppTypography.mono(palette).copyWith(
                      fontSize: 12,
                      color: palette.accent,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        BibleTextField(
          label: '',
          hint:
              'El ADN visual del proyecto. Naturalismo estilizado, contrastes…',
          maxLines: 3,
          initialValue: data.conceptNarrativeIntent ?? data.visualConcept ?? '',
          onChanged: (v) {
            data.conceptNarrativeIntent = v;
            data.visualConcept = v;
            onChanged(data);
          },
        ),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _GlassCard({
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
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.05),
            blurRadius: 0,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CardHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final AppPalette palette;

  const _CardHeader({
    required this.icon,
    required this.title,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: palette.accent, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTypography.titleMedium(palette).copyWith(fontSize: 18),
        ),
      ],
    );
  }
}

class _TechScrubRow extends StatelessWidget {
  final String label;
  final String value;
  final AppPalette palette;
  final ValueChanged<String> onEdit;
  final bool accent;
  final bool warn;

  const _TechScrubRow({
    required this.label,
    required this.value,
    required this.palette,
    required this.onEdit,
    this.accent = false,
    this.warn = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = warn
        ? const Color(0xFFFFB4AB)
        : accent
            ? palette.accent
            : palette.textPrimary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          final c = TextEditingController(text: value);
          final v = await showDialog<String>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(label),
              content: TextField(controller: c, autofocus: true),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, c.text.trim()),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          if (v != null && v.isNotEmpty) onEdit(v);
        },
        child: Container(
          padding: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          child: Row(
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
                  color: color,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextureBars extends StatelessWidget {
  final int level;
  final AppPalette palette;
  final ValueChanged<int> onChanged;

  const _TextureBars({
    required this.level,
    required this.palette,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 4; i++)
          Padding(
            padding: EdgeInsets.only(left: i == 1 ? 0 : 4),
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: Container(
                width: 28,
                height: 8,
                decoration: BoxDecoration(
                  color: i <= level
                      ? palette.accent
                      : palette.surfaceElevated,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CinematicRefsGrid extends ConsumerWidget {
  final int projectId;
  final AppPalette palette;
  final String keyFrameTitle;
  final String keyFrameTech;
  final VoidCallback onEditKeyFrame;

  const _CinematicRefsGrid({
    required this.projectId,
    required this.palette,
    required this.keyFrameTitle,
    required this.keyFrameTech,
    required this.onEditKeyFrame,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    return StreamBuilder<List<MoodboardImage>>(
      stream: db.watchMoodboardImagesForSection(
        projectId,
        BibleSectionId.concept,
      ),
      builder: (context, snap) {
        final images = snap.data ?? [];
        if (images.isEmpty) {
          return Text(
            'Sin referencias aún. Añade frames o asigna en Moodboard.',
            style: AppTypography.caption(palette).copyWith(
              color: palette.textTertiary,
            ),
          );
        }

        final thumbs = images.take(3).toList();
        final hero = images.length > 3 ? images[3] : images.first;

        return Column(
          children: [
            LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth.isFinite
                    ? c.maxWidth
                    : MediaQuery.sizeOf(context).width;
                final cols = w >= 520 ? 3 : 2;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: thumbs.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 16 / 9,
                  ),
                  itemBuilder: (context, i) {
                    final model = MoodboardImageModel.fromRow(thumbs[i]);
                    final file = File(model.imagePath);
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          file.existsSync()
                              ? Image.file(file, fit: BoxFit.cover)
                              : ColoredBox(color: palette.surfaceOverlay),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Color(0xCC131315),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                              child: Text(
                                (model.filmReference ??
                                        model.caption ??
                                        'REF')
                                    .toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.label(palette).copyWith(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 12),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onEditKeyFrame,
                borderRadius: BorderRadius.circular(6),
                child: BibleMoodboardImageTarget(
                  projectId: projectId,
                  sectionId: BibleSectionId.concept,
                  hint: 'Clic aquí → ⌘V para pegar key frame',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: AspectRatio(
                      aspectRatio: 21 / 9,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Builder(
                          builder: (_) {
                            final model = MoodboardImageModel.fromRow(hero);
                            final file = File(model.imagePath);
                            return file.existsSync()
                                ? Image.file(file, fit: BoxFit.cover)
                                : ColoredBox(
                                    color: palette.surfaceOverlay,
                                    child: Center(
                                      child: TextButton.icon(
                                        onPressed: () =>
                                            MoodboardHelpers.addManualImages(
                                          db: db,
                                          projectId: projectId,
                                          category: MoodboardCategory.framing,
                                          assignedSections: [
                                            BibleSectionId.concept,
                                          ],
                                        ),
                                        icon: Icon(
                                          Icons.add_photo_alternate_outlined,
                                          color: palette.accent,
                                        ),
                                        label: Text(
                                          'Añadir key frame',
                                          style:
                                              TextStyle(color: palette.accent),
                                        ),
                                      ),
                                    ),
                                  );
                          },
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Color(0xE6131315),
                                Color(0x33131315),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 20,
                          right: 20,
                          bottom: 16,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                keyFrameTitle,
                                style: AppTypography.titleMedium(palette)
                                    .copyWith(
                                  color: Colors.white,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                keyFrameTech,
                                style: AppTypography.mono(palette).copyWith(
                                  fontSize: 12,
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
              ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CompositionActRow extends StatelessWidget {
  final String actLabel;
  final String value;
  final AppPalette palette;
  final ValueChanged<String> onEdit;

  const _CompositionActRow({
    required this.actLabel,
    required this.value,
    required this.palette,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final c = TextEditingController(text: value);
        final v = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(actLabel),
            content: TextField(controller: c, autofocus: true),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, c.text.trim()),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        if (v != null && v.isNotEmpty) onEdit(v);
      },
      child: Row(
        children: [
          Text(
            actLabel,
            style: AppTypography.mono(palette).copyWith(
              color: palette.textPrimary,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTypography.mono(palette).copyWith(
                color: palette.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SymbolCard extends StatelessWidget {
  final String hex;
  final String name;
  final String meaning;
  final AppPalette palette;
  final Color? Function(String?) parseHex;
  final VoidCallback onEdit;

  const _SymbolCard({
    required this.hex,
    required this.name,
    required this.meaning,
    required this.palette,
    required this.parseHex,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final c = parseHex(hex) ?? palette.accent;
    return Material(
      color: palette.surfaceOverlay.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(color: c, width: 4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.toUpperCase(),
                style: AppTypography.label(palette).copyWith(
                  fontSize: 10,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                meaning.isEmpty ? 'Toca para editar…' : meaning,
                style: AppTypography.bodyMedium(palette).copyWith(
                  fontSize: 12,
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final AppPalette palette;
  final ValueChanged<String> onEdit;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.palette,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.surfaceOverlay.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () async {
          final c = TextEditingController(text: value);
          final v = await showDialog<String>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(label),
              content: TextField(controller: c, autofocus: true),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, c.text.trim()),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          if (v != null && v.isNotEmpty) onEdit(v);
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: AppTypography.mono(palette).copyWith(
                  fontSize: 11,
                  color: palette.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                value.toUpperCase(),
                style: AppTypography.label(palette).copyWith(
                  color: palette.accent,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActTimelineItem extends StatelessWidget {
  final String roman;
  final String title;
  final String body;
  final bool showLine;
  final AppPalette palette;
  final Future<void> Function(String title, String body) onEdit;

  const _ActTimelineItem({
    required this.roman,
    required this.title,
    required this.body,
    required this.showLine,
    required this.palette,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.accent.withValues(alpha: 0.2),
                ),
                child: Text(
                  roman,
                  style: AppTypography.label(palette).copyWith(
                    color: palette.accent,
                    fontSize: 11,
                  ),
                ),
              ),
              if (showLine)
                Expanded(
                  child: Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: showLine ? 20 : 0),
              child: InkWell(
                onTap: () async {
                  final t = TextEditingController(text: title);
                  final b = TextEditingController(text: body);
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('Acto $roman'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: t,
                            decoration:
                                const InputDecoration(labelText: 'Título'),
                          ),
                          TextField(
                            controller: b,
                            maxLines: 4,
                            decoration:
                                const InputDecoration(labelText: 'Intención'),
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
                  if (ok == true) {
                    await onEdit(t.text.trim(), b.text.trim());
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ACTO $roman: ${title.toUpperCase()}',
                      style: AppTypography.label(palette).copyWith(
                        color: palette.textPrimary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      body.isEmpty ? 'Toca para definir la intención…' : body,
                      style: AppTypography.bodyMedium(palette).copyWith(
                        fontSize: 13,
                        color: palette.textSecondary,
                        height: 1.4,
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
}

class _ReferenceMetaCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final AppPalette palette;
  final VoidCallback onEdit;

  const _ReferenceMetaCard({
    required this.data,
    required this.palette,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xB31A1A1C),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data['film']?.toString().isNotEmpty == true
                    ? data['film'].toString()
                    : 'Referencia',
                style: AppTypography.titleMedium(palette),
              ),
              const SizedBox(height: 4),
              Text(
                'Dir. Fotografía: ${data['dp'] ?? '—'}'
                '${data['director'] != null && data['director'].toString().isNotEmpty ? ' · Dir: ${data['director']}' : ''}',
                style: AppTypography.mono(palette).copyWith(
                  fontSize: 11,
                  color: palette.textTertiary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _mini('Tono', data['tone']?.toString() ?? '—'),
                  ),
                  Expanded(
                    child:
                        _mini('Intención', data['intent']?.toString() ?? '—'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mini(String label, String value) {
    return Column(
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
          style: AppTypography.mono(palette).copyWith(
            fontSize: 11,
            color: palette.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// Módulos Stitch descompuestos para el panel Widgets ↔ pantalla.
class _ConceptStitchModule extends ConsumerWidget {
  final String slot;
  final VisualBibleData data;
  final int projectId;
  final AppPalette palette;
  final AppDatabase db;
  final String? sectionContentJson;
  final String? formatSectionContentJson;
  final BibleChanged onChanged;
  final Color? Function(String?) parseHex;
  final Future<void> Function(WidgetRef ref, Map<String, dynamic> update)
      updateCustomData;

  const _ConceptStitchModule({
    required this.slot,
    required this.data,
    required this.projectId,
    required this.palette,
    required this.db,
    required this.onChanged,
    required this.sectionContentJson,
    this.formatSectionContentJson,
    required this.parseHex,
    required this.updateCustomData,
  });

  Map<String, dynamic> _custom() {
    if (sectionContentJson == null) return {};
    try {
      final decoded = jsonDecode(sectionContentJson!);
      if (decoded is Map<String, dynamic> && decoded.containsKey('_values')) {
        final vals = decoded['_values'] as Map<String, dynamic>;
        if (vals.containsKey('conceptData')) {
          return jsonDecode(vals['conceptData'] as String)
              as Map<String, dynamic>;
        }
      }
    } catch (_) {}
    return {};
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final custom = _custom();
    final colorSymbols = (custom['colorSymbols'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final actTitles = (custom['actTitles'] as Map?)?.cast<String, String>() ??
        {'1': 'El Orden Frágil', '2': 'El Descenso', '3': 'La Resolución'};
    final actComp =
        (custom['actComposition'] as Map?)?.cast<String, String>() ??
            {
              '1': 'Symmetrical, Locked Off, Wide',
              '2': 'Handheld, Asymmetrical, Medium',
              '3': 'Chaotic, Extreme Close-ups, Dutch',
            };
    final metrics =
        (custom['lightingMetrics'] as Map?)?.cast<String, String>() ??
            {
              'contrast': data.contrastStyle ?? 'ALTO (4:1)',
              'motivation': 'PRÁCTICOS VISIBLES',
            };
    final shadowTreatment = custom['shadowTreatment'] as String? ?? '';
    final keyFrameTitle =
        custom['keyFrameTitle'] as String? ?? 'Key Frame Analysis';
    final formatBlob = FormatPilotResolve.parseBlob(formatSectionContentJson);
    final aspectLabel =
        FormatPilotResolve.activeRatio(formatBlob, data) ?? '2.39:1';
    final keyFrameTech = custom['keyFrameTech'] as String? ??
        'Aspect Ratio: $aspectLabel / Focal: 21mm / T2.8';
    final act1 = custom['act1Intent'] as String? ?? '';
    final act2 = custom['act2Intent'] as String? ?? '';
    final act3 = custom['act3Intent'] as String? ?? '';

    return switch (slot) {
      'colorPalette' => _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paleta de Color',
                style: AppTypography.titleMedium(palette).copyWith(fontSize: 20),
              ),
              const SizedBox(height: 20),
              StreamBuilder<List<VisualBibleColorBlock>>(
                stream: db.watchColorBlocksForBible(data.id),
                builder: (context, snap) {
                  final blocks =
                      snap.data?.map(ColorBlockModel.fromRow).toList() ?? [];
                  if (blocks.isEmpty) {
                    return Text(
                      'Define colores en Color e imagen.',
                      style: AppTypography.bodyMedium(palette),
                    );
                  }
                  return Wrap(
                    spacing: 10,
                    runSpacing: 14,
                    children: [
                      for (final b in blocks)
                        for (final c in b.dominantColors.take(3))
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: parseHex(c) ?? palette.surfaceOverlay,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      'colorSymbolism' => _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardHeader(
                icon: Icons.psychology_outlined,
                title: 'Simbología de Color',
                palette: palette,
              ),
              const SizedBox(height: 16),
              for (final sym in colorSymbols)
                Text(
                  '${sym['poeticName'] ?? 'Color'} · ${sym['narrativeMeaning'] ?? ''}',
                  style: AppTypography.bodyMedium(palette),
                ),
            ],
          ),
        ),
      'lightPhilosophy' => _GlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardHeader(
                icon: Icons.lightbulb_outline,
                title: 'Filosofía de Luz',
                palette: palette,
              ),
              const SizedBox(height: 12),
              BibleTextField(
                label: '',
                hint: 'Noir moderno, far-side key…',
                maxLines: 4,
                initialValue: data.lightingPhilosophy ?? '',
                onChanged: (v) {
                  data.lightingPhilosophy = v;
                  onChanged(data);
                },
              ),
              const SizedBox(height: 12),
              Text(
                'Contraste: ${metrics['contrast'] ?? '—'}',
                style: AppTypography.caption(palette),
              ),
            ],
          ),
        ),
      'keyFrame' => _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(keyFrameTitle,
                  style:
                      AppTypography.titleMedium(palette).copyWith(fontSize: 20)),
              const SizedBox(height: 8),
              Text(keyFrameTech, style: AppTypography.mono(palette)),
              const SizedBox(height: 12),
              MoodboardStrip.forSection(
                projectId: projectId,
                sectionId: BibleSectionId.concept,
                showTitle: false,
                showCaptions: true,
              ),
            ],
          ),
        ),
      'shadowTreatment' => _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tratamiento de Sombras',
                style: AppTypography.titleMedium(palette).copyWith(fontSize: 20),
              ),
              const SizedBox(height: 12),
              BibleTextField(
                label: '',
                maxLines: 5,
                initialValue: shadowTreatment,
                onChanged: (v) =>
                    updateCustomData(ref, {'shadowTreatment': v}),
              ),
            ],
          ),
        ),
      'actComposition' => _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Composición por Actos',
                style: AppTypography.titleMedium(palette).copyWith(fontSize: 20),
              ),
              const SizedBox(height: 14),
              for (final n in ['1', '2', '3'])
                _CompositionActRow(
                  actLabel: 'Act ${['I', 'II', 'III'][int.parse(n) - 1]}:',
                  value: actComp[n] ?? '—',
                  palette: palette,
                  onEdit: (v) => updateCustomData(ref, {
                    'actComposition': {...actComp, n: v},
                  }),
                ),
            ],
          ),
        ),
      'actNotes' => _GlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardHeader(
                icon: Icons.timeline,
                title: 'Intención Visual por Acto',
                palette: palette,
              ),
              const SizedBox(height: 20),
              _ActTimelineItem(
                roman: 'I',
                title: actTitles['1'] ?? 'Acto I',
                body: act1,
                showLine: true,
                palette: palette,
                onEdit: (title, body) async {
                  await updateCustomData(ref, {
                    'act1Intent': body,
                    'actTitles': {...actTitles, '1': title},
                  });
                },
              ),
              _ActTimelineItem(
                roman: 'II',
                title: actTitles['2'] ?? 'Acto II',
                body: act2,
                showLine: true,
                palette: palette,
                onEdit: (title, body) async {
                  await updateCustomData(ref, {
                    'act2Intent': body,
                    'actTitles': {...actTitles, '2': title},
                  });
                },
              ),
              _ActTimelineItem(
                roman: 'III',
                title: actTitles['3'] ?? 'Acto III',
                body: act3,
                showLine: false,
                palette: palette,
                onEdit: (title, body) async {
                  await updateCustomData(ref, {
                    'act3Intent': body,
                    'actTitles': {...actTitles, '3': title},
                  });
                },
              ),
            ],
          ),
        ),
      _ => const SizedBox.shrink(),
    };
  }
}
