import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../shared/visual_bible/bible_cards.dart';
import '../../../../shared/visual_bible/bible_equipment.dart';
import '../../../../shared/visual_bible/bible_text_specs.dart';
import '../../../../shared/visual_bible/camera_pilot_resolve.dart';
import '../../../../shared/visual_bible/camera_points.dart';
import '../../bible_section_fields.dart';
import '../../visual_bible_model.dart';
import '../bible_card_editor.dart';
import '../bible_cards_widget.dart';
import '../bible_equipment_widget.dart';
import '../bible_navigation_scope.dart';
import '../bible_point_panel.dart';
import '../bible_table_widget.dart';
import '../bible_unified_references_panel.dart';
import 'section_scaffold.dart';

/// Cámara y sensor: con qué se rueda y por qué.
///
/// Sus puntos se pintan con los widgets del catálogo. Lo que cada uno
/// guarda, y de dónde se lee lo escrito en biblias anteriores, está en
/// [CameraPoints].
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

  static const _sectionId = BibleSectionId.camera;

  Future<void> _saveValue(WidgetRef ref, String key, String? value) => ref
      .read(databaseProvider)
      .saveBibleSectionFieldValue(data.id, _sectionId, key, value);

  static String? _orNull(String text) =>
      text.trim().isEmpty ? null : text.trim();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final blob = CameraPilotResolve.parseBlob(sectionContentJson);
    final values = BibleSectionFieldsConfig.parseValues(sectionContentJson);
    final labels = {
      for (final field in BibleSectionFieldsConfig.parse(
        sectionContentJson,
        _sectionId,
      ))
        field.key: field.label,
    };
    String label(String key, String fallback) => labels[key] ?? fallback;

    final recordingValue = CameraPoints.recordingValue(
      values,
      blob,
      captureResolution: CameraPilotResolve.captureResolution(blob, data),
      codec: data.codec ?? data.recordingFormat,
      colorScience: data.colorScienceNotes,
      frameRate: data.frameRateNotes,
    );
    final matrixValue = CameraPoints.matrixValue(values);
    final pipelineValue = CameraPoints.colorPipelineValue(
      values,
      blob,
      showLut: data.creativeLutName,
    );
    final accessoriesValue = CameraPoints.accessoriesValue(values, blob);
    final dataFlowCards = CameraPoints.dataFlowCards(
      values,
      blob,
      workflowPipeline: data.workflowPipeline,
    );
    final philosophyValue = CameraPoints.philosophyValue(
      values,
      philosophy: data.cameraPhilosophy,
      movementStyle: data.movementStyle,
    );
    final movementCards = CameraPoints.movementCards(
      values,
      data.cameraMovements,
    );
    final bodyValue = CameraPoints.bodyValue(
      values,
      blob,
      nativeIso: data.nativeIso,
    );
    final imageSource = BibleCardImageSource(
      projectId: projectId,
      bibleId: data.id,
      sectionId: _sectionId,
    );

    // La cámara principal de biblias anteriores, hasta que el punto
    // «Cámaras» tenga su propio valor.
    Widget withLegacyCamera(
      Widget Function(List<BibleEquipmentItem> items) builder,
    ) {
      if (values.containsKey(CameraPoints.equipment)) {
        return builder(CameraPoints.equipmentItems(values));
      }
      return FutureBuilder<Camera?>(
        future: db.resolveProjectCamera(projectId),
        builder: (context, snap) {
          final camera = snap.data;
          return builder(
            CameraPoints.equipmentItems(
              values,
              legacyCameraId: camera?.id,
              legacyCameraName: camera == null
                  ? null
                  : '${camera.brand} ${camera.model}',
              legacyFacts: camera == null ? const {} : cameraFacts(camera),
            ),
          );
        },
      );
    }

    final equipment = BiblePointPanel(
      label: label(CameraPoints.equipment, 'Cámaras'),
      icon: Icons.videocam_outlined,
      child: withLegacyCamera(
        (items) => BibleCameraEquipmentPoint(
          projectId: projectId,
          items: items,
          onChanged: (next) {
            _saveValue(
              ref,
              CameraPoints.equipment,
              BibleEquipmentItem.encode(next),
            );
            // La cámara A es la principal del proyecto para el resto de
            // la app (planta, óptica, formato).
            final main = next.isEmpty ? null : next.first;
            if (main?.catalogId != data.primaryCameraId) {
              data.primaryCameraId = main?.catalogId;
              onChanged(data);
            }
          },
        ),
      ),
    );

    final body = BiblePointPanel(
      label: label(CameraPoints.body, 'Ficha del cuerpo'),
      icon: Icons.memory_outlined,
      child: withLegacyCamera((items) {
        final facts = items.isEmpty
            ? const <String, String>{}
            : items.first.facts;
        return BibleTextSpecsWidget(
          // Al cambiar de cámara cambian los datos de su ficha.
          key: ValueKey('camera_body_${items.isEmpty ? '' : items.first.name}'),
          value: bodyValue,
          placeholders: facts,
          hint:
              'Cómo se va a usar el sensor: a qué ISO, cuándo se sube, qué '
              'se evita…',
          onChanged: (value) {
            _saveValue(ref, CameraPoints.body, value.encode());
            final iso = int.tryParse(
              CameraPoints.row(value, CameraPoints.rowNativeIso),
            );
            if (iso != data.nativeIso) {
              data.nativeIso = iso;
              onChanged(data);
            }
          },
        );
      }),
    );

    final recording = BiblePointPanel(
      label: label(CameraPoints.recording, 'Formato y cadencia'),
      icon: Icons.movie_creation_outlined,
      child: BibleTextSpecsWidget(
        key: const ValueKey('camera_recording'),
        value: recordingValue,
        hint: 'En qué se graba y por qué: resolución, códec, cadencia…',
        onChanged: (value) {
          _saveValue(ref, CameraPoints.recording, value.encode());
          // Columnas que leen Formato, Workflow y el resumen del proyecto.
          data
            ..captureResolution = _orNull(
              CameraPoints.row(value, CameraPoints.rowResolution),
            )
            ..codec = _orNull(CameraPoints.row(value, CameraPoints.rowCodec))
            ..colorScienceNotes = _orNull(
              CameraPoints.row(value, CameraPoints.rowColorSpace),
            )
            ..frameRateNotes = _orNull(
              CameraPoints.row(value, CameraPoints.rowFrameRate),
            );
          onChanged(data);
        },
      ),
    );

    final matrix = BiblePointPanel(
      label: label(CameraPoints.matrix, 'Matriz de grabación'),
      icon: Icons.table_rows_outlined,
      child: BibleTableWidget(
        key: const ValueKey('camera_matrix'),
        value: matrixValue,
        onChanged: (value) =>
            _saveValue(ref, CameraPoints.matrix, value.encode()),
      ),
    );

    final pipeline = BiblePointPanel(
      label: label(CameraPoints.colorPipeline, 'Color en cámara'),
      icon: Icons.gradient_outlined,
      child: BibleTextSpecsWidget(
        key: const ValueKey('camera_pipeline'),
        value: pipelineValue,
        hint: 'Cómo se ve la imagen en el set y qué se entrega a color…',
        onChanged: (value) {
          _saveValue(ref, CameraPoints.colorPipeline, value.encode());
          data.creativeLutName = _orNull(
            CameraPoints.row(value, CameraPoints.rowShowLut),
          );
          onChanged(data);
        },
      ),
    );

    final accessories = BiblePointPanel(
      label: label(CameraPoints.accessories, 'Filtros, soportes y accesorios'),
      icon: Icons.inventory_2_outlined,
      child: BibleTableWidget(
        key: const ValueKey('camera_accessories'),
        value: accessoriesValue,
        onChanged: (value) =>
            _saveValue(ref, CameraPoints.accessories, value.encode()),
      ),
    );

    final dataFlow = BiblePointPanel(
      label: label(CameraPoints.dataFlow, 'Gestión de datos'),
      icon: Icons.storage_outlined,
      child: BibleCardsWidget(
        imageSource: imageSource,
        cards: dataFlowCards,
        onChanged: (cards) => _saveValue(
          ref,
          CameraPoints.dataFlow,
          BibleCard.encode(cards) ?? '[]',
        ),
      ),
    );

    final philosophy = BiblePointPanel(
      label: label(CameraPoints.philosophy, 'Filosofía de cámara'),
      icon: Icons.psychology_alt_outlined,
      child: BibleTextSpecsWidget(
        key: const ValueKey('camera_philosophy'),
        value: philosophyValue,
        hint: 'Cómo mira la cámara: distancia, altura, cuándo se mueve…',
        onChanged: (value) {
          _saveValue(ref, CameraPoints.philosophy, value.encode());
          data
            ..cameraPhilosophy = _orNull(value.text)
            ..movementStyle = _orNull(
              CameraPoints.row(value, CameraPoints.rowMovementStyle),
            );
          onChanged(data);
        },
      ),
    );

    final movements = BiblePointPanel(
      label: label(CameraPoints.movements, 'Movimientos de cámara'),
      icon: Icons.control_camera_outlined,
      child: BibleCardsWidget(
        imageSource: imageSource,
        layout: BibleCardsLayout.columns,
        cards: movementCards,
        onChanged: (cards) {
          _saveValue(
            ref,
            CameraPoints.movements,
            BibleCard.encode(cards) ?? '[]',
          );
          data.cameraMovements = [
            for (final card in cards)
              if (!card.isEmpty)
                {
                  'movement': card.title,
                  'narrative': card.body,
                  'reference': '',
                },
          ];
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
          '¿Por qué esta cámara y este sensor? Qué queremos contar con '
          'este formato…',
      sectionNumber: null,
      sectionTitle: 'Cámara y sensor',
      duplicateValues: {
        CameraPoints.body: bodyValue.encode(),
        CameraPoints.recording: recordingValue.encode(),
        CameraPoints.matrix: matrixValue.encode(),
        CameraPoints.colorPipeline: pipelineValue.encode(),
        CameraPoints.accessories: accessoriesValue.encode(),
        CameraPoints.dataFlow: BibleCard.encode(dataFlowCards),
        CameraPoints.philosophy: philosophyValue.encode(),
        CameraPoints.movements: BibleCard.encode(movementCards),
      },
      fieldWidgets: {
        CameraPoints.equipment: equipment,
        CameraPoints.body: body,
        CameraPoints.recording: recording,
        CameraPoints.matrix: matrix,
        CameraPoints.colorPipeline: pipeline,
        CameraPoints.accessories: accessories,
        CameraPoints.dataFlow: dataFlow,
        CameraPoints.philosophy: philosophy,
        CameraPoints.movements: movements,
        // Punto de biblias anteriores: eran las imágenes de la pantalla.
        if (data.id > 0)
          'specsReference': BibleReferencesPanel(
            projectId: projectId,
            sectionId: _sectionId,
            bibleId: data.id,
            title: label('specsReference', 'Referencias técnicas'),
            onOpenMoodboard: () =>
                BibleNavigationScope.openMoodboardForSection(
                  context,
                  _sectionId,
                ),
          ),
      },
    );
  }
}
