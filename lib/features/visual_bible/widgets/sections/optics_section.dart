// /Users/danieldiaz/Documents/IRIS DP/iris_dp/lib/features/visual_bible/widgets/sections/optics_section.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../visual_bible_model.dart';
import '../../../equipment/widgets/equipment_picker.dart';
import '../bible_form_widgets.dart';
import '../bible_section_shared_widgets.dart';
import 'section_scaffold.dart';

class OpticsSection extends ConsumerStatefulWidget {
  final VisualBibleData data;
  final int projectId;
  final String? sectionContentJson;
  final BibleChanged onChanged;

  const OpticsSection({
    super.key,
    required this.data,
    required this.projectId,
    this.sectionContentJson,
    required this.onChanged,
  });

  @override
  ConsumerState<OpticsSection> createState() => _OpticsSectionState();
}

class _OpticsSectionState extends ConsumerState<OpticsSection> {
  Map<String, dynamic> _getParsedJson() {
    final jsonStr = widget.data.opticsConfigJson ?? widget.sectionContentJson ?? '{}';
    try {
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  void _updateJson(Map<String, dynamic> newData) {
    final current = _getParsedJson();
    current.addAll(newData);
    widget.data.opticsConfigJson = jsonEncode(current);
    widget.onChanged(widget.data);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);
    final data = widget.data;
    final parsedJson = _getParsedJson();

    final List<dynamic> filtrationStack = parsedJson['filtrationStack'] ?? [];
    final List<dynamic> maintenanceLog = parsedJson['maintenanceLog'] ?? [];
    final List<dynamic> anamorphicSpecs = parsedJson['anamorphicSpecs'] ?? [];

    return BibleSectionScaffold(
      sectionId: BibleSectionId.optics,
      projectId: widget.projectId,
      data: data,
      onChanged: widget.onChanged,
      sectionContentJson: widget.sectionContentJson,
      narrativeHint: '¿Por qué esta lente y este T-stop? Qué queremos contar con este carácter óptico…',
      sectionNumber: '03',
      sectionTitle: 'Óptica',
      fieldWidgets: {
        'opticSettings': Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: palette.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'PRIMARY SET',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: palette.accent,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  StreamBuilder<List<Lense>>(
                    stream: db.watchAllLenses(),
                    builder: (context, snap) {
                      final lenses = snap.data ?? [];
                      if (lenses.isEmpty) return const SizedBox.shrink();
                      return EquipmentPicker(
                        projectId: widget.projectId,
                        equipmentType: 'lens',
                        label: 'Lente principal',
                        selectedId: data.primaryLensId,
                        onSelected: (id) {
                          data.primaryLensId = id;
                          widget.onChanged(data);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  BibleChipRow(
                    chips: [
                      data.opticType ?? 'Anamórfico',
                      'T1.4',
                      '2x Squeeze'
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  BibleTextField(
                    label: 'Filosofía óptica',
                    hint: 'Cómo el carácter de la lente sirve a la historia...',
                    initialValue: data.lensPhilosophy,
                    onChanged: (v) {
                      data.lensPhilosophy = v;
                      widget.onChanged(data);
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Row(
                    children: [
                      Expanded(
                        child: BibleTechCard(
                          label: 'BOKEH CHARACTERISTIC',
                          value: 'Ovalado / Suave',
                        ),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: BibleTechCard(
                          label: 'FLARE BEHAVIOR',
                          value: 'Azul anamórfico, controlado',
                        ),
                      ),
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
                  Text('FOCALES PRINCIPALES', style: AppTypography.titleMedium(palette)),
                  const SizedBox(height: AppSpacing.md),
                  BibleChipRow(
                    chips: data.primaryFocalLengths.map((f) => '${f}mm').toList(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  BibleTextField(
                    label: 'Añadir focal (mm)',
                    hint: 'Ej. 35',
                    onChanged: (v) {
                      final val = int.tryParse(v.trim());
                      if (val != null && !data.primaryFocalLengths.contains(val)) {
                        data.primaryFocalLengths = [...data.primaryFocalLengths, val];
                        widget.onChanged(data);
                      }
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
                  Text('FILTRATION STACK', style: AppTypography.titleMedium(palette)),
                  const SizedBox(height: AppSpacing.md),
                  ...filtrationStack.asMap().entries.map((e) {
                    final i = e.key;
                    final map = e.value as Map<String, dynamic>;
                    return Row(
                      children: [
                        Expanded(child: Text('${map['name']} - ${map['density']}\n${map['justification']}')),
                        IconButton(
                          icon: Icon(Icons.delete, color: palette.error),
                          onPressed: () {
                            final list = List.from(filtrationStack)..removeAt(i);
                            _updateJson({'filtrationStack': list});
                          },
                        ),
                      ],
                    );
                  }),
                  TextButton(
                    onPressed: () {
                      final list = List.from(filtrationStack);
                      list.add({'name': 'Nuevo filtro', 'density': '1/4', 'justification': '...'});
                      _updateJson({'filtrationStack': list});
                    },
                    child: Text('Añadir filtro', style: TextStyle(color: palette.accent)),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  BibleTextField(
                    label: 'Notas de filtración',
                    hint: 'Detalles adicionales...',
                    initialValue: data.filtrationNotes,
                    onChanged: (v) {
                      data.filtrationNotes = v;
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
                  Text('ANAMORPHIC SPECIFICS', style: AppTypography.titleMedium(palette)),
                  const SizedBox(height: AppSpacing.md),
                  Table(
                    children: [
                      TableRow(
                        children: [
                          Text('Focal Length', style: AppTypography.label(palette)),
                          Text('T-Stop', style: AppTypography.label(palette)),
                          Text('CFD', style: AppTypography.label(palette)),
                          Text('Distorsión', style: AppTypography.label(palette)),
                        ],
                      ),
                      ...(anamorphicSpecs.isEmpty ? [{}, {}, {}] : anamorphicSpecs).map((spec) {
                        final map = spec as Map<dynamic, dynamic>? ?? {};
                        return TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: SizedBox(
                                width: 100,
                                child: BibleTextField(initialValue: map['focalLength']?.toString() ?? '', onChanged: (v){}),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: SizedBox(
                                width: 80,
                                child: BibleTextField(initialValue: map['tStop']?.toString() ?? '', onChanged: (v){}),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: SizedBox(
                                width: 80,
                                child: BibleTextField(initialValue: map['cfd']?.toString() ?? '', onChanged: (v){}),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: SizedBox(
                                width: 100,
                                child: BibleTextField(initialValue: map['distortion']?.toString() ?? '', onChanged: (v){}),
                              ),
                            ),
                          ],
                        );
                      }),
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
                  Text('MAINTENANCE LOG', style: AppTypography.titleMedium(palette)),
                  const SizedBox(height: AppSpacing.md),
                  ...maintenanceLog.asMap().entries.map((e) {
                    final map = e.value as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Text('${map['date']}'),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(child: Text('${map['description']}')),
                          const SizedBox(width: AppSpacing.md),
                          // Placeholder status dot
                          Container(
                            width: 10, height: 10,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: map['status'] == 'ok' ? palette.success : palette.warning),
                          ),
                        ],
                      ),
                    );
                  }),
                  TextButton(
                    onPressed: () {
                      final list = List.from(maintenanceLog);
                      list.add({'date': 'Hoy', 'description': 'Revisión', 'status': 'ok'});
                      _updateJson({'maintenanceLog': list});
                    },
                    child: Text('Añadir revisión', style: TextStyle(color: palette.accent)),
                  ),
                ],
              ),
            ),
          ],
        )
      },
    );
  }
}
