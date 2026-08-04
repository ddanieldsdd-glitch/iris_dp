import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_card.dart';
import '../optics_lab/optics_calculator.dart';
import '../optics_lab/sensor_mode_utils.dart';
import '../visual_bible/widgets/bible_form_widgets.dart';
import 'storage_calculator.dart';
import 'storage_codec_catalog.dart';
import 'storage_resolution_catalog.dart';

/// Calculadora de almacenamiento y data rate (modelo PHFX framesToDataRate).
class StorageCalculatorScreen extends ConsumerStatefulWidget {
  final int projectId;

  const StorageCalculatorScreen({super.key, required this.projectId});

  @override
  ConsumerState<StorageCalculatorScreen> createState() =>
      _StorageCalculatorScreenState();
}

class _StorageCalculatorScreenState
    extends ConsumerState<StorageCalculatorScreen> {
  StorageResolution _resolution = kCommonResolutions[5];
  double _fps = 24;
  int _hours = 1;
  int _minutes = 0;
  int _seconds = 0;
  int _dayMultiplier = 1;
  RecordingCodecFamily _codecFamily = RecordingCodecFamily.none;
  String? _codecVariant;
  DeliveryFormat _delivery = DeliveryFormat.sameAsSource;

  Camera? _selectedCamera;
  SensorModeSpec? _selectedMode;

  final _widthCtrl = TextEditingController(text: '4096');
  final _heightCtrl = TextEditingController(text: '2160');
  final _customFpsCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController(text: '1');
  final _minutesCtrl = TextEditingController();
  final _secondsCtrl = TextEditingController();
  final _dayMultCtrl = TextEditingController(text: '1');
  bool _useCustomResolution = false;

  @override
  void dispose() {
    _widthCtrl.dispose();
    _heightCtrl.dispose();
    _customFpsCtrl.dispose();
    _hoursCtrl.dispose();
    _minutesCtrl.dispose();
    _secondsCtrl.dispose();
    _dayMultCtrl.dispose();
    super.dispose();
  }

  StorageResolution get _activeResolution {
    if (_useCustomResolution) {
      final w = int.tryParse(_widthCtrl.text.trim()) ?? _resolution.width;
      final h = int.tryParse(_heightCtrl.text.trim()) ?? _resolution.height;
      return StorageResolution(width: w, height: h, label: '${w}x$h');
    }
    return _resolution;
  }

  double get _activeFps {
    final custom = double.tryParse(_customFpsCtrl.text.trim());
    if (custom != null && custom > 0) return custom;
    return _fps;
  }

  StorageCalculationResult get _result => StorageCalculator.compute(
        source: _activeResolution,
        frameRate: _activeFps,
        hours: _hours,
        minutes: _minutes,
        seconds: _seconds,
        dayMultiplier: _dayMultiplier,
        recordingCodec: _codecFamily,
        recordingVariantId: _codecVariant,
        delivery: _delivery,
      );

  List<SensorModeSpec> _parseModes(Camera? cam) {
    final jsonStr = cam?.sensorModesJson;
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      return (jsonDecode(jsonStr) as List)
          .map((e) => SensorModeSpec.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Resolución en px del modo: usa datos del catálogo o estima desde mm físicos.
  (int width, int height, bool estimated) _resolutionForMode(
    Camera cam,
    SensorModeSpec mode,
  ) {
    final ctx = SensorModeContext.fromCamera(cam, mode);
    final rp = ctx.recordingPixels;
    return (rp.$1, rp.$2, rp.$3);
  }

  List<SensorModeSpec> _modesForCamera(Camera? cam) {
    if (cam == null) return [];
    final modes = parseSensorModesJson(cam.sensorModesJson);
    if (modes.isNotEmpty) return modes;
    return [
      SensorModeSpec(
        name: 'Open Gate',
        widthMm: cam.sensorWidthMm,
        heightMm: cam.sensorHeightMm,
      ),
    ];
  }

  void _applyCameraMode(Camera cam, SensorModeSpec mode) {
    final (w, h, estimated) = _resolutionForMode(cam, mode);
    final ctx = SensorModeContext.fromCamera(cam, mode);
    setState(() {
      _selectedCamera = cam;
      _selectedMode = mode;
      _useCustomResolution = false;
      _resolution = StorageResolution(
        width: w,
        height: h,
        label: estimated
            ? '${cam.brand} ${cam.model} — ${mode.name} (est.) · ${ctx.cropLabel}'
            : '${cam.brand} ${cam.model} — ${mode.name} · ${ctx.cropLabel}',
      );
      _widthCtrl.text = '$w';
      _heightCtrl.text = '$h';
    });
  }

  void _parseDurationField(String v, void Function(int) setter) {
    setter(int.tryParse(v) ?? 0);
    setState(() {});
  }

  String _cameraLabel(Camera camera, List<Camera> all) {
    final base = '${camera.brand} ${camera.model}';
    final duplicates =
        all.where((c) => c.brand == camera.brand && c.model == camera.model).length;
    if (duplicates > 1) {
      final suffix = camera.isCustom ? 'custom' : 'catálogo';
      return '$base · $suffix #${camera.id}';
    }
    if (camera.isCustom) return '$base (custom)';
    return base;
  }

  int _modeIndexFor(Camera cam, SensorModeSpec? mode) {
    final modes = _modesForCamera(cam);
    if (mode == null) return 0;
    final idx = modes.indexWhere(
      (m) =>
          m.name == mode.name &&
          m.widthMm == mode.widthMm &&
          m.heightMm == mode.heightMm,
    );
    return idx >= 0 ? idx : 0;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);
    final result = _result;
    final variants = kRecordingCodecVariants[_codecFamily] ?? [];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          'Calculadora de almacenamiento',
          style: AppTypography.titleMedium(palette),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Estima data rates y espacio en tarjeta según resolución, fps, '
          'códec y duración. Modelo basado en PHFX framesToDataRate.',
          style: AppTypography.caption(palette)
              .copyWith(color: palette.textTertiary),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Paso 1 — Resolución', style: AppTypography.label(palette)),
              const SizedBox(height: AppSpacing.md),
              StreamBuilder<List<Camera>>(
                stream: db.watchAllCameras(),
                builder: (context, snap) {
                  final cameras = snap.data ?? [];
                  if (cameras.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cámara del catálogo', style: AppTypography.label(palette)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        isExpanded: true,
                        value: _selectedCamera != null &&
                                cameras.any((c) => c.id == _selectedCamera!.id)
                            ? _selectedCamera!.id
                            : null,
                        dropdownColor: palette.surfaceElevated,
                        style: AppTypography.bodyLarge(palette),
                        decoration: const InputDecoration(),
                        hint: const Text('—'),
                        items: cameras
                            .map(
                              (c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(
                                  _cameraLabel(c, cameras),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (id) {
                          if (id == null) {
                            setState(() {
                              _selectedCamera = null;
                              _selectedMode = null;
                            });
                            return;
                          }
                          final cam = cameras.firstWhere((c) => c.id == id);
                          final modes = _modesForCamera(cam);
                          _applyCameraMode(cam, modes.first);
                        },
                      ),
                      if (_selectedCamera != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Builder(
                          builder: (context) {
                            final modes = _modesForCamera(_selectedCamera!);
                            final modeIndex = _modeIndexFor(_selectedCamera!, _selectedMode);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Modo sensor / resolución de grabación',
                                  style: AppTypography.label(palette),
                                ),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<int>(
                                  isExpanded: true,
                                  value: modeIndex.clamp(0, modes.length - 1),
                                  dropdownColor: palette.surfaceElevated,
                                  style: AppTypography.bodyLarge(palette),
                                  decoration: const InputDecoration(),
                                  items: modes.asMap().entries.map((entry) {
                                    final m = entry.value;
                                    final ctx = SensorModeContext.fromCamera(
                                      _selectedCamera!,
                                      m,
                                    );
                                    final (w, h, est) = _resolutionForMode(
                                      _selectedCamera!,
                                      m,
                                    );
                                    final resLabel = est ? '$w×$h (est.)' : '$w×$h';
                                    return DropdownMenuItem(
                                      value: entry.key,
                                      child: Text(
                                        '${m.name} · $resLabel · ${ctx.cropLabel}',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (idx) {
                                    if (idx == null) return;
                                    _applyCameraMode(_selectedCamera!, modes[idx]);
                                  },
                                ),
                              ],
                            );
                          },
                        ),
                        if (_selectedMode != null &&
                            _resolutionForMode(_selectedCamera!, _selectedMode!).$3)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.xs),
                            child: Text(
                              'Resolución estimada desde área física del sensor '
                              '(sin px en catálogo).',
                              style: AppTypography.caption(palette)
                                  .copyWith(color: palette.textTertiary),
                            ),
                          ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                    ],
                  );
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Resolución personalizada',
                  style: AppTypography.bodyLarge(palette),
                ),
                value: _useCustomResolution,
                onChanged: (v) => setState(() => _useCustomResolution = v),
              ),
              if (!_useCustomResolution)
                BibleDropdown(
                  label: 'Resolución común',
                  options: kCommonResolutions.map((r) => r.label).toList(),
                  value: _resolution.label,
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _resolution =
                          kCommonResolutions.firstWhere((r) => r.label == v);
                      _widthCtrl.text = '${_resolution.width}';
                      _heightCtrl.text = '${_resolution.height}';
                    });
                  },
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _widthCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(labelText: 'Ancho (px)'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: TextField(
                        controller: _heightCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(labelText: 'Alto (px)'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Paso 2–4 — FPS, duración, códec',
                  style: AppTypography.label(palette)),
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        BibleDropdown(
                          label: 'Frame rate',
                          options: kStandardFrameRates
                              .map((f) => f.toString())
                              .toList(),
                          value: _fps.toString(),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() {
                              _fps = double.parse(v);
                              _customFpsCtrl.clear();
                            });
                          },
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextField(
                          controller: _customFpsCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'FPS personalizado',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      children: [
                        TextField(
                          controller: _hoursCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(labelText: 'Horas'),
                          onChanged: (v) => _parseDurationField(v, (n) => _hours = n),
                        ),
                        TextField(
                          controller: _minutesCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(labelText: 'Minutos'),
                          onChanged: (v) => _parseDurationField(v, (n) => _minutes = n),
                        ),
                        TextField(
                          controller: _secondsCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(labelText: 'Segundos'),
                          onChanged: (v) => _parseDurationField(v, (n) => _seconds = n),
                        ),
                        TextField(
                          controller: _dayMultCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(
                            labelText: 'Multiplicador jornadas',
                          ),
                          onChanged: (v) => _parseDurationField(
                            v,
                            (n) => _dayMultiplier = n.clamp(1, 999),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              BibleDropdown(
                label: 'Códec de grabación (RAW)',
                options: RecordingCodecFamily.values
                    .map((f) => kRecordingCodecFamilies[f]!)
                    .toList(),
                value: kRecordingCodecFamilies[_codecFamily]!,
                onChanged: (v) {
                  if (v == null) return;
                  final family = kRecordingCodecFamilies.entries
                      .firstWhere((e) => e.value == v)
                      .key;
                  setState(() {
                    _codecFamily = family;
                    final vars = kRecordingCodecVariants[family] ?? [];
                    _codecVariant = vars.isNotEmpty ? vars.first.id : null;
                  });
                },
              ),
              if (variants.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                BibleDropdown(
                  label: 'Variante',
                  options: variants.map((v) => v.label).toList(),
                  value: variants
                      .firstWhere(
                        (v) => v.id == _codecVariant,
                        orElse: () => variants.first,
                      )
                      .label,
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _codecVariant =
                          variants.firstWhere((vr) => vr.label == v).id;
                    });
                  },
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              BibleDropdown(
                label: 'Formato de entrega (ProRes / DNxHR)',
                options: kDeliveryFormats.map((d) => d.label).toList(),
                value: _delivery.label,
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _delivery =
                        kDeliveryFormats.firstWhere((d) => d.label == v);
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Resumen', style: AppTypography.label(palette)),
              const SizedBox(height: AppSpacing.sm),
              _InfoRow(
                label: 'Resolución',
                value: result.sourceResolution.dimensionsLabel,
              ),
              _InfoRow(
                label: 'Megapíxeles',
                value: result.sourceResolution.megapixels.toStringAsFixed(2),
              ),
              _InfoRow(
                label: 'Aspect ratio',
                value: result.sourceResolution.aspectLabel,
              ),
              _InfoRow(label: 'Frame rate', value: '${result.frameRate} fps'),
              if (result.totalDuration != null) ...[
                _InfoRow(
                  label: 'Duración',
                  value: formatDurationLabel(result.totalDuration!),
                ),
                _InfoRow(
                  label: 'Frames totales',
                  value: '${result.totalFrames ?? 0}',
                ),
              ],
              if (result.deliveryResolution != null)
                _InfoRow(
                  label: 'Resolución entrega',
                  value: result.deliveryResolution!.dimensionsLabel,
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final section in result.sections) ...[
          _DataRateSectionTable(
            section: section,
            hasProject: result.totalDuration != null,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Text(
          'Referencia: PHFX framesToDataRate (Phil Holland). '
          'Estimaciones orientativas para planificación de workflow.',
          style: AppTypography.caption(palette)
              .copyWith(color: palette.textTertiary, fontSize: 11),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: AppTypography.caption(palette)
                  .copyWith(color: palette.textTertiary),
            ),
          ),
          Expanded(
            child: Text(value, style: AppTypography.bodyLarge(palette)),
          ),
        ],
      ),
    );
  }
}

class _DataRateSectionTable extends StatelessWidget {
  final DataRateSection section;
  final bool hasProject;

  const _DataRateSectionTable({
    required this.section,
    required this.hasProject,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(section.title, style: AppTypography.label(palette)),
          const SizedBox(height: AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 36,
              dataRowMinHeight: 32,
              dataRowMaxHeight: 40,
              columnSpacing: 16,
              columns: [
                const DataColumn(label: Text('Códec')),
                const DataColumn(label: Text('/ frame')),
                const DataColumn(label: Text('/ segundo')),
                const DataColumn(label: Text('/ minuto')),
                const DataColumn(label: Text('/ hora')),
                if (hasProject) const DataColumn(label: Text('Proyecto')),
              ],
              rows: [
                for (final row in section.rows)
                  DataRow(cells: [
                    DataCell(Text(row.label, style: const TextStyle(fontSize: 12))),
                    DataCell(Text(formatStorageSize(row.bytesPerFrame))),
                    DataCell(Text(formatStorageSize(row.bytesPerSecond))),
                    DataCell(Text(formatStorageSize(row.bytesPerMinute))),
                    DataCell(Text(formatStorageSize(row.bytesPerHour))),
                    if (hasProject)
                      DataCell(Text(
                        row.bytesForProject != null
                            ? formatStorageSize(row.bytesForProject!)
                            : '—',
                      )),
                  ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}