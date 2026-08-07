import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../moodboard_annotation_store.dart';
import '../moodboard_palette_extractor.dart';
import '../moodboard_reference_meta.dart';
import '../visual_bible_model.dart';
import 'moodboard_annotation_painter.dart';

enum _LightboxTool { none, draw, arrow, text }

/// Lightbox unificado: frame + meta + comentarios + anotación in-place.
class MoodboardLightbox extends ConsumerStatefulWidget {
  final List<MoodboardImageModel> images;
  final int initialIndex;
  final Map<int, MoodboardReferenceMeta> metaById;
  final int? bibleId;
  final int? projectId;
  final VoidCallback onClose;
  final Future<void> Function(MoodboardImageModel image) onAddToProject;
  final void Function(int imageId, MoodboardReferenceMeta meta)? onMetaSaved;

  const MoodboardLightbox({
    super.key,
    required this.images,
    required this.initialIndex,
    required this.metaById,
    this.bibleId,
    this.projectId,
    required this.onClose,
    required this.onAddToProject,
    this.onMetaSaved,
  });

  static Future<void> show({
    required BuildContext context,
    required List<MoodboardImageModel> images,
    required int initialIndex,
    required Map<int, MoodboardReferenceMeta> metaById,
    int? bibleId,
    int? projectId,
    required Future<void> Function(MoodboardImageModel image) onAddToProject,
    void Function(int imageId, MoodboardReferenceMeta meta)? onMetaSaved,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar lightbox',
      barrierColor: Colors.black.withValues(alpha: 0.72),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim, secondary) {
        return MoodboardLightbox(
          images: images,
          initialIndex: initialIndex,
          metaById: metaById,
          bibleId: bibleId,
          projectId: projectId ??
              (images.isNotEmpty ? images.first.projectId : null),
          onClose: () => Navigator.of(ctx).pop(),
          onAddToProject: onAddToProject,
          onMetaSaved: onMetaSaved,
        );
      },
      transitionBuilder: (ctx, anim, secondary, child) {
        return FadeTransition(opacity: anim, child: child);
      },
    );
  }

  @override
  ConsumerState<MoodboardLightbox> createState() => _MoodboardLightboxState();
}

class _MoodboardLightboxState extends ConsumerState<MoodboardLightbox> {
  late int _index;
  late final FocusNode _focus;
  late Map<int, MoodboardReferenceMeta> _metaById;
  List<Color> _palette = const [];
  bool _extracting = false;
  bool _annotateMode = false;
  _LightboxTool _tool = _LightboxTool.draw;
  Color _drawColor = const Color(0xFF2997FF);
  final List<MoodboardStroke> _strokes = [];
  List<Offset> _livePoints = [];
  Offset? _arrowStart;
  Offset? _arrowEnd;
  bool _strokesLoading = false;

  final _commentCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _directorCtrl = TextEditingController();
  final _dopCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  final _cameraCtrl = TextEditingController();
  final _lensesCtrl = TextEditingController();
  final _aspectCtrl = TextEditingController();

  String? _lightingLook;
  String? _lightSource;
  String? _lightTexture;
  String? _composition;
  String? _locationKind;
  String? _locationName;
  String? _timeOfDay;
  String? _colorMood;
  bool _pendingReview = false;

