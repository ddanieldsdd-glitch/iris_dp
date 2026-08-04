import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../bible_section_fields.dart';
import '../../visual_bible_model.dart';
import '../../../equipment/widgets/equipment_picker.dart';
import '../bible_form_widgets.dart';
import 'section_scaffold.dart';

class OpticsSection extends ConsumerWidget {
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

  static const _opticTypes = ['Esférica', 'Anamórfica', 'Vintage', 'Moderna'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);

    final settingsLabel = BibleSectionFieldsConfig.labelFor(
      sectionContentJson,
      BibleSectionId.optics,
      'opticSettings',
      'Filosofía y kit de lentes',
    );

    return BibleSectionScaffold(
      sectionId: BibleSectionId.optics,
      projectId: projectId,
      data: data,
      onChanged: onChanged,
      sectionContentJson: sectionContentJson,
      narrativeHint:
          '¿Por qué esta lente y este T-stop? Qué queremos contar '
          'con este carácter óptico…',
      fieldWidgets: {
        'opticSettings': AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                settingsLabel,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: AppSpacing.md),
              BibleTextField(
                label: 'Filosofía de óptica',
                hint: 'Cómo el carácter de la lente sirve a la historia…',
                maxLines: 4,
                initialValue: data.lensPhilosophy,
                onChanged: (v) {
                  data.lensPhilosophy = v.trim().isEmpty ? null : v.trim();
                  onChanged(data);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: BibleDropdown(
                      label: 'Tipo de óptica',
                      options: _opticTypes,
                      value: data.opticType,
                      onChanged: (v) {
                        data.opticType = v;
                        onChanged(data);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: BibleTextField(
                      label: 'T-stop de trabajo',
                      hint: 'T2.8',
                      initialValue: data.defaultTStop,
                      onChanged: (v) {
                        data.defaultTStop = v.trim().isEmpty ? null : v.trim();
                        onChanged(data);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              BibleTextField(
                label: 'Focales preferentes (mm)',
                hint: '35, 50, 85',
                initialValue: data.primaryFocalLengths.join(', '),
                onChanged: (v) {
                  data.primaryFocalLengths = v
                      .split(',')
                      .map((s) => int.tryParse(s.trim()) ?? 0)
                      .where((n) => n > 0)
                      .toList();
                  onChanged(data);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              StreamBuilder<List<Lense>>(
                stream: db.watchAllLenses(),
                builder: (context, snap) {
                  final lenses = snap.data ?? [];
                  if (lenses.isEmpty) return const SizedBox.shrink();
                  return EquipmentPicker(
                    projectId: projectId,
                    equipmentType: 'lens',
                    label: 'Óptica principal',
                    selectedId: data.primaryLensId,
                    onSelected: (id) {
                      data.primaryLensId = id;
                      onChanged(data);
                    },
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
              BibleTextField(
                label: 'Profundidad de campo',
                hint: 'Selectiva en primeros planos, profunda en exteriores, '
                    'T2 para separar sujetos del fondo…',
                maxLines: 4,
                initialValue: data.depthOfFieldNotes,
                onChanged: (v) {
                  data.depthOfFieldNotes = v.trim().isEmpty ? null : v.trim();
                  onChanged(data);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              BibleTextField(
                label: 'Carácter óptico (flare, breathing, bokeh…)',
                hint: 'Flare suave en contraluz, bokeh redondo…',
                maxLines: 3,
                initialValue: data.opticCharacterNotes,
                onChanged: (v) {
                  data.opticCharacterNotes =
                      v.trim().isEmpty ? null : v.trim();
                  onChanged(data);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              BibleTextField(
                label: 'Filtración (Pro-Mist, polarizador, IR-ND…)',
                hint: '1/4 Pro-Mist en interiores emotivos…',
                maxLines: 3,
                initialValue: data.filtrationNotes,
                onChanged: (v) {
                  data.filtrationNotes = v.trim().isEmpty ? null : v.trim();
                  onChanged(data);
                },
              ),
            ],
          ),
        ),
      },
    );
  }
}
