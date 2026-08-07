import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../visual_bible_model.dart';
import '../bible_form_widgets.dart';
import '../bible_section_shared_widgets.dart';
import '../narrative_bridge_card.dart';
import '../../../equipment/widgets/equipment_picker.dart';

class CameraSensorSection extends ConsumerStatefulWidget {
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
  ConsumerState<CameraSensorSection> createState() => _CameraSensorSectionState();
}

class _CameraSensorSectionState extends ConsumerState<CameraSensorSection> {
  late BibleVisualMode _visualMode;

  @override
  void initState() {
    super.initState();
    _visualMode = _parseVisualMode(widget.sectionContentJson);
  }

  BibleVisualMode _parseVisualMode(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return BibleVisualMode.cinematic;
    try {
      final map = jsonDecode(jsonStr);
      final modeStr = map['visualMode'] as String?;
      return BibleVisualMode.values.firstWhere(
        (e) => e.name == modeStr,
        orElse: () => BibleVisualMode.cinematic,
      );
    } catch (_) {
      return BibleVisualMode.cinematic;
    }
  }

  void _onModeChanged(BibleVisualMode mode) {
    setState(() => _visualMode = mode);
    // Nota: Como no hay un callback para actualizar sectionContentJson directamente, 
    // mantenemos el estado visual localmente.
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        BibleSectionHeader(
          number: '02',
          title: 'Cámara y Sensor',
          trailing: BibleSectionModeDropdown(
            value: _visualMode,
            onChanged: _onModeChanged,
          ),
        ),

        NarrativeBridgeCard(
          title: 'INTENCIÓN NARRATIVA (CÁMARA)',
          hint: '¿Por qué esta cámara y sensor? Qué queremos contar con este formato, rango dinámico y color science...',
          value: data.cameraNarrativeIntent,
          onChanged: (v) {
            data.cameraNarrativeIntent = v;
            widget.onChanged(data);
          },
        ),
        const SizedBox(height: AppSpacing.lg),

        // Bloque A-CAM
        StreamBuilder<List<Camera>>(
          stream: db.watchAllCameras(),
          builder: (context, snap) {
            final cameras = snap.data ?? [];
            final selectedCamera = cameras.where((c) => c.id == data.primaryCameraId).firstOrNull;

            return AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: palette.accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'A-CAM',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: palette.accent,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            if (cameras.isNotEmpty)
                              EquipmentPicker(
                                projectId: widget.projectId,
                                equipmentType: 'camera',
                                label: 'Cámara principal',
                                selectedId: data.primaryCameraId,
                                onSelected: (id) {
                                  final cam = cameras.where((c) => c.id == id).firstOrNull;
                                  data.primaryCameraId = id;
                                  if (cam != null) {
                                    data.nativeIso ??= cam.nativeIso;
                                    data.colorScienceNotes ??= cam.colorScience;
                                  }
                                  widget.onChanged(data);
                                },
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      BibleHeroValue(
                        value: data.nativeIso?.toString() ?? '—',
                        unit: 'ISO',
                        label: 'ISO NATIVO',
                        color: palette.accent,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: BibleTechCard(
                          label: 'Sensor',
                          value: data.captureResolution ??
                              (selectedCamera != null
                                  ? '${selectedCamera.sensorWidthMm.toStringAsFixed(1)}×${selectedCamera.sensorHeightMm.toStringAsFixed(1)} mm'
                                  : '—'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: BibleTechCard(
                          label: 'Color Science',
                          value: data.colorScienceNotes ?? (selectedCamera?.colorScience ?? '—'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: BibleTechCard(
                          label: 'Rango Dinámico',
                          value: '14+ stops',
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: BibleTechCard(
                          label: 'Montura',
                          value: 'LPL/PL',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),

        // Formato y Codec
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FORMATO Y CÓDEC',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: palette.textTertiary,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: BibleTechCard(
                      label: 'Formato',
                      value: data.recordingFormat ?? '—',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: BibleTechCard(
                      label: 'Códec',
                      value: data.codec ?? '—',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: BibleTechCard(
                      label: 'Resolución',
                      value: data.captureResolution ?? '—',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: BibleTechCard(
                      label: 'Frame Rate',
                      value: data.frameRateNotes ?? '—',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: BibleTextField(
                      label: 'Formato',
                      hint: 'ProRes / RAW',
                      initialValue: data.recordingFormat,
                      onChanged: (v) {
                        data.recordingFormat = v.trim().isEmpty ? null : v.trim();
                        widget.onChanged(data);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: BibleTextField(
                      label: 'Códec',
                      hint: 'ProRes 4444 XQ',
                      initialValue: data.codec,
                      onChanged: (v) {
                        data.codec = v.trim().isEmpty ? null : v.trim();
                        widget.onChanged(data);
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
                      label: 'Resolución (Capture)',
                      hint: '4K DCI',
                      initialValue: data.captureResolution,
                      onChanged: (v) {
                        data.captureResolution = v.trim().isEmpty ? null : v.trim();
                        widget.onChanged(data);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: BibleTextField(
                      label: 'Frame Rate general',
                      hint: '24fps',
                      initialValue: data.frameRateNotes,
                      onChanged: (v) {
                        data.frameRateNotes = v.trim().isEmpty ? null : v.trim();
                        widget.onChanged(data);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Cadencia y Obturación
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CADENCIA Y OBTURACIÓN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: palette.textTertiary,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const BibleChipRow(
                chips: ['24fps', '25fps', '48fps', '120fps'],
              ),
              const SizedBox(height: AppSpacing.md),
              BibleTextField(
                label: 'Notas de cadencia',
                hint: 'Uso de frame rates alternativos por escena...',
                initialValue: data.frameRateNotes,
                onChanged: (v) {
                  data.frameRateNotes = v.trim().isEmpty ? null : v.trim();
                  widget.onChanged(data);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: palette.accent),
                  color: palette.accent.withValues(alpha: 0.05),
                ),
                child: BibleTextField(
                  label: 'SLOW MOTION',
                  hint: 'Notas específicas sobre slow motion, ángulo de obturación...',
                  initialValue: data.resolutionNotes, // Reusing field for demo purposes
                  onChanged: (v) {
                    data.resolutionNotes = v.trim().isEmpty ? null : v.trim();
                    widget.onChanged(data);
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Gestión DIT
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GESTIÓN DIT Y DATA',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: palette.textTertiary,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: BibleTechCard(
                      label: 'Flujo DIT',
                      value: data.workflowPipeline ?? '—',
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: BibleTechCard(
                      label: 'Protocolo de Transferencia',
                      value: '—',
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: BibleTechCard(
                      label: 'Estrategia de Backup',
                      value: '—',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Latitude Comparison
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LATITUDE COMPARISON',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: palette.textTertiary,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              BibleHorizontalBar(
                label: 'A-CAM',
                fraction: 0.85,
                valueLabel: '+14 stops',
                barColor: palette.accent,
              ),
              const SizedBox(height: AppSpacing.sm),
              BibleHorizontalBar(
                label: 'B-CAM',
                fraction: 0.70,
                valueLabel: '+11 stops',
                barColor: palette.success,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Data Rate & Storage
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DATA RATE & STORAGE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: palette.textTertiary,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              BibleHorizontalBar(
                label: 'A-CAM',
                fraction: 0.6,
                valueLabel: '~2.8 GB/hr',
                barColor: palette.accent,
              ),
              const SizedBox(height: AppSpacing.sm),
              BibleHorizontalBar(
                label: 'B-CAM',
                fraction: 0.4,
                valueLabel: '~1.4 GB/hr',
                barColor: palette.textSecondary,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Filosofía de cámara
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: BibleTextField(
            label: 'Filosofía de cámara',
            hint: '¿La cámara observa o participa? ¿Es objetiva o subjetiva?',
            maxLines: 4,
            initialValue: data.cameraPhilosophy,
            onChanged: (v) {
              data.cameraPhilosophy = v.trim().isEmpty ? null : v.trim();
              widget.onChanged(data);
            },
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Movimientos
        _CameraMovements(data: data, onChanged: widget.onChanged),
      ],
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
    final palette = context.palette;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'MOVIMIENTOS DE CÁMARA',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: palette.textTertiary,
                    letterSpacing: 1.1,
                  ),
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
                icon: Icon(Icons.add, size: 16, color: palette.accent),
                label: Text('Añadir', style: TextStyle(color: palette.accent)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
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
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: palette.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: palette.border, width: 0.5),
                ),
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
                          icon: Icon(Icons.delete_outline, color: palette.error),
                          onPressed: () {
                            data.cameraMovements.removeAt(i);
                            onChanged(data);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    BibleTextField(
                      label: 'Intención narrativa',
                      hint: 'Qué pretendemos contar al mover la cámara así...',
                      maxLines: 2,
                      initialValue: mov['narrative'],
                      onChanged: (v) {
                        mov['narrative'] = v;
                        onChanged(data);
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    BibleTextField(
                      label: 'Referencia (película / fragmento)',
                      hint: 'Children of Men — plano secuencia...',
                      initialValue: mov['reference'],
                      onChanged: (v) {
                        mov['reference'] = v;
                        onChanged(data);
                      },
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