  List<LocationBasePlan> _projectLocations = const [];
  List<String> _intExtOptions = List.of(kMoodboardIntExt);
  List<String> _timeOptions = List.of(kMoodboardTimesOfDay);

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.images.length - 1);
    _metaById = Map.of(widget.metaById);
    _focus = FocusNode();
    _bindMetaControllers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
      _ensurePalette();
      _loadStrokes();
      _loadCatalogContext();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    _commentCtrl.dispose();
    _titleCtrl.dispose();
    _yearCtrl.dispose();
    _directorCtrl.dispose();
    _dopCtrl.dispose();
    _notesCtrl.dispose();
    _tagsCtrl.dispose();
    _cameraCtrl.dispose();
    _lensesCtrl.dispose();
    _aspectCtrl.dispose();
    super.dispose();
  }

  MoodboardImageModel get _image => widget.images[_index];

  MoodboardReferenceMeta get _meta =>
      _metaById[_image.id] ?? const MoodboardReferenceMeta();

  void _bindMetaControllers() {
    final m = _meta;
    _titleCtrl.text = m.title ?? _image.filmReference ?? '';
    _yearCtrl.text = m.year ?? '';
    _directorCtrl.text = m.director ?? '';
    _dopCtrl.text = m.dop ?? '';
    _notesCtrl.text = m.technicalNotes ?? _image.caption ?? '';
    _tagsCtrl.text = m.tags.join(', ');
    _cameraCtrl.text = m.camera ?? '';
    _lensesCtrl.text = m.lenses ?? '';
    _aspectCtrl.text = m.aspectRatio ?? '';
    _lightingLook = m.lightingLook;
    _lightSource = m.lightSource;
    _lightTexture = m.lightTexture;
    _composition = m.composition;
    _locationKind = _normalizeIntExt(m.locationKind);
    _locationName = m.locationName ?? _image.linkedLocationName;
    _timeOfDay = _normalizeTimeOfDay(m.timeOfDay);
    _colorMood = m.colorMood;
    _pendingReview = m.pendingReview;
    _palette = m.paletteHex
        .map(MoodboardPaletteExtractor.fromHex)
        .whereType<Color>()
        .toList();
  }

  static String? _normalizeIntExt(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final u = raw.trim().toUpperCase().replaceAll('.', '');
    if (u.contains('INT') && u.contains('EXT')) return 'INT/EXT';
    if (u.startsWith('INT') || u == 'INTERIOR') return 'INT';
    if (u.startsWith('EXT') || u == 'EXTERIOR') return 'EXT';
    return raw.trim().toUpperCase();
  }

  static String? _normalizeTimeOfDay(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final u = raw.trim().toUpperCase();
    if (u.contains('AZUL') || u.contains('BLUE')) return 'HORA AZUL';
    if (u.contains('AMANEC') || u.contains('DAWN')) return 'AMANECER';
    if (u.contains('ATARD') || u.contains('DUSK') || u.contains('GOLDEN')) {
      return 'ATARDECER';
    }
    if (u.contains('NOCH') || u.contains('NIGHT')) return 'NOCHE';
    if (u.contains('DÍA') || u.contains('DIA') || u == 'DAY') return 'DÍA';
    return u;
  }

  Future<void> _loadCatalogContext() async {
    final projectId = widget.projectId ?? _image.projectId;
    final db = ref.read(databaseProvider);
    final locs = await db.watchLocationsForProject(projectId).first;
    final scenes = await db.watchScenesForProject(projectId).first;
    if (!mounted) return;

    final intExt = <String>{...kMoodboardIntExt};
    final times = <String>{...kMoodboardTimesOfDay};
    for (final s in scenes) {
      final ie = _normalizeIntExt(s.intExt);
      if (ie != null) intExt.add(ie);
      final t = _normalizeTimeOfDay(s.dayNight);
      if (t != null) times.add(t);
    }

    setState(() {
      _projectLocations = locs;
      _intExtOptions = intExt.toList();
      _timeOptions = times.toList();
    });
  }

  Future<void> _loadStrokes() async {
    setState(() => _strokesLoading = true);
    final strokes = await MoodboardAnnotationStore.loadStrokes(_image.id);
    if (!mounted) return;
    setState(() {
      _strokes
        ..clear()
        ..addAll(strokes);
      _livePoints = [];
      _arrowStart = null;
      _arrowEnd = null;
      _strokesLoading = false;
    });
  }

  Future<void> _persistStrokes() async {
    await MoodboardAnnotationStore.saveStrokes(_image.id, _strokes);
  }

  Future<void> _ensurePalette({bool force = false}) async {
    if (!force && _palette.isNotEmpty) return;
    setState(() => _extracting = true);
    final colors = await MoodboardPaletteExtractor.fromFile(
      _image.imagePath,
      count: MoodboardPaletteExtractor.defaultSwatches,
    );
    if (!mounted) return;
    setState(() {
      _palette = colors;
      _extracting = false;
    });
    if (colors.isEmpty) {
      if (force && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo extraer la paleta de esta imagen'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    final next = MoodboardReferenceMeta(
      title: _meta.title,
      year: _meta.year,
      director: _meta.director,
      dop: _meta.dop,
      aspectRatio: _meta.aspectRatio,
      camera: _meta.camera,
      lenses: _meta.lenses,
      technicalNotes: _meta.technicalNotes,
      tags: _meta.tags,
      lightingLook: _meta.lightingLook,
      lightSource: _meta.lightSource,
      lightTexture: _meta.lightTexture,
      composition: _meta.composition,
      locationKind: _meta.locationKind,
      locationName: _meta.locationName,
      timeOfDay: _meta.timeOfDay,
      colorMood: _meta.colorMood,
      pendingReview: _meta.pendingReview,
      paletteHex: colors.map(MoodboardPaletteExtractor.toHex).toList(),
    );
    await MoodboardReferenceMetaStore.save(_image.id, next);
    _metaById[_image.id] = next;
    widget.onMetaSaved?.call(_image.id, next);
  }

  Future<void> _goTo(int nextIndex) async {
    await _saveMetaSilent();
    await _persistStrokes();
    setState(() {
      _index = nextIndex;
      _annotateMode = false;
      _tool = _LightboxTool.draw;
      _bindMetaControllers();
    });
    _ensurePalette();
    _loadStrokes();
  }

  void _prev() {
    if (_index <= 0) return;
    _goTo(_index - 1);
  }

  void _next() {
    if (_index >= widget.images.length - 1) return;
    _goTo(_index + 1);
  }

  Future<void> _saveMetaSilent() async {
    final tags = _tagsCtrl.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final next = MoodboardReferenceMeta(
      title: _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
      year: _yearCtrl.text.trim().isEmpty ? null : _yearCtrl.text.trim(),
      director:
          _directorCtrl.text.trim().isEmpty ? null : _directorCtrl.text.trim(),
      dop: _dopCtrl.text.trim().isEmpty ? null : _dopCtrl.text.trim(),
      technicalNotes:
          _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      camera: _cameraCtrl.text.trim().isEmpty ? null : _cameraCtrl.text.trim(),
      lenses: _lensesCtrl.text.trim().isEmpty ? null : _lensesCtrl.text.trim(),
      aspectRatio:
          _aspectCtrl.text.trim().isEmpty ? null : _aspectCtrl.text.trim(),
      tags: tags,
      paletteHex: _palette.map(MoodboardPaletteExtractor.toHex).toList(),
      lightingLook: _lightingLook,
      lightSource: _lightSource,
      lightTexture: _lightTexture,
      composition: _composition,
      locationKind: _locationKind,
      locationName: _locationName,
      timeOfDay: _timeOfDay,
      colorMood: _colorMood,
      pendingReview: _pendingReview,
    );
    await MoodboardReferenceMetaStore.save(_image.id, next);
    _metaById[_image.id] = next;
    widget.onMetaSaved?.call(_image.id, next);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_annotateMode) {
        setState(() => _annotateMode = false);
        return KeyEventResult.handled;
      }
      _saveMetaSilent();
      _persistStrokes();
      widget.onClose();
      return KeyEventResult.handled;
    }
    if (_annotateMode) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _prev();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _next();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _share() async {
    final file = XFile(_image.imagePath);
    final title = _titleCtrl.text.trim().isEmpty
        ? 'Referencia IRIS'
        : _titleCtrl.text.trim();
    await Share.shareXFiles([file], text: title);
  }

  Future<void> _postComment() async {
    final bibleId = widget.bibleId;
    final text = _commentCtrl.text.trim();
    if (bibleId == null || bibleId <= 0 || text.isEmpty) return;
    final db = ref.read(databaseProvider);
    await db.insertBibleComment(
      BibleCommentsCompanion.insert(
        bibleId: bibleId,
        authorRole: 'dp',
        targetType: 'moodboard',
        targetId: Value(_image.id),
        comment: text,
      ),
    );
    _commentCtrl.clear();
  }

  void _undoStroke() {
    if (_strokes.isEmpty) return;
    setState(() => _strokes.removeLast());
    _persistStrokes();
  }

  void _onPanStart(Offset local, Size size) {
    if (!_annotateMode ||
        _tool == _LightboxTool.none ||
        _tool == _LightboxTool.text) {
      return;
    }
    final n = Offset(local.dx / size.width, local.dy / size.height);
    setState(() {
      if (_tool == _LightboxTool.draw) {
        _livePoints = [n];
      } else if (_tool == _LightboxTool.arrow) {
        _arrowStart = n;
        _arrowEnd = n;
      }
    });
  }

  void _onPanUpdate(Offset local, Size size) {
    final n = Offset(
      (local.dx / size.width).clamp(0.0, 1.0),
      (local.dy / size.height).clamp(0.0, 1.0),
    );
    setState(() {
      if (_tool == _LightboxTool.draw) {
        _livePoints = [..._livePoints, n];
      } else if (_tool == _LightboxTool.arrow) {
        _arrowEnd = n;
      }
    });
  }

  void _onPanEnd() {
    if (_tool == _LightboxTool.draw && _livePoints.length >= 2) {
      _strokes.add(
        MoodboardStroke(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          color: _drawColor,
          width: 3,
          points: List.of(_livePoints),
        ),
      );
      _livePoints = [];
      _persistStrokes();
    } else if (_tool == _LightboxTool.arrow &&
        _arrowStart != null &&
        _arrowEnd != null) {
      _strokes.add(
        MoodboardStroke(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          color: _drawColor,
          width: 4,
          points: [_arrowStart!, _arrowEnd!],
          label: 'ARROW',
        ),
      );
      _arrowStart = null;
      _arrowEnd = null;
      _persistStrokes();
    } else {
      setState(() {
        _livePoints = [];
        _arrowStart = null;
        _arrowEnd = null;
      });
    }
    setState(() {});
  }

  Future<void> _addTextLabel(Size size, Offset local) async {
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('Etiqueta'),
          content: TextField(
            controller: c,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'KEY LIGHT…'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('Añadir'),
            ),
          ],
        );
      },
    );
    if (text == null || text.isEmpty) return;
    final n = Offset(local.dx / size.width, local.dy / size.height);
    setState(() {
      _strokes.add(
        MoodboardStroke(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          color: _drawColor,
          width: 2,
          points: [n],
          label: text,
        ),
      );
    });
    await _persistStrokes();
  }

  Future<void> _linkLocation({
    String? name,
    int? planId,
  }) async {
    setState(() {
      _locationName = name;
    });
    await _saveMetaSilent();
    final db = ref.read(databaseProvider);
    final row = await (db.select(db.moodboardImages)
          ..where((t) => t.id.equals(_image.id)))
        .getSingle();
    await db.updateMoodboardImage(
      row.copyWith(
        linkedLocationName: Value(name),
        linkedLocationBasePlanId: Value(planId),
      ),
    );
    _image.linkedLocationName = name;
    _image.linkedLocationBasePlanId = planId;
  }

  Future<void> _addProjectLocation() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva localización'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Nombre del set / lugar',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    final projectId = widget.projectId ?? _image.projectId;
    final db = ref.read(databaseProvider);
    final created = await db.createLocationWithDefaultSet(projectId, name);
    await _loadCatalogContext();
    await _linkLocation(name: created.set.locationName, planId: created.set.id);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final stage = _Stage(
      image: _image,
      palette: _palette,
      extracting: _extracting,
      canPrev: _index > 0 && !_annotateMode,
      canNext: _index < widget.images.length - 1 && !_annotateMode,
      onPrev: _prev,
      onNext: _next,
      onReextract: () => _ensurePalette(force: true),
      annotateMode: _annotateMode,
      strokesLoading: _strokesLoading,
      strokes: [
        ..._strokes,
        if (_livePoints.length >= 2)
          MoodboardStroke(
            id: 'live',
            color: _drawColor,
            width: 3,
            points: _livePoints,
          ),
        if (_arrowStart != null && _arrowEnd != null)
          MoodboardStroke(
            id: 'live-arrow',
            color: _drawColor,
            width: 4,
            points: [_arrowStart!, _arrowEnd!],
            label: 'ARROW',
          ),
      ],
      tool: _tool,
      drawColor: _drawColor,
      onTool: (t) => setState(() {
        _tool = t;
        _drawColor = t == _LightboxTool.text
            ? const Color(0xFFFF3B30)
            : const Color(0xFF2997FF);
      }),
      onUndo: _undoStroke,
      onExitAnnotate: () => setState(() => _annotateMode = false),
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onTapForText: _addTextLabel,
    );

    final side = _SidePanel(
      image: _image,
      titleCtrl: _titleCtrl,
      yearCtrl: _yearCtrl,
      directorCtrl: _directorCtrl,
      dopCtrl: _dopCtrl,
      notesCtrl: _notesCtrl,
      tagsCtrl: _tagsCtrl,
      cameraCtrl: _cameraCtrl,
      lensesCtrl: _lensesCtrl,
      aspectCtrl: _aspectCtrl,
      commentCtrl: _commentCtrl,
      lightingLook: _lightingLook,
      lightSource: _lightSource,
      lightTexture: _lightTexture,
      composition: _composition,
      locationKind: _locationKind,
      locationName: _locationName,
      timeOfDay: _timeOfDay,
      colorMood: _colorMood,
      pendingReview: _pendingReview,
      intExtOptions: _intExtOptions,
      timeOptions: _timeOptions,
      projectLocations: _projectLocations,
      onLightingLook: (v) {
        setState(() => _lightingLook = v);
        _saveMetaSilent();
      },
      onLightSource: (v) {
        setState(() => _lightSource = v);
        _saveMetaSilent();
      },
      onLightTexture: (v) {
        setState(() => _lightTexture = v);
        _saveMetaSilent();
      },
      onComposition: (v) {
        setState(() => _composition = v);
        _saveMetaSilent();
      },
      onLocationKind: (v) {
        setState(() => _locationKind = v);
        _saveMetaSilent();
      },
      onSelectLocation: (plan) async {
        if (plan == null) {
          await _linkLocation(name: null, planId: null);
        } else {
          await _linkLocation(name: plan.locationName, planId: plan.id);
        }
      },
      onAddLocation: _addProjectLocation,
      onTimeOfDay: (v) {
        setState(() => _timeOfDay = v);
        _saveMetaSilent();
      },
      onColorMood: (v) {
        setState(() => _colorMood = v);
        _saveMetaSilent();
      },
      onPendingReview: (v) {
        setState(() => _pendingReview = v);
        _saveMetaSilent();
      },
      bibleId: widget.bibleId,
      annotateMode: _annotateMode,
      onClose: () async {
        await _saveMetaSilent();
        await _persistStrokes();
        widget.onClose();
      },
      onSave: _saveMetaSilent,
      onAdd: () => widget.onAddToProject(_image),
      onShare: _share,
      onToggleAnnotate: () => setState(() {
        _annotateMode = !_annotateMode;
        if (_annotateMode) _tool = _LightboxTool.draw;
      }),
      onPostComment: _postComment,
    );

    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: Material(
        color: const Color(0xF20E0E10),
        child: wide
            ? Row(
                children: [
                  Expanded(child: stage),
                  SizedBox(width: 380, child: side),
                ],
              )
            : Column(
                children: [
                  Expanded(flex: 5, child: stage),
                  Expanded(flex: 5, child: side),
                ],
              ),
      ),
    );
  }
}

