// /Users/danieldiaz/Documents/IRIS DP/iris_dp/lib/features/visual_bible/widgets/sections/lighting_section.dart
import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../bible_section_fields.dart';
import '../../visual_bible_model.dart';
import '../bible_form_widgets.dart';
import '../bible_section_shared_widgets.dart';
import '../lighting_diagram/lighting_diagram_editor.dart';
import 'section_scaffold.dart';

class LightingSection extends ConsumerStatefulWidget {
  final VisualBibleData data;
  final int projectId;
  final int bibleId;
  final String? sectionContentJson;
  final BibleChanged onChanged;

  const LightingSection({
    super.key,
    required this.data,
    required this.projectId,
    required this.bibleId,
    this.sectionContentJson,
    required this.onChanged,
  });

  @override
  ConsumerState<LightingSection> createState() => _LightingSectionState();
}

class _LightingSectionState extends ConsumerState<LightingSection> {
  Map<String, dynamic> _getCustomData() {
    if (widget.sectionContentJson == null) return {};
    try {
      final decoded = jsonDecode(widget.sectionContentJson!);
      if (decoded is Map<String, dynamic> && decoded.containsKey('_values')) {
        final vals = decoded['_values'] as Map<String, dynamic>;
        if (vals.containsKey('lightingData')) {
          return jsonDecode(vals['lightingData'] as String) as Map<String, dynamic>;
        }
      }
    } catch (_) {}
    return {};
  }

