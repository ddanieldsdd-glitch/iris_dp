import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../../../shared/visual_bible/workflow_points.dart';
import '../../bible_section_fields.dart';
import '../../visual_bible_model.dart';
import '../bible_form_widgets.dart';
import '../bible_point_panel.dart';
import '../bible_table_widget.dart';
import 'section_scaffold.dart';

/// Workflow: qué pasa con la imagen desde la cámara hasta la entrega, y
/// quién la cuida.
///
/// Sus puntos se pintan con los widgets del catálogo. Lo que cada uno
/// guarda está en [WorkflowPoints].
class WorkflowSection extends ConsumerWidget {
  final VisualBibleData data;
  final int projectId;
  final String? sectionContentJson;
  final BibleChanged onChanged;

  const WorkflowSection({
    super.key,
    required this.data,
    required this.projectId,
    this.sectionContentJson,
    required this.onChanged,
  });

  static const _sectionId = BibleSectionId.workflow;

  Future<void> _saveValue(WidgetRef ref, String key, String? value) => ref
      .read(databaseProvider)
      .saveBibleSectionFieldValue(data.id, _sectionId, key, value);

  static String? _orNull(String text) =>
      text.trim().isEmpty ? null : text.trim();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final values = BibleSectionFieldsConfig.parseValues(sectionContentJson);
    final labels = {
      for (final field in BibleSectionFieldsConfig.parse(
        sectionContentJson,
        _sectionId,
      ))
        field.key: field.label,
    };
    String label(String key, String fallback) => labels[key] ?? fallback;

    final stepsValue = WorkflowPoints.stepsValue(values);
    final teamValue = WorkflowPoints.teamValue(values);
    final deliveryValue = WorkflowPoints.deliveryValue(
      values,
      deliveryColorSpace: data.deliveryColorSpace,
      resolutionNotes: data.resolutionNotes,
      workflowPipeline: data.workflowPipeline,
    );

    // Workflow no tiene columna propia para la intención: va con sus
    // valores, como cualquier punto de texto.
    final narrative = BiblePointPanel(
      label: label('narrative', 'Intención narrativa'),
      icon: Icons.psychology_outlined,
      child: BibleTextField(
        label: '',
        hint:
            'Qué le pedimos al flujo de trabajo para proteger la imagen que '
            'buscamos…',
        maxLines: 4,
        initialValue: values['narrative'] ?? '',
        onChanged: (v) => _saveValue(ref, 'narrative', v.trim()),
      ),
    );

    final steps = BiblePointPanel(
      label: label(WorkflowPoints.steps, 'Del rodaje a la entrega'),
      icon: Icons.account_tree_outlined,
      child: BibleTableWidget(
        key: const ValueKey('workflow_steps'),
        value: stepsValue,
        onChanged: (value) =>
            _saveValue(ref, WorkflowPoints.steps, value.encode()),
      ),
    );

    final team = BiblePointPanel(
      label: label(WorkflowPoints.team, 'Equipo de datos'),
      icon: Icons.groups_outlined,
      child: BibleTextSpecsWidget(
        key: const ValueKey('workflow_team'),
        value: teamValue,
        hint:
            'Quién hace las copias, quién las comprueba y qué no se borra '
            'sin confirmar…',
        onChanged: (value) =>
            _saveValue(ref, WorkflowPoints.team, value.encode()),
      ),
    );

    final delivery = BiblePointPanel(
      label: label(WorkflowPoints.delivery, 'Formatos y entrega'),
      icon: Icons.send_outlined,
      child: BibleTextSpecsWidget(
        key: const ValueKey('workflow_delivery'),
        value: deliveryValue,
        // Códec y cadencia son los de Cámara mientras no se escriba otro.
        placeholders: WorkflowPoints.fromCamera(
          codec: data.codec,
          frameRate: data.frameRateNotes,
        ),
        hint: 'Qué se entrega, a quién y en qué formato…',
        onChanged: (value) {
          _saveValue(ref, WorkflowPoints.delivery, value.encode());
          data
            ..workflowPipeline = _orNull(
              WorkflowPoints.row(value, WorkflowPoints.rowPipeline),
            )
            ..resolutionNotes = _orNull(
              WorkflowPoints.row(value, WorkflowPoints.rowResolution),
            )
            ..deliveryColorSpace = _orNull(
              WorkflowPoints.row(value, WorkflowPoints.rowColorSpace),
            );
          onChanged(data);
        },
      ),
    );

    return BibleSectionScaffold(
      sectionId: _sectionId,
      projectId: projectId,
      data: data,
      onChanged: onChanged,
      sectionContentJson: sectionContentJson,
      narrativeHint:
          'Qué le pedimos al flujo de trabajo para proteger la imagen que '
          'buscamos…',
      sectionNumber: null,
      sectionTitle: 'Workflow',
      duplicateValues: {
        WorkflowPoints.steps: stepsValue.encode(),
        WorkflowPoints.team: teamValue.encode(),
        WorkflowPoints.delivery: deliveryValue.encode(),
      },
      fieldWidgets: {
        'narrative': narrative,
        WorkflowPoints.steps: steps,
        WorkflowPoints.team: team,
        WorkflowPoints.delivery: delivery,
      },
    );
  }
}
