import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../bible_section_fields.dart';
import '../../seeds/camera_specs_seed.dart';
import '../../visual_bible_model.dart';
import '../bible_form_widgets.dart';
import '../../../equipment/widgets/equipment_picker.dart';
import 'section_scaffold.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);

    final philosophyLabel = BibleSectionFieldsConfig.labelFor(
      sectionContentJson,
      BibleSectionId.camera,
      'philosophy',
      'Filosofía de cámara',
    );
    final cameraBodyLabel = BibleSectionFieldsConfig.labelFor(
      sectionContentJson,
      BibleSectionId.camera,
      'cameraBody',
      'Cámara y formato',
    );

    return BibleSectionScaffold(
      sectionId: BibleSectionId.camera,
      projectId: projectId,
      data: data,
      onChanged: onChanged,
      sectionContentJson: sectionContentJson,
      narrativeHint:
          '¿Por qué esta cámara y sensor? Qué queremos contar con este '
          'formato, rango dinámico y color science…',
      fieldWidgets: {
        'cameraBody': StreamBuilder<List<Camera>>(
          stream: db.watchAllCameras(),
          builder: (context, snap) {
            final cameras = snap.data ?? [];

            return AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cameraBodyLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (cameras.isNotEmpty)
                    EquipmentPicker(
                      projectId: projectId,
                      equipmentType: 'camera',
                      label: 'Cámara principal',
                      selectedId: data.primaryCameraId,
                      onSelected: (id) {
                        final cam =
                            cameras.where((c) => c.id == id).firstOrNull;
                        data.primaryCameraId = id;
                        if (cam != null) {
                          data.nativeIso ??= cam.nativeIso;
                          data.colorScienceNotes ??= cam.colorScience;
                        }
                        onChanged(data);
                      },
                    ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: BibleTextField(
                          label: 'Formato / códec',
                          hint: 'ProRes 4444 XQ',
                          initialValue: data.recordingFormat,
                          onChanged: (v) {
                            data.recordingFormat =
                                v.trim().isEmpty ? null : v.trim();
                            onChanged(data);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: BibleTextField(
                          label: 'Códec',
                          hint: 'ProRes / RAW',
                          initialValue: data.codec,
                          onChanged: (v) {
                            data.codec = v.trim().isEmpty ? null : v.trim();
                            onChanged(data);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: BibleTextField(
                          label: 'Resolución / frame rate',
                          hint: '4K DCI 24fps',
                          initialValue: data.resolutionNotes,
                          onChanged: (v) {
                            data.resolutionNotes =
                                v.trim().isEmpty ? null : v.trim();
                            onChanged(data);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: BibleTextField(
                          label: 'ISO nativo',
                          hint: '800',
                          initialValue: data.nativeIso?.toString(),
                          onChanged: (v) {
                            data.nativeIso = int.tryParse(v.trim());
                            onChanged(data);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  BibleTextField(
                    label: 'Notas frame rate por escena',
                    hint: '48fps en clímax, 24fps resto…',
                    maxLines: 2,
                    initialValue: data.frameRateNotes,
                    onChanged: (v) {
                      data.frameRateNotes = v.trim().isEmpty ? null : v.trim();
                      onChanged(data);
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  BibleTextField(
                    label: 'Color science nativa',
                    hint: 'Cómo renderiza highlights, skin tones…',
                    maxLines: 3,
                    initialValue: data.colorScienceNotes,
                    onChanged: (v) {
                      data.colorScienceNotes =
                          v.trim().isEmpty ? null : v.trim();
                      onChanged(data);
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  BibleTextField(
                    label: 'Comportamiento en baja luz',
                    hint: '¿Necesitamos rodar en condiciones de poca luz?',
                    maxLines: 2,
                    initialValue: data.lowLightNotes,
                    onChanged: (v) {
                      data.lowLightNotes = v.trim().isEmpty ? null : v.trim();
                      onChanged(data);
                    },
                  ),
                ],
              ),
            );
          },
        ),
        'philosophy': AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: BibleTextField(
            label: philosophyLabel,
            hint: '¿La cámara observa o participa?',
            maxLines: 4,
            initialValue: data.cameraPhilosophy,
            onChanged: (v) {
              data.cameraPhilosophy = v.trim().isEmpty ? null : v.trim();
              onChanged(data);
            },
          ),
        ),
        'movements': _CameraMovements(data: data, onChanged: onChanged),
        'specsReference': _CameraSpecsReference(),
      },
    );
  }
}

class _CameraMovements extends StatelessWidget {
  final VisualBibleData data;
  final BibleChanged onChanged;

  const _CameraMovements({required this.data, required this.onChanged});

  static const _options = [
    'Estático',
    'Dolly',
    'Steadicam',
    'Mano',
    'Grúa',
    'Zoom',
    'Observacional',
  ];

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Movimientos de cámara',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  data.cameraMovements.add({
                    'movement': 'Dolly',
                    'narrative': '',
                    'reference': '',
                  });
                  onChanged(data);
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Añadir'),
              ),
            ],
          ),
          BibleDropdown(
            label: 'Estilo general',
            options: const ['Estático', 'Observacional', 'Participativo', 'Mixto'],
            value: data.movementStyle,
            onChanged: (v) {
              data.movementStyle = v;
              onChanged(data);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          ...data.cameraMovements.asMap().entries.map((entry) {
            final i = entry.key;
            final mov = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: BibleDropdown(
                          label: 'Movimiento',
                          options: _options,
                          value: mov['movement'],
                          onChanged: (v) {
                            mov['movement'] = v ?? '';
                            onChanged(data);
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          data.cameraMovements.removeAt(i);
                          onChanged(data);
                        },
                      ),
                    ],
                  ),
                  BibleTextField(
                    label: 'Intención narrativa',
                    hint: 'Qué pretendemos contar al mover la cámara así…',
                    maxLines: 2,
                    initialValue: mov['narrative'],
                    onChanged: (v) {
                      mov['narrative'] = v;
                      onChanged(data);
                    },
                  ),
                  BibleTextField(
                    label: 'Referencia (película / fragmento)',
                    hint: 'Children of Men — plano secuencia…',
                    initialValue: mov['reference'],
                    onChanged: (v) {
                      mov['reference'] = v;
                      onChanged(data);
                    },
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _CameraSpecsReference extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Fichas técnicas de referencia',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...kExtendedCameraSpecs.map(
            (spec) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${spec.brand} ${spec.model} — '
                '${spec.dynamicRangeStops} stops, ISO ${spec.nativeIso}, '
                '${spec.colorScience}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
