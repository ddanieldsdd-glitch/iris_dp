import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../bible_section_fields.dart';
import '../../services/mired_converter.dart';
import '../../visual_bible_model.dart';
import '../bible_form_widgets.dart';
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
  final _sourceKelvinCtrl = TextEditingController(text: '3200');
  final _targetKelvinCtrl = TextEditingController(text: '5600');
  GelRecommendation? _gelRec;

  static const _lightQualities = [
    'Dura',
    'Semidura',
    'Suave',
    'Muy suave',
    'Naturalista',
  ];
  static const _contrastStyles = [
    'Alto contraste (5:1+)',
    'Medio-alto (3:1)',
    'Medio (2:1)',
    'Bajo (1.5:1)',
    'Flat (1:1)',
  ];
  static const _lightSources = [
    'Natural dominante',
    'Prácticas dominantes',
    'Artificial controlada',
    'Mixta',
  ];

  @override
  void dispose() {
    _sourceKelvinCtrl.dispose();
    _targetKelvinCtrl.dispose();
    super.dispose();
  }

  void _calculateGel() {
    final source = int.tryParse(_sourceKelvinCtrl.text.trim());
    final target = int.tryParse(_targetKelvinCtrl.text.trim());
    if (source == null || target == null) return;
    setState(() {
      _gelRec = MiredConverter.recommendGel(
        sourceKelvin: source,
        targetKelvin: target,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);
    final data = widget.data;

    final philosophyLabel = BibleSectionFieldsConfig.labelFor(
      widget.sectionContentJson,
      BibleSectionId.lighting,
      'philosophy',
      'Filosofía de iluminación',
    );
    final miredLabel = BibleSectionFieldsConfig.labelFor(
      widget.sectionContentJson,
      BibleSectionId.lighting,
      'miredConverter',
      'Conversor Mired / Kelvin / Gel',
    );
    final diagramsLabel = BibleSectionFieldsConfig.labelFor(
      widget.sectionContentJson,
      BibleSectionId.lighting,
      'diagrams',
      'Diagramas de iluminación',
    );

    return BibleSectionScaffold(
      sectionId: BibleSectionId.lighting,
      projectId: widget.projectId,
      data: data,
      onChanged: widget.onChanged,
      sectionContentJson: widget.sectionContentJson,
      narrativeHint:
          '¿Por qué iluminamos así? Qué emoción transmite esta '
          'filosofía de luz y sus ratios…',
      fieldWidgets: {
        'philosophy': AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(philosophyLabel, style: AppTypography.titleMedium(palette)),
              const SizedBox(height: AppSpacing.md),
              BibleTextField(
                label: philosophyLabel,
                hint: 'Calidad, dirección y origen de la luz…',
                maxLines: 5,
                initialValue: data.lightingPhilosophy,
                onChanged: (v) {
                  data.lightingPhilosophy = v.trim().isEmpty ? null : v.trim();
                  widget.onChanged(data);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: BibleDropdown(
                      label: 'Calidad',
                      options: _lightQualities,
                      value: data.lightQuality,
                      onChanged: (v) {
                        data.lightQuality = v;
                        widget.onChanged(data);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: BibleDropdown(
                      label: 'Contraste',
                      options: _contrastStyles,
                      value: data.contrastStyle,
                      onChanged: (v) {
                        data.contrastStyle = v;
                        widget.onChanged(data);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              BibleDropdown(
                label: 'Origen de la luz',
                options: _lightSources,
                value: data.lightSource,
                onChanged: (v) {
                  data.lightSource = v;
                  widget.onChanged(data);
                },
              ),
            ],
          ),
        ),
        'miredConverter': AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(miredLabel, style: AppTypography.titleMedium(palette)),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: BibleTextField(
                      label: 'Kelvin fuente',
                      hint: '3200',
                      controller: _sourceKelvinCtrl,
                      onChanged: (_) => _calculateGel(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: BibleTextField(
                      label: 'Kelvin objetivo',
                      hint: '5600',
                      controller: _targetKelvinCtrl,
                      onChanged: (_) => _calculateGel(),
                    ),
                  ),
                ],
              ),
              if (_gelRec != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _gelRec!.description,
                  style: AppTypography.bodyMedium(palette).copyWith(
                    color: palette.accent,
                  ),
                ),
              ],
            ],
          ),
        ),
        'diagrams': Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Row(
          children: [
            Text(diagramsLabel, style: AppTypography.titleMedium(palette)),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _addSetup(context),
              icon: Icon(Icons.add, color: palette.accent, size: 18),
              label: Text('Nuevo setup',
                  style: AppTypography.label(palette)
                      .copyWith(color: palette.accent)),
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
                              child: Text(setup.setupName,
                                  style: AppTypography.titleMedium(palette)),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline,
                                  color: palette.error, size: 20),
                              onPressed: () =>
                                  db.deleteLightingSetup(setup.id),
                            ),
                          ],
                        ),
                        if (setup.narrativeNote?.isNotEmpty == true)
                          Text(setup.narrativeNote!),
                        if (setup.practicalMotivation?.isNotEmpty == true)
                          Text('Práctica: ${setup.practicalMotivation}'),
                        const SizedBox(height: AppSpacing.sm),
                        SizedBox(
                          height: 280,
                          child: LightingDiagramEditor(
                            initialJson: setup.diagramJson,
                            onChanged: (json) async {
                              await db.updateLightingSetup(
                                row.copyWith(diagramJson: json),
                              );
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
        ),
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
                Text('Nuevo setup de luz',
                    style: AppTypography.titleMedium(palette)),
                const SizedBox(height: AppSpacing.md),
                BibleTextField(
                  label: 'Nombre',
                  hint: 'Entrevista ventana',
                  onChanged: (_) {},
                  controller: nameCtrl,
                ),
                BibleTextField(
                  label: 'Intención narrativa',
                  hint: 'Qué emoción transmite este setup…',
                  maxLines: 2,
                  onChanged: (_) {},
                  controller: narrativeCtrl,
                ),
                BibleTextField(
                  label: 'Motivación práctica',
                  hint: 'Ventana lateral como key…',
                  maxLines: 2,
                  onChanged: (_) {},
                  controller: practicalCtrl,
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    await ref.read(databaseProvider).insertLightingSetup(
                          LightingSetupsCompanion.insert(
                            bibleId: widget.bibleId,
                            setupName: name,
                            narrativeNote: Value(
                              narrativeCtrl.text.trim().isEmpty
                                  ? null
                                  : narrativeCtrl.text.trim(),
                            ),
                            practicalMotivation: Value(
                              practicalCtrl.text.trim().isEmpty
                                  ? null
                                  : practicalCtrl.text.trim(),
                            ),
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