  Future<void> _updateCustomData(Map<String, dynamic> update) async {
    final current = _getCustomData();
    final newData = {...current, ...update};
    final db = ref.read(databaseProvider);
    final def = await (db.select(db.bibleSectionDefinitions)
          ..where(
            (d) =>
                d.bibleId.equals(widget.data.id) &
                d.id.equals(BibleSectionId.lighting),
          ))
        .getSingleOrNull();
    if (def != null) {
      final fields =
          BibleSectionFieldsConfig.parse(def.contentJson, BibleSectionId.lighting);
      final values = BibleSectionFieldsConfig.parseValues(def.contentJson);
      values['lightingData'] = jsonEncode(newData);
      await db.upsertBibleSectionDefinition(
        def.copyWith(
          contentJson: drift.Value(
            BibleSectionFieldsConfig.encode(fields, values: values),
          ),
        ),
      );
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);
    final data = widget.data;
    final parsedJson = _getCustomData();

    final List<dynamic> equipmentManifest = parsedJson['equipmentManifest'] ?? [];
    final String gafferDirectives = parsedJson['gafferDirectives'] ?? 'Ensure soft wrap on key.';
    final int globalColorTemp = parsedJson['globalColorTemp'] ?? 5600;
    final String globalTint = parsedJson['globalTint'] ?? 'neutral';
    final String contrastRatio = parsedJson['contrastRatio'] ?? '8:1';
    final String lightOriginPrimary = parsedJson['lightOriginPrimary'] ?? '';
    final String lightOriginSecondary = parsedJson['lightOriginSecondary'] ?? '';
    final String lightOriginAccents = parsedJson['lightOriginAccents'] ?? '';

    return BibleSectionScaffold(
      sectionId: BibleSectionId.lighting,
      projectId: widget.projectId,
      data: data,
      onChanged: widget.onChanged,
      sectionContentJson: widget.sectionContentJson,
      narrativeHint: '¿Por qué iluminamos así? Qué emoción transmite esta filosofía de luz y sus ratios…',
      sectionNumber: '05',
      sectionTitle: 'Iluminación',
      fieldWidgets: {
        'philosophy': Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: BibleTechCard(label: 'COLOR TEMP', value: '${globalColorTemp}K')),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: BibleTechCard(label: 'CONTRAST RATIO', value: contrastRatio)),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: BibleTechCard(label: 'FUENTE', value: data.lightSource ?? 'Natural')),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: BibleTechCard(label: 'CALIDAD', value: data.lightQuality ?? '', mono: false)),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: BibleTechCard(label: 'ESTILO', value: data.contrastStyle ?? '', mono: false)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  BibleTextField(
                    label: 'Filosofía de iluminación',
                    hint: '...',
                    maxLines: 3,
                    initialValue: data.lightingPhilosophy,
                    onChanged: (v) {
                      data.lightingPhilosophy = v;
                      widget.onChanged(data);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BibleHeroValue(value: '${globalColorTemp}K', unit: '', label: 'TEMPERATURA GLOBAL'),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Text('Tint: $globalTint'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('LIGHT ORIGIN & MOTIVATION', style: AppTypography.titleMedium(palette)),
                  const SizedBox(height: AppSpacing.md),
                  BibleTextField(
                    label: 'Primary',
                    initialValue: lightOriginPrimary,
                    onChanged: (v) => _updateCustomData({'lightOriginPrimary': v}),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  BibleTextField(
                    label: 'Secondary',
                    initialValue: lightOriginSecondary,
                    onChanged: (v) => _updateCustomData({'lightOriginSecondary': v}),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  BibleTextField(
                    label: 'Stylized Accents',
                    initialValue: lightOriginAccents,
                    onChanged: (v) => _updateCustomData({'lightOriginAccents': v}),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('EQUIPMENT MANIFEST', style: AppTypography.titleMedium(palette)),
                  const SizedBox(height: AppSpacing.md),
                  Table(
                    children: [
                      TableRow(
                        children: [
                          Text('Fixture', style: AppTypography.label(palette)),
                          Text('Rol', style: AppTypography.label(palette)),
                          Text('Int/Mod', style: AppTypography.label(palette)),
                          Text('Status', style: AppTypography.label(palette)),
                        ],
                      ),
                      ...equipmentManifest.map((item) {
                        final m = item as Map<String, dynamic>;
                        return TableRow(
                          children: [
                            Text(m['fixture'] ?? ''),
                            Text(m['role'] ?? ''),
                            Text('${m['intensity']} / ${m['modifier']}'),
                            Container(
                              width: 10, height: 10,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: palette.success),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                  TextButton(onPressed: (){}, child: Text('Añadir fixture', style: TextStyle(color: palette.accent))),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            BibleGafferDirectiveBox(text: gafferDirectives, title: 'GAFFER DIRECTIVES'),
            const SizedBox(height: AppSpacing.sm),
            BibleTextField(
              label: 'Editar Directivas',
              initialValue: gafferDirectives,
              onChanged: (v) => _updateCustomData({'gafferDirectives': v}),
            ),
          ],
        ),
        'diagrams': Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Setups de iluminación', style: AppTypography.titleMedium(palette)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _addSetup(context),
                  icon: Icon(Icons.add, color: palette.accent, size: 18),
                  label: Text('Nuevo setup', style: AppTypography.label(palette).copyWith(color: palette.accent)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            StreamBuilder<List<LightingSetup>>(
              stream: db.watchLightingSetupsForBible(widget.bibleId),
              builder: (context, snap) {
                final setups = snap.data ?? [];
                return Column(
                  children: setups.map((row) {
                    final setup = LightingSetupModel.fromRow(row);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                      child: AppCard(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(setup.setupName, style: AppTypography.titleMedium(palette)),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete_outline, color: palette.error, size: 20),
                                  onPressed: () => db.deleteLightingSetup(setup.id),
                                ),
                              ],
                            ),
                            if (setup.narrativeNote?.isNotEmpty == true) Text(setup.narrativeNote!),
                            if (setup.practicalMotivation?.isNotEmpty == true) Text('Práctica: ${setup.practicalMotivation}'),
                            const SizedBox(height: AppSpacing.sm),
                            SizedBox(
                              height: 280,
                              child: LightingDiagramEditor(
                                initialJson: setup.diagramJson,
                                onChanged: (json) async {
                                  await db.updateLightingSetup(row.copyWith(diagramJson: json));
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        )
      },
    );
  }

  Future<void> _addSetup(BuildContext context) async {
    final palette = context.palette;
    final nameCtrl = TextEditingController();
    final narrativeCtrl = TextEditingController();
    final practicalCtrl = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.surfaceElevated,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.lg,
            bottom: MediaQuery.paddingOf(ctx).bottom + AppSpacing.lg,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Nuevo setup de luz', style: AppTypography.titleMedium(palette)),
                const SizedBox(height: AppSpacing.md),
                BibleTextField(label: 'Nombre', hint: 'Entrevista ventana', onChanged: (_) {}, controller: nameCtrl),
                BibleTextField(label: 'Intención narrativa', hint: 'Qué emoción transmite este setup…', maxLines: 2, onChanged: (_) {}, controller: narrativeCtrl),
                BibleTextField(label: 'Motivación práctica', hint: 'Ventana lateral como key…', maxLines: 2, onChanged: (_) {}, controller: practicalCtrl),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    await ref.read(databaseProvider).insertLightingSetup(
                      LightingSetupsCompanion.insert(
                        bibleId: widget.bibleId,
                        setupName: name,
                        narrativeNote: drift.Value(narrativeCtrl.text.trim().isEmpty ? null : narrativeCtrl.text.trim()),
                        practicalMotivation: drift.Value(practicalCtrl.text.trim().isEmpty ? null : practicalCtrl.text.trim()),
                        diagramJson: '[]',
                      ),
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Crear setup'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