class _Stage extends StatefulWidget {
  final MoodboardImageModel image;
  final List<Color> palette;
  final bool extracting;
  final bool canPrev;
  final bool canNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onReextract;
  final bool annotateMode;
  final bool strokesLoading;
  final List<MoodboardStroke> strokes;
  final _LightboxTool tool;
  final Color drawColor;
  final ValueChanged<_LightboxTool> onTool;
  final VoidCallback onUndo;
  final VoidCallback onExitAnnotate;
  final void Function(Offset local, Size size) onPanStart;
  final void Function(Offset local, Size size) onPanUpdate;
  final VoidCallback onPanEnd;
  final Future<void> Function(Size size, Offset local) onTapForText;

  const _Stage({
    required this.image,
    required this.palette,
    required this.extracting,
    required this.canPrev,
    required this.canNext,
    required this.onPrev,
    required this.onNext,
    required this.onReextract,
    required this.annotateMode,
    required this.strokesLoading,
    required this.strokes,
    required this.tool,
    required this.drawColor,
    required this.onTool,
    required this.onUndo,
    required this.onExitAnnotate,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    required this.onTapForText,
  });

  @override
  State<_Stage> createState() => _StageState();
}

class _StageState extends State<_Stage> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onHorizontalDragEnd: widget.annotateMode
            ? null
            : (d) {
                final v = d.primaryVelocity ?? 0;
                if (v > 200) widget.onPrev();
                if (v < -200) widget.onNext();
              },
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                    child: Center(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final size = Size(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          );
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.file(
                                  File(widget.image.imagePath),
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => ColoredBox(
                                    color: palette.surfaceElevated,
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      color: palette.textTertiary,
                                      size: 48,
                                    ),
                                  ),
                                ),
                                if (!widget.strokesLoading)
                                  CustomPaint(
                                    painter: MoodboardAnnotationPainter(
                                      strokes: widget.strokes,
                                    ),
                                  ),
                                if (widget.annotateMode)
                                  Positioned.fill(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTapUp: widget.tool ==
                                              _LightboxTool.text
                                          ? (d) => widget.onTapForText(
                                                size,
                                                d.localPosition,
                                              )
                                          : null,
                                      onPanStart: widget.tool ==
                                                  _LightboxTool.draw ||
                                              widget.tool ==
                                                  _LightboxTool.arrow
                                          ? (d) => widget.onPanStart(
                                                d.localPosition,
                                                size,
                                              )
                                          : null,
                                      onPanUpdate: widget.tool ==
                                                  _LightboxTool.draw ||
                                              widget.tool ==
                                                  _LightboxTool.arrow
                                          ? (d) => widget.onPanUpdate(
                                                d.localPosition,
                                                size,
                                              )
                                          : null,
                                      onPanEnd: widget.tool ==
                                                  _LightboxTool.draw ||
                                              widget.tool ==
                                                  _LightboxTool.arrow
                                          ? (_) => widget.onPanEnd()
                                          : null,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  if (widget.annotateMode)
                    Positioned(
                      left: 20,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: _AnnotateToolbar(
                          tool: widget.tool,
                          onTool: widget.onTool,
                          onUndo: widget.onUndo,
                          onDone: widget.onExitAnnotate,
                          palette: palette,
                        ),
                      ),
                    ),
                  if (widget.canPrev)
                    Positioned(
                      left: 12,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: AnimatedOpacity(
                          opacity: _hovered ? 1 : 0.4,
                          duration: const Duration(milliseconds: 160),
                          child: _CircleBtn(
                            icon: Icons.chevron_left,
                            onTap: widget.onPrev,
                            palette: palette,
                          ),
                        ),
                      ),
                    ),
                  if (widget.canNext)
                    Positioned(
                      right: 12,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: AnimatedOpacity(
                          opacity: _hovered ? 1 : 0.4,
                          duration: const Duration(milliseconds: 160),
                          child: _CircleBtn(
                            icon: Icons.chevron_right,
                            onTap: widget.onNext,
                            palette: palette,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        'PALETA DEL PLANO',
                        style: AppTypography.mono(palette).copyWith(
                              fontSize: 10,
                              letterSpacing: 1.2,
                              color: palette.textSecondary,
                            ),
                      ),
                      const Spacer(),
                      if (widget.extracting)
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        TextButton(
                          onPressed: widget.onReextract,
                          child: const Text('Re-extraer'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 40,
                    child: widget.palette.isEmpty
                        ? Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.04),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.18),
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.extracting
                                  ? 'Extrayendo paleta…'
                                  : 'Sin paleta · pulsa Re-extraer',
                              style: AppTypography.caption(palette).copyWith(
                                    color: palette.textSecondary,
                                  ),
                            ),
                          )
                        : DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.22),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: Row(
                                children: [
                                  for (var i = 0;
                                      i < widget.palette.length;
                                      i++)
                                    Expanded(
                                      child: ColoredBox(
                                        color: widget.palette[i],
                                        child: i < widget.palette.length - 1
                                            ? Align(
                                                alignment:
                                                    Alignment.centerRight,
                                                child: Container(
                                                  width: 1,
                                                  color: Colors.black
                                                      .withValues(alpha: 0.25),
                                                ),
                                              )
                                            : null,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnnotateToolbar extends StatelessWidget {
  final _LightboxTool tool;
  final ValueChanged<_LightboxTool> onTool;
  final VoidCallback onUndo;
  final VoidCallback onDone;
  final AppPalette palette;

  const _AnnotateToolbar({
    required this.tool,
    required this.onTool,
    required this.onUndo,
    required this.onDone,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xB31A1A1C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToolBtn(
            icon: Icons.draw,
            selected: tool == _LightboxTool.draw,
            onTap: () => onTool(_LightboxTool.draw),
            palette: palette,
          ),
          _ToolBtn(
            icon: Icons.north_east,
            selected: tool == _LightboxTool.arrow,
            onTap: () => onTool(_LightboxTool.arrow),
            palette: palette,
          ),
          _ToolBtn(
            icon: Icons.title,
            selected: tool == _LightboxTool.text,
            onTap: () => onTool(_LightboxTool.text),
            palette: palette,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Container(
              height: 1,
              width: 28,
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          _ToolBtn(
            icon: Icons.undo,
            selected: false,
            onTap: onUndo,
            palette: palette,
          ),
          _ToolBtn(
            icon: Icons.check,
            selected: false,
            onTap: onDone,
            palette: palette,
          ),
        ],
      ),
    );
  }
}

class _ToolBtn extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final AppPalette palette;

  const _ToolBtn({
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected
            ? palette.accent.withValues(alpha: 0.2)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(
              icon,
              size: 18,
              color: selected ? palette.accent : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}

class _SidePanel extends ConsumerWidget {
  final MoodboardImageModel image;
  final TextEditingController titleCtrl;
  final TextEditingController yearCtrl;
  final TextEditingController directorCtrl;
  final TextEditingController dopCtrl;
  final TextEditingController notesCtrl;
  final TextEditingController tagsCtrl;
  final TextEditingController cameraCtrl;
  final TextEditingController lensesCtrl;
  final TextEditingController aspectCtrl;
  final TextEditingController commentCtrl;
  final String? lightingLook;
  final String? lightSource;
  final String? lightTexture;
  final String? composition;
  final String? locationKind;
  final String? locationName;
  final String? timeOfDay;
  final String? colorMood;
  final bool pendingReview;
  final List<String> intExtOptions;
  final List<String> timeOptions;
  final List<LocationBasePlan> projectLocations;
  final ValueChanged<String?> onLightingLook;
  final ValueChanged<String?> onLightSource;
  final ValueChanged<String?> onLightTexture;
  final ValueChanged<String?> onComposition;
  final ValueChanged<String?> onLocationKind;
  final Future<void> Function(LocationBasePlan? plan) onSelectLocation;
  final Future<void> Function() onAddLocation;
  final ValueChanged<String?> onTimeOfDay;
  final ValueChanged<String?> onColorMood;
  final ValueChanged<bool> onPendingReview;
  final int? bibleId;
  final bool annotateMode;
  final VoidCallback onClose;
  final Future<void> Function() onSave;
  final VoidCallback onAdd;
  final VoidCallback onShare;
  final VoidCallback onToggleAnnotate;
  final Future<void> Function() onPostComment;

  const _SidePanel({
    required this.image,
    required this.titleCtrl,
    required this.yearCtrl,
    required this.directorCtrl,
    required this.dopCtrl,
    required this.notesCtrl,
    required this.tagsCtrl,
    required this.cameraCtrl,
    required this.lensesCtrl,
    required this.aspectCtrl,
    required this.commentCtrl,
    required this.lightingLook,
    required this.lightSource,
    required this.lightTexture,
    required this.composition,
    required this.locationKind,
    required this.locationName,
    required this.timeOfDay,
    required this.colorMood,
    required this.pendingReview,
    required this.intExtOptions,
    required this.timeOptions,
    required this.projectLocations,
    required this.onLightingLook,
    required this.onLightSource,
    required this.onLightTexture,
    required this.onComposition,
    required this.onLocationKind,
    required this.onSelectLocation,
    required this.onAddLocation,
    required this.onTimeOfDay,
    required this.onColorMood,
    required this.onPendingReview,
    required this.bibleId,
    required this.annotateMode,
    required this.onClose,
    required this.onSave,
    required this.onAdd,
    required this.onShare,
    required this.onToggleAnnotate,
    required this.onPostComment,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);
    final locLabel = (locationName ?? image.linkedLocationName)?.trim();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121214),
        border: Border(
          left: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    annotateMode ? 'ANOTAR' : 'DETALLE DEL PLANO',
                    style: AppTypography.mono(palette).copyWith(
                          fontSize: 11,
                          letterSpacing: 1.3,
                          color: annotateMode
                              ? const Color(0xFFFFB4AB)
                              : palette.accent,
                        ),
                  ),
                ),
                IconButton(
                  tooltip: pendingReview
                      ? 'Quitar pendiente'
                      : 'Marcar pendiente',
                  onPressed: () => onPendingReview(!pendingReview),
                  icon: Icon(
                    pendingReview
                        ? Icons.mark_email_unread
                        : Icons.mark_email_read_outlined,
                    color: pendingReview ? palette.warning : palette.textTertiary,
                    size: 20,
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: Icon(Icons.close, color: palette.textSecondary),
                ),
              ],
            ),
          ),
          if (pendingReview)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: palette.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: palette.warning.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  'Pendiente de revisar',
                  style: AppTypography.caption(palette).copyWith(
                        color: palette.warning,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                TextField(
                  controller: titleCtrl,
                  style: AppTypography.titleMedium(palette).copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                  decoration: const InputDecoration(
                    hintText: 'Título del plano / referencia',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
                if (locLabel != null && locLabel.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      locLabel.toUpperCase(),
                      style: AppTypography.mono(palette).copyWith(
                            fontSize: 10,
                            letterSpacing: 0.8,
                            color: palette.textTertiary,
                          ),
                    ),
                  ),
                TextField(
                  controller: notesCtrl,
                  maxLines: 4,
                  style: AppTypography.bodyMedium(palette).copyWith(
                        height: 1.45,
                        color: palette.textSecondary,
                      ),
                  decoration: InputDecoration(
                    hintText: 'Apunte principal del plano…',
                    hintStyle: AppTypography.bodyMedium(palette).copyWith(
                          color: palette.textTertiary,
                        ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.03),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: palette.accent.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _CatalogSectionLabel(text: 'Catálogo biblia', palette: palette),
                const SizedBox(height: 8),
                _ChipRow(
                  label: 'INT / EXT (guion)',
                  options: intExtOptions,
                  value: locationKind,
                  onChanged: onLocationKind,
                  palette: palette,
                ),
                const SizedBox(height: 10),
                Text(
                  'Localización',
                  style: AppTypography.caption(palette).copyWith(
                        color: palette.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final plan in projectLocations)
                      FilterChip(
                        label: Text(plan.locationName),
                        selected: locationName == plan.locationName,
                        onSelected: (v) => onSelectLocation(v ? plan : null),
                        showCheckmark: false,
                        visualDensity: VisualDensity.compact,
                        labelStyle: TextStyle(
                          fontSize: 11,
                          color: locationName == plan.locationName
                              ? palette.textPrimary
                              : palette.textSecondary,
                        ),
                        selectedColor: palette.accent.withValues(alpha: 0.22),
                        backgroundColor: Colors.white.withValues(alpha: 0.03),
                        side: BorderSide(
                          color: locationName == plan.locationName
                              ? palette.accent.withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                    ActionChip(
                      avatar: Icon(Icons.add, size: 16, color: palette.accent),
                      label: const Text('Añadir'),
                      onPressed: onAddLocation,
                      visualDensity: VisualDensity.compact,
                      labelStyle: TextStyle(
                        fontSize: 11,
                        color: palette.accent,
                        fontWeight: FontWeight.w600,
                      ),
                      backgroundColor: Colors.white.withValues(alpha: 0.03),
                      side: BorderSide(
                        color: palette.accent.withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                ),
                if (projectLocations.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Sin sets aún. Añade uno o crea localizaciones desde el guion.',
                      style: AppTypography.caption(palette).copyWith(
                            color: palette.textTertiary,
                          ),
                    ),
                  ),
                const SizedBox(height: 10),
                _ChipRow(
                  label: 'Hora del día',
                  options: timeOptions,
                  value: timeOfDay,
                  onChanged: onTimeOfDay,
                  palette: palette,
                ),
                const SizedBox(height: 10),
                _ChipRow(
                  label: 'Calidad de luz',
                  options: kMoodboardLightingLooks,
                  value: lightingLook,
                  onChanged: onLightingLook,
                  palette: palette,
                ),
                const SizedBox(height: 10),
                _ChipRow(
                  label: 'Tipo / fuente de luz',
                  options: kMoodboardLightSources,
                  value: lightSource,
                  onChanged: onLightSource,
                  palette: palette,
                ),
                const SizedBox(height: 10),
                _ChipRow(
                  label: 'Textura de la luz',
                  options: kMoodboardLightTextures,
                  value: lightTexture,
                  onChanged: onLightTexture,
                  palette: palette,
                ),
                const SizedBox(height: 10),
                _ChipRow(
                  label: 'Composición',
                  options: kMoodboardCompositions,
                  value: composition,
                  onChanged: onComposition,
                  palette: palette,
                ),
                const SizedBox(height: 10),
                _ChipRow(
                  label: 'Look color',
                  options: kMoodboardColorMoods,
                  value: colorMood,
                  onChanged: onColorMood,
                  palette: palette,
                ),
                const SizedBox(height: 16),
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    title: Text(
                      'Créditos y técnico',
                      style: AppTypography.caption(palette).copyWith(
                            color: palette.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    children: [
                      TextField(
                        controller: yearCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Año',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: aspectCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Aspect ratio',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: directorCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Director',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: dopCtrl,
                        decoration: const InputDecoration(
                          labelText: 'DP / DoP',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: cameraCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Cámara',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: lensesCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Óptica',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: tagsCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Tags (coma)',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                FilledButton.tonal(
                  onPressed: () async {
                    await onSave();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Detalles guardados'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: const Text('Guardar'),
                ),
                const SizedBox(height: 20),
                _CatalogSectionLabel(text: 'Notas', palette: palette),
                const SizedBox(height: 8),
                if (bibleId == null || bibleId! <= 0)
                  Text(
                    'Guarda la biblia para comentar.',
                    style: AppTypography.caption(palette),
                  )
                else
                  StreamBuilder<List<BibleComment>>(
                    stream: db.watchBibleComments(
                      bibleId!,
                      targetType: 'moodboard',
                      targetId: image.id,
                    ),
                    builder: (context, snap) {
                      final comments = snap.data ?? [];
                      if (comments.isEmpty) {
                        return Text(
                          'Sin notas aún.',
                          style: AppTypography.caption(palette).copyWith(
                                color: palette.textTertiary,
                              ),
                        );
                      }
                      return Column(
                        children: [
                          for (final c in comments)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.06),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.comment,
                                    style: AppTypography.bodyMedium(palette)
                                        .copyWith(fontSize: 13, height: 1.4),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        '${c.authorRole.toUpperCase()} · '
                                        '${c.createdAt.toLocal().toString().substring(0, 16)}',
                                        style: AppTypography.caption(palette),
                                      ),
                                      const Spacer(),
                                      InkWell(
                                        onTap: () =>
                                            db.deleteBibleComment(c.id),
                                        child: Icon(
                                          Icons.close,
                                          size: 14,
                                          color: palette.textTertiary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: commentCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Añadir nota…',
                          isDense: true,
                        ),
                        onSubmitted: (_) => onPostComment(),
                      ),
                    ),
                    IconButton(
                      onPressed: onPostComment,
                      icon: Icon(Icons.send, color: palette.accent),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('A biblia'),
                ),
                FilledButton.tonalIcon(
                  onPressed: onToggleAnnotate,
                  icon: Icon(
                    annotateMode ? Icons.check : Icons.draw_outlined,
                    size: 16,
                  ),
                  label: Text(annotateMode ? 'Listo' : 'Anotar'),
                ),
                OutlinedButton.icon(
                  onPressed: onShare,
                  icon: const Icon(Icons.ios_share, size: 16),
                  label: const Text('Share'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogSectionLabel extends StatelessWidget {
  final String text;
  final AppPalette palette;

  const _CatalogSectionLabel({required this.text, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppTypography.mono(palette).copyWith(
            fontSize: 10,
            letterSpacing: 1.1,
            color: palette.textTertiary,
          ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  final String label;
  final List<String> options;
  final String? value;
  final ValueChanged<String?> onChanged;
  final AppPalette palette;

  const _ChipRow({
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.caption(palette).copyWith(
                color: palette.textSecondary,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final opt in options)
              FilterChip(
                label: Text(opt),
                selected: value == opt,
                onSelected: (v) => onChanged(v ? opt : null),
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                labelStyle: TextStyle(
                  fontSize: 11,
                  color: value == opt
                      ? palette.textPrimary
                      : palette.textSecondary,
                ),
                selectedColor: palette.accent.withValues(alpha: 0.22),
                backgroundColor: Colors.white.withValues(alpha: 0.03),
                side: BorderSide(
                  color: value == opt
                      ? palette.accent.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final AppPalette palette;

  const _CircleBtn({
    required this.icon,
    required this.onTap,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
