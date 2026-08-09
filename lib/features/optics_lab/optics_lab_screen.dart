import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/media_storage.dart';
import '../../core/widgets/app_card.dart';
import '../equipment/widgets/project_camera_roster_bar.dart';
import '../luka_export/luka_compatibility_service.dart';
import '../luka_export/luka_manifest_service.dart';
import 'flt_frame_line_preview.dart';
import 'frame_line_geometry.dart';
import 'frame_line_models.dart';
import 'frame_line_settings_panel.dart';
import 'optics_calculator.dart';
import 'optics_lab_samples.dart';
import 'sensor_coverage_painter.dart';
import 'sensor_mode_utils.dart';

/// Laboratorio óptico interactivo estilo ARRI FLT.
class OpticsLabScreen extends ConsumerStatefulWidget {
  final int projectId;
  final int? initialCameraId;
  final int? initialLensId;
  final String? initialAspectRatio;
  final String? initialTStop;
  final String? initialReferenceImagePath;
  final bool showSaveToBible;
  final bool embedded;

  const OpticsLabScreen({
    super.key,
    required this.projectId,
    this.initialCameraId,
    this.initialLensId,
    this.initialAspectRatio,
    this.initialTStop,
    this.initialReferenceImagePath,
    this.showSaveToBible = true,
    this.embedded = false,
  });

  @override
  ConsumerState<OpticsLabScreen> createState() => _OpticsLabScreenState();
}

class _OpticsLabScreenState extends ConsumerState<OpticsLabScreen> {
  final _captureKey = GlobalKey();
  Camera? _camera;
  Lense? _lens;
  SensorModeSpec _mode = const SensorModeSpec(
    name: 'Open Gate',
    widthMm: 27.99,
    heightMm: 19.22,
  );
  double _focalMm = 35;
  double _tStop = 2.8;
  double _subjectM = 3.0;
  double _aspect = 16 / 9;
  bool _loaded = false;
  bool _anamorphicPreview = false;
  double _lensSqueeze = 1.0;
  String? _referenceImagePath;
  ReferenceBackground _referenceBackground = const ReferenceBackground.white();
  List<FrameLineConfig> _frameLines = FrameLineConfig.defaults();
  FltSettingsTab _fltSettingsTab = FltSettingsTab.frameLineA;
  LensIlluminationGuideConfig _lensGuide = const LensIlluminationGuideConfig();
  FrameLeaderConfig _frameLeader = const FrameLeaderConfig();
  String _recordingCodec = 'Apple ProRes';
  String _recordingProfileId = 'full';
  LukaCompatReport? _cameraLuka;
  LukaCompatReport? _lensLuka;

  @override
  void initState() {
    super.initState();
    _aspect = OpticsCalculator.parseAspectRatio(widget.initialAspectRatio);
    _tStop = double.tryParse(widget.initialTStop ?? '') ?? 2.8;
    _referenceImagePath = widget.initialReferenceImagePath;
    if (_referenceImagePath != null) {
      _referenceBackground = ReferenceBackground.image(_referenceImagePath);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDefaults());
  }

  Future<void> _loadDefaults() async {
    final db = ref.read(databaseProvider);
    final bible = await db.getVisualBibleForProject(widget.projectId);
    final camId = widget.initialCameraId ?? bible?.primaryCameraId;
    final lensId = widget.initialLensId ?? bible?.primaryLensId;

    if (camId != null) {
      _camera = await db.getCameraById(camId);
      _applyCameraModes(_camera);
    } else {
      final cam = await db.resolveProjectCamera(widget.projectId);
      if (cam != null) {
        _camera = cam;
        _applyCameraModes(cam);
      }
    }

    if (lensId != null) {
      _lens = await db.getLensById(lensId);
    } else {
      _lens = await db.resolveProjectLens(widget.projectId);
    }
    if (_lens != null) {
      _applyLensFocal(_lens);
      _anamorphicPreview = _lens?.isAnamorphic ?? false;
      _lensSqueeze =
          _lens?.squeezeRatio ?? (_lens?.isAnamorphic == true ? 2.0 : 1.0);
    }

    if (bible?.aspectRatio != null) {
      _aspect = OpticsCalculator.parseAspectRatio(bible!.aspectRatio);
    }
    if (bible?.defaultTStop != null) {
      _tStop = double.tryParse(bible!.defaultTStop!) ?? _tStop;
    }

    if (_referenceImagePath == null) {
      final samples =
          await db.watchOpticsLabSamples(widget.projectId).first;
      if (samples.isNotEmpty) {
        _referenceImagePath = samples.first.imagePath;
        _referenceBackground =
            ReferenceBackground.image(_referenceImagePath!);
      }
    }

    await _refreshLukaReports();
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _refreshLukaReports() async {
    final svc = await LukaCompatibilityService.create(
      LukaManifestService(ref.read(databaseProvider)),
    );
    if (_camera != null) _cameraLuka = svc.evaluateCamera(_camera!);
    if (_lens != null) _lensLuka = svc.evaluateLens(_lens!, camera: _camera);
  }

  void _applyCameraModes(Camera? cam) {
    if (cam == null) return;
    final modes = _parseModes(cam.sensorModesJson);
    if (modes.isNotEmpty) {
      _mode = modes.first;
    } else {
      _mode = SensorModeSpec(
        name: 'Open Gate',
        widthMm: cam.sensorWidthMm,
        heightMm: cam.sensorHeightMm,
      );
    }
    _recordingCodec = SensorModeContext.defaultCodecForCamera(cam);
    _recordingProfileId = 'full';
  }

  List<RecordingProfileOption> get _recordingProfiles {
    final ctx = _sensorContext;
    if (ctx == null) return const [];
    return ctx.recordingProfiles(codec: _recordingCodec);
  }

  RecordingProfileOption? get _selectedRecordingProfile {
    final profiles = _recordingProfiles;
    if (profiles.isEmpty) return null;
    return profiles.where((p) => p.id == _recordingProfileId).firstOrNull ?? profiles.first;
  }

  ComputedFrameLine? get _activeComputedFrameLine {
    final idx = switch (_fltSettingsTab) {
      FltSettingsTab.frameLineA => 0,
      FltSettingsTab.frameLineB => 1,
      FltSettingsTab.frameLineC => 2,
      _ => 0,
    };
    final id = _frameLines[idx.clamp(0, _frameLines.length - 1)].id;
    return _frameLineLayout.frameLines.where((f) => f.config.id == id).firstOrNull;
  }

  void _applyLensFocal(Lense? lens) {
    if (lens == null) return;
    if (lens.focalLength > 0) {
      _focalMm = lens.focalLength;
    } else if (lens.focalMin != null) {
      _focalMm = lens.focalMin!;
    }
  }

  (double min, double max) get _focalRange {
    final lens = _lens;
    if (lens != null && lens.focalMin != null && lens.focalMax != null) {
      return (lens.focalMin!, lens.focalMax!);
    }
    return (8, 300);
  }

  List<SensorModeSpec> _parseModes(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((e) => SensorModeSpec.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  double get _deliveryAspect {
    final primary = _frameLines.firstWhere(
      (f) => f.id == 'A',
      orElse: () => _frameLines.first,
    );
    return primary.effectiveAspectRatio ?? _aspect;
  }

  SensorModeContext? get _sensorContext {
    final cam = _camera;
    if (cam == null) return null;
    return SensorModeContext.fromCamera(cam, _mode);
  }

  OpticsResult get _result {
    final lens = _lens;
    final ctx = _sensorContext;
    final format = lens?.formatCoverage ?? 'S35';
    final fullDiag = math.sqrt(
      _mode.widthMm * _mode.widthMm + _mode.heightMm * _mode.heightMm,
    );
    final imageCircle = lens?.imageCircleMm ??
        math.max(
          fullDiag * 1.02,
          OpticsCalculator.imageCircleForFormat(format),
        );
    final previewDesqueeze =
        _anamorphicPreview && (_lens?.isAnamorphic == true || _lensSqueeze > 1.0)
            ? _lensSqueeze
            : 1.0;
    int? recW;
    int? recH;
    final profile = _selectedRecordingProfile;
    if (profile != null) {
      recW = profile.widthPx;
      recH = profile.heightPx;
    } else if (ctx != null) {
      final rp = ctx.recordingPixels;
      recW = rp.$1;
      recH = rp.$2;
    }
    return OpticsCalculator.computeFromMode(
      mode: SensorModeSpec(
        name: _mode.name,
        widthMm: _mode.widthMm,
        heightMm: _mode.heightMm,
        cropFactor: _mode.cropFactor,
        maxWidthPx: _mode.maxWidthPx,
        maxHeightPx: _mode.maxHeightPx,
        anamorphicDesqueeze: previewDesqueeze,
        offsetXMm: _mode.offsetXMm,
        offsetYMm: _mode.offsetYMm,
      ),
      focalMm: _focalMm,
      imageCircleMm: imageCircle,
      formatCoverage: format,
      aspectRatio: _deliveryAspect,
      tStop: _tStop,
      subjectDistanceM: _subjectM,
      isAnamorphic: (_lens?.isAnamorphic ?? false) || _lensSqueeze > 1.0,
      squeezeRatio: _lensSqueeze,
      cameraMount: _camera?.mountType,
      lensMount: lens?.mountType,
      fullSensorWidthMm: ctx?.fullWidthMm,
      fullSensorHeightMm: ctx?.fullHeightMm,
      recordingWidthPx: recW,
      recordingHeightPx: recH,
      cropWidthPercent: ctx?.cropWidthPercent,
      cropHeightPercent: ctx?.cropHeightPercent,
    );
  }

  FrameLineLayout get _frameLineLayout {
    final previewDesqueeze =
        _anamorphicPreview && (_lens?.isAnamorphic == true || _lensSqueeze > 1.0)
            ? _lensSqueeze
            : 1.0;
    final ctx = _sensorContext ??
        SensorModeContext(
          fullWidthMm: _mode.widthMm,
          fullHeightMm: _mode.heightMm,
          mode: _mode,
        );
    return FrameLineGeometry.compute(
      context: ctx,
      optics: _result,
      frameLines: _frameLines,
      referenceFocalMm: 50,
      previewDesqueeze: previewDesqueeze,
      recordingWidthPx: _selectedRecordingProfile?.widthPx,
      recordingHeightPx: _selectedRecordingProfile?.heightPx,
    );
  }

  Future<void> _exportPng() async {
    final boundary =
        _captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return;
    final path = await MediaStorage.writeProjectFileBytes(
      projectId: widget.projectId,
      subfolder: 'optics_lab',
      bytes: bytes.buffer.asUint8List(),
      fileName: 'flt_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Captura guardada: $path')),
    );
  }

  Future<void> _saveToBible() async {
    final db = ref.read(databaseProvider);
    final snapshot = {
      'cameraId': _camera?.id,
      'lensId': _lens?.id,
      'sensorMode': _mode.name,
      'focalMm': _focalMm,
      'tStop': _tStop,
      'aspectRatio': _deliveryAspect,
      'frameLines': _frameLines.map((f) => {
            'id': f.id,
            'aspect': f.effectiveAspectRatio,
            'show': f.showFrameLine,
            'scaling': f.scalingPercent,
          }).toList(),
      'subjectDistanceM': _subjectM,
      'hFov': _result.hFovDeg,
      'dFov': _result.dFovDeg,
      'hyperfocalM': _result.hyperfocalM,
      'resolution': _result.resolutionLabel,
      'coverage': _result.coverageLabel,
      if (_referenceImagePath != null) 'referenceImagePath': _referenceImagePath,
    };
    await db.saveOpticsConfigToBible(
      projectId: widget.projectId,
      cameraId: _camera?.id,
      lensId: _lens?.id,
      tStop: _tStop.toStringAsFixed(1),
      configJson: jsonEncode(snapshot),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuración guardada en la Biblia')),
      );
    }
  }

  Widget _lukaBanner(AppPalette palette) {
    final warnings = <String>[];
    if (_cameraLuka != null && _cameraLuka!.level != LukaCompatLevel.full) {
      warnings.addAll(_cameraLuka!.messages);
    }
    if (_lensLuka != null && _lensLuka!.level != LukaCompatLevel.full) {
      warnings.addAll(_lensLuka!.messages);
    }
    if (warnings.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      color: Colors.amber.withValues(alpha: 0.15),
      child: Text(
        'LUKA: ${warnings.join(' · ')}',
        style: AppTypography.caption(palette),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);
    final result = _result;

    if (!_loaded) {
      if (widget.embedded) {
        return const Center(child: CircularProgressIndicator());
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Laboratorio óptico')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final body = Column(
      children: [
        _lukaBanner(palette),
        if (widget.embedded) _embeddedToolbar(palette),
        Expanded(child: _mainWorkspace(palette, db, result)),
        _statusFooter(palette, result),
      ],
    );

    if (widget.embedded) return body;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: palette.surface,
        title: Text('Laboratorio óptico (FLT)', style: AppTypography.titleMedium(palette)),
        actions: [
          IconButton(
            tooltip: 'Exportar PNG',
            icon: const Icon(Icons.image_outlined),
            onPressed: _exportPng,
          ),
          if (widget.showSaveToBible)
            TextButton(
              onPressed: _saveToBible,
              child: const Text('Guardar en Biblia'),
            ),
        ],
      ),
      body: body,
    );
  }

  Widget _embeddedToolbar(AppPalette palette) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      color: palette.surfaceElevated,
      child: Row(
        children: [
          Text('FLT', style: AppTypography.titleMedium(palette)),
          const Spacer(),
          IconButton(
            tooltip: 'Exportar PNG',
            icon: const Icon(Icons.image_outlined),
            onPressed: _exportPng,
          ),
          if (widget.showSaveToBible)
            TextButton(
              onPressed: _saveToBible,
              child: const Text('Guardar en Biblia'),
            ),
        ],
      ),
    );
  }

  Widget _mainWorkspace(AppPalette palette, AppDatabase db, OpticsResult result) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 960;
        final settings = _settingsPanel(palette, db);
        final coverage = _coveragePanel(palette, result);
        final preview = _previewPanel(db, result);

        if (narrow) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                settings,
                const SizedBox(height: AppSpacing.md),
                SizedBox(height: 220, child: coverage),
                const SizedBox(height: AppSpacing.md),
                SizedBox(height: 420, child: preview),
              ],
            ),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              flex: 3,
              child: settings,
            ),
            Flexible(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: coverage,
              ),
            ),
            Flexible(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: preview,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _settingsPanel(AppPalette palette, AppDatabase db) {
    final (focalMin, focalMax) = _focalRange;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        ProjectCameraRosterBar(
          db: db,
          projectId: widget.projectId,
          activeCameraId: _camera?.id,
          palette: palette,
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Camera Settings', style: AppTypography.titleMedium(palette)),
        const SizedBox(height: AppSpacing.sm),
        StreamBuilder<List<Camera>>(
          stream: db.watchAllCameras(),
          builder: (context, snap) {
            final cameras = snap.data ?? [];
            return DropdownButtonFormField<int>(
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Cámara'),
              initialValue: _camera?.id,
              items: cameras
                  .map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text('${c.brand} ${c.model}',
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (id) async {
                final cam = cameras.where((c) => c.id == id).firstOrNull;
                setState(() {
                  _camera = cam;
                  _applyCameraModes(cam);
                });
                await _refreshLukaReports();
                if (mounted) setState(() {});
              },
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String>(
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Modo sensor'),
          initialValue: _mode.name,
          items: (_camera != null
                  ? _parseModes(_camera!.sensorModesJson)
                  : [_mode])
              .map((m) {
                final ctx = _camera != null
                    ? SensorModeContext.fromCamera(_camera!, m)
                    : null;
                final label = ctx != null
                    ? '${m.name} · ${ctx.recordingLabel} · ${ctx.cropLabel}'
                    : m.name;
                return DropdownMenuItem(value: m.name, child: Text(label, overflow: TextOverflow.ellipsis));
              })
              .toList(),
          onChanged: (name) {
            final modes = _parseModes(_camera?.sensorModesJson);
            final m = modes.where((x) => x.name == name).firstOrNull;
            if (m != null) {
              setState(() {
                _mode = m;
                _recordingProfileId = 'full';
              });
            }
          },
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String>(
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Recording Resolution'),
          initialValue: _recordingProfiles.any((p) => p.id == _recordingProfileId)
              ? _recordingProfileId
              : _recordingProfiles.firstOrNull?.id,
          items: _recordingProfiles
              .map((p) => DropdownMenuItem(
                    value: p.id,
                    child: Text('${p.label} · ${p.codec}', overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: _recordingProfiles.isEmpty
              ? null
              : (id) {
                  if (id != null) setState(() => _recordingProfileId = id);
                },
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String>(
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Recording Codec'),
          initialValue: SensorModeContext.kRecordingCodecs.contains(_recordingCodec)
              ? _recordingCodec
              : SensorModeContext.kRecordingCodecs.first,
          items: SensorModeContext.kRecordingCodecs
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _recordingCodec = v);
          },
        ),
        const SizedBox(height: AppSpacing.md),
        StreamBuilder<List<Lense>>(
          stream: db.watchAllLenses(),
          builder: (context, snap) {
            final lenses = snap.data ?? [];
            return DropdownButtonFormField<int>(
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Óptica'),
              initialValue: _lens?.id,
              items: lenses
                  .map((l) => DropdownMenuItem(
                        value: l.id,
                        child: Text('${l.brand} ${l.model}',
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (id) async {
                final lens = lenses.where((l) => l.id == id).firstOrNull;
                setState(() {
                  _lens = lens;
                  _applyLensFocal(lens);
                  _anamorphicPreview = lens?.isAnamorphic ?? false;
                  _lensSqueeze =
                      lens?.squeezeRatio ?? (_lens?.isAnamorphic == true ? 2.0 : 1.0);
                });
                await _refreshLukaReports();
                if (mounted) setState(() {});
              },
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Focal: ${_focalMm.toStringAsFixed(0)} mm',
            style: AppTypography.caption(palette)),
        Slider(
          value: _focalMm.clamp(focalMin, focalMax),
          min: focalMin,
          max: focalMax,
          divisions: (focalMax - focalMin).round().clamp(1, 300),
          onChanged: (v) => setState(() => _focalMm = v),
        ),
        Text('T-stop: T${_tStop.toStringAsFixed(1)}',
            style: AppTypography.caption(palette)),
        Slider(
          value: _tStop.clamp(1.0, 22),
          min: 1,
          max: 22,
          divisions: 42,
          onChanged: (v) => setState(() => _tStop = v),
        ),
        DropdownButtonFormField<double>(
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Lens Squeeze'),
          initialValue: _lensSqueeze,
          items: const [
            DropdownMenuItem(value: 1.0, child: Text('1.0 (esférico)')),
            DropdownMenuItem(value: 1.3, child: Text('1.3x')),
            DropdownMenuItem(value: 1.5, child: Text('1.5x')),
            DropdownMenuItem(value: 2.0, child: Text('2.0x anamórfico')),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _lensSqueeze = v);
          },
        ),
        if (_lens?.isAnamorphic == true)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Desqueeze preview'),
            value: _anamorphicPreview,
            onChanged: (v) => setState(() => _anamorphicPreview = v),
          ),
        Text('Distancia sujeto: ${_subjectM.toStringAsFixed(1)} m',
            style: AppTypography.caption(palette)),
        Slider(
          value: _subjectM.clamp(0.3, 20),
          min: 0.3,
          max: 20,
          onChanged: (v) => setState(() => _subjectM = v),
        ),
        const Divider(height: AppSpacing.xl),
        FrameLineSettingsPanel(
          configs: _frameLines,
          activeTab: _fltSettingsTab,
          onTabChanged: (tab) => setState(() => _fltSettingsTab = tab),
          activeComputed: _activeComputedFrameLine,
          lensGuide: _lensGuide,
          onLensGuideChanged: (g) => setState(() => _lensGuide = g),
          frameLeader: _frameLeader,
          onFrameLeaderChanged: (l) => setState(() => _frameLeader = l),
          onConfigChanged: (cfg) {
            setState(() {
              _frameLines =
                  _frameLines.map((f) => f.id == cfg.id ? cfg : f).toList();
            });
          },
        ),
      ],
    );
  }

  Widget _coveragePanel(AppPalette palette, OpticsResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Lens Illumination', style: AppTypography.caption(palette)),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: AppCard(
            padding: EdgeInsets.zero,
            child: CustomPaint(
              painter: SensorCoveragePainter(
                result: result,
                context: _sensorContext,
                sensorModeName: _mode.name,
                tStop: _tStop,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _previewPanel(AppDatabase db, OpticsResult result) {
    return StreamBuilder<List<OpticsLabSample>>(
      stream: db.watchOpticsLabSamples(widget.projectId),
      builder: (context, sampleSnap) {
        final samples = sampleSnap.data ?? [];
        final samplePaths = samples.map((s) => s.imagePath).toList();

        return FltFrameLinePreview(
          repaintKey: _captureKey,
          layout: _frameLineLayout,
          optics: result,
          mode: _mode,
          desqueezePreview:
              _anamorphicPreview && (_lens?.isAnamorphic == true || _lensSqueeze > 1.0),
          squeezeRatio: _lensSqueeze,
          lensGuide: _lensGuide,
          frameLeader: _frameLeader,
          background: _referenceBackground,
          samplePaths: samplePaths,
          onBackgroundChanged: (bg) {
            setState(() {
              _referenceBackground = bg;
              if (bg.kind == ReferenceBackgroundKind.image) {
                _referenceImagePath = bg.imagePath;
              }
            });
          },
          onAddSample: () async {
            final path = await pickAndStoreOpticsLabSample(
              db: ref.read(databaseProvider),
              projectId: widget.projectId,
              context: context,
            );
            if (!mounted || path == null) return;
            setState(() {
              _referenceImagePath = path;
              _referenceBackground = ReferenceBackground.image(path);
            });
          },
          onDeleteSample: (path) async {
            final sample = samples.where((s) => s.imagePath == path).firstOrNull;
            if (sample == null) return;
            await deleteOpticsLabSample(
              db: ref.read(databaseProvider),
              sampleId: sample.id,
            );
            if (!mounted) return;
            if (_referenceImagePath == path) {
              setState(() {
                _referenceImagePath = null;
                _referenceBackground = const ReferenceBackground.white();
              });
            }
          },
        );
      },
    );
  }

  Widget _statusFooter(AppPalette palette, OpticsResult result) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      color: palette.surfaceElevated,
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        children: [
          Text('HFOV ${result.hFovDeg.toStringAsFixed(1)}°'),
          Text('VFOV ${result.vFovDeg.toStringAsFixed(1)}°'),
          Text('DFOV ${result.dFovDeg.toStringAsFixed(1)}°'),
          Text('Focal eff. ${result.focalEffectiveMm.toStringAsFixed(1)} mm'),
          if (result.hyperfocalM != null)
            Text('Hiperfocal ${result.hyperfocalM!.toStringAsFixed(2)} m'),
                if (result.recordingResolutionLabel != null)
                  Text('Rec. ${result.recordingResolutionLabel}'),
                if (result.cropWidthPercent != null)
                  Text(
                    'Crop ${result.cropWidthPercent!.toStringAsFixed(0)}×'
                    '${result.cropHeightPercent!.toStringAsFixed(0)}%',
                  ),
          Text(
            'Cobertura: ${result.coverageLabel}',
            style: TextStyle(
              color: result.portholingWarning
                  ? Colors.orange
                  : result.coversSensor
                      ? Colors.green
                      : Colors.red,
            ),
          ),
          if (result.mountWarning != null)
            Text(result.mountWarning!, style: const TextStyle(color: Colors.amber)),
          Text(
            'Aproximación FLT — no sustituye Artemis on-set.',
            style: AppTypography.caption(palette),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
