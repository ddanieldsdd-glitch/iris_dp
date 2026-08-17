import 'dart:async';
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
import '../../../shared/annotations/annotation_canvas.dart';
import '../../../shared/annotations/annotation_document.dart';
import '../../../shared/visual_bible/bible_section_ids.dart';
import '../moodboard_annotation_store.dart';
import '../moodboard_catalog_service.dart';
import '../services/moodboard_lighting_link_service.dart';
import '../moodboard_palette_extractor.dart';
import '../moodboard_reference_meta.dart';
import '../visual_bible_model.dart';
import 'moodboard_assign_fields.dart';

enum _LightboxTool { draw, arrow, text, select, eraser }

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
          projectId:
              projectId ?? (images.isNotEmpty ? images.first.projectId : null),
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
  String? _selectedNoteId;
  late final AnnotationCanvasController _annotationController;
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
  List<String> _assignedSections = const [];

  List<LocationBasePlan> _projectLocations = const [];
  List<String> _intExtOptions = List.of(kMoodboardIntExt);
  List<String> _timeOptions = List.of(kMoodboardTimesOfDay);
  List<String> _lightingLookOptions = List.of(kMoodboardLightingLooks);
  List<String> _lightSourceOptions = List.of(kMoodboardLightSources);
  List<String> _lightTextureOptions = List.of(kMoodboardLightTextures);
  List<String> _compositionOptions = List.of(kMoodboardCompositions);
  List<String> _colorMoodOptions = List.of(kMoodboardColorMoods);

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.images.length - 1);
    _metaById = Map.of(widget.metaById);
    _focus = FocusNode();
    _annotationController = AnnotationCanvasController();
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
    _annotationController.dispose();
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
    _assignedSections = List<String>.from(_image.assignedSections);
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
    final catalog = await MoodboardCatalogService.loadForProject(projectId);
    if (!mounted) return;

    final intExt = <String>{
      ...MoodboardCatalogService.options(
        MoodboardCatalogKey.intExt,
        catalog,
      ),
    };
    final times = <String>{
      ...MoodboardCatalogService.options(
        MoodboardCatalogKey.timeOfDay,
        catalog,
      ),
    };
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
      _lightingLookOptions = MoodboardCatalogService.options(
        MoodboardCatalogKey.lightingLook,
        catalog,
      );
      _lightSourceOptions = MoodboardCatalogService.options(
        MoodboardCatalogKey.lightSource,
        catalog,
      );
      _lightTextureOptions = MoodboardCatalogService.options(
        MoodboardCatalogKey.lightTexture,
        catalog,
      );
      _compositionOptions = MoodboardCatalogService.options(
        MoodboardCatalogKey.composition,
        catalog,
      );
      _colorMoodOptions = MoodboardCatalogService.options(
        MoodboardCatalogKey.colorMood,
        catalog,
      );
    });
  }

  Future<void> _loadStrokes() async {
    setState(() => _strokesLoading = true);
    final imageId = _image.id;
    final document = await MoodboardAnnotationStore.loadDocument(
      db: ref.read(databaseProvider),
      projectId: widget.projectId ?? _image.projectId,
      imageId: imageId,
    );
    if (!mounted) return;
    if (_image.id != imageId) return;
    setState(() {
      _annotationController.replaceDocument(document);
      _strokesLoading = false;
    });
  }

  Future<void> _persistStrokes() async {
    await MoodboardAnnotationStore.saveDocument(
      db: ref.read(databaseProvider),
      projectId: widget.projectId ?? _image.projectId,
      imageId: _image.id,
      document: _annotationController.document,
    );
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
    await MoodboardReferenceMetaStore.save(ref.read(databaseProvider), _image.id, next);
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
      _selectedNoteId = null;
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
      director: _directorCtrl.text.trim().isEmpty
          ? null
          : _directorCtrl.text.trim(),
      dop: _dopCtrl.text.trim().isEmpty ? null : _dopCtrl.text.trim(),
      technicalNotes: _notesCtrl.text.trim().isEmpty
          ? null
          : _notesCtrl.text.trim(),
      camera: _cameraCtrl.text.trim().isEmpty ? null : _cameraCtrl.text.trim(),
      lenses: _lensesCtrl.text.trim().isEmpty ? null : _lensesCtrl.text.trim(),
      aspectRatio: _aspectCtrl.text.trim().isEmpty
          ? null
          : _aspectCtrl.text.trim(),
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
    await MoodboardReferenceMetaStore.save(ref.read(databaseProvider), _image.id, next);
    _metaById[_image.id] = next;
    widget.onMetaSaved?.call(_image.id, next);
    if (widget.bibleId != null) {
      await MoodboardLightingLinkService.linkImageToMatchingCards(
        db: ref.read(databaseProvider),
        bibleId: widget.bibleId!,
        imageId: _image.id,
        meta: next,
      );
    }
    await _persistPlacement();
  }

  Future<void> _persistPlacement() async {
    await MoodboardCatalogService.updateImagePlacement(
      db: ref.read(databaseProvider),
      image: _image,
      assignedSections: _assignedSections,
      linkedLocationName: _locationName,
      linkedLocationBasePlanId: _image.linkedLocationBasePlanId,
    );
  }

  Future<void> _applySuggestedSections() async {
    await _saveMetaSilent();
    final suggested = MoodboardCatalogService.suggestSections(
      meta: _metaById[_image.id] ?? const MoodboardReferenceMeta(),
      linkedLocationName: _locationName ?? _image.linkedLocationName,
      linkedLocationBasePlanId: _image.linkedLocationBasePlanId,
    );
    if (suggested.isEmpty) return;
    setState(() {
      _assignedSections = {..._assignedSections, ...suggested}.toList();
    });
    await _persistPlacement();
  }

  Future<void> _addCatalogOption(MoodboardCatalogKey key) async {
    final projectId = widget.projectId ?? _image.projectId;
    final label = switch (key) {
      MoodboardCatalogKey.intExt => 'INT / EXT',
      MoodboardCatalogKey.timeOfDay => 'Hora del día',
      MoodboardCatalogKey.lightingLook => 'Calidad de luz',
      MoodboardCatalogKey.lightSource => 'Tipo / fuente de luz',
      MoodboardCatalogKey.lightTexture => 'Textura de la luz',
      MoodboardCatalogKey.composition => 'Composición',
      MoodboardCatalogKey.colorMood => 'Look color',
    };
    final ctrl = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Añadir a $label'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: 'Nueva opción…'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Añadir'),
          ),
        ],
      ),
    );
    if (value == null || value.isEmpty || !mounted) return;
    await MoodboardCatalogService.addCustomOption(
      projectId: projectId,
      key: key,
      value: value,
    );
    await _loadCatalogContext();
    if (!mounted) return;
    setState(() {
      switch (key) {
        case MoodboardCatalogKey.intExt:
          _locationKind = value;
        case MoodboardCatalogKey.timeOfDay:
          _timeOfDay = value;
        case MoodboardCatalogKey.lightingLook:
          _lightingLook = value;
        case MoodboardCatalogKey.lightSource:
          _lightSource = value;
        case MoodboardCatalogKey.lightTexture:
          _lightTexture = value;
        case MoodboardCatalogKey.composition:
          _composition = value;
        case MoodboardCatalogKey.colorMood:
          _colorMood = value;
      }
    });
    await _saveMetaSilent();
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
    if (_annotateMode) {
      if (event.logicalKey == LogicalKeyboardKey.backspace ||
          event.logicalKey == LogicalKeyboardKey.delete) {
        _deleteSelectedNote();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
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
    _annotationController.undo();
  }

  Future<void> _editNote(String noteId, {String? initialText}) async {
    final note = _annotationController.document.notes
        .where((n) => n.id == noteId)
        .firstOrNull;
    if (note == null) return;
    final ctrl = TextEditingController(text: initialText ?? note.text);
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar post-it'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Texto…'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (text == null || text.isEmpty) return;
    _annotationController.updateNote(noteId, text: text);
    await _persistStrokes();
  }

  Future<void> _addTextLabel(Size size, Offset local) async {
    final nx = (local.dx / size.width).clamp(0.0, 1.0);
    final ny = (local.dy / size.height).clamp(0.0, 1.0);
    final hit = _annotationController.hitTestNote(nx, ny);
    if (hit != null) {
      setState(() => _selectedNoteId = hit);
      await _editNote(hit);
      return;
    }

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
    final x = (local.dx / size.width).clamp(0.0, 1.0);
    final y = (local.dy / size.height).clamp(0.0, 1.0);
    _annotationController.addNote(
      AnnotationNote(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        text: text,
        x: x,
        y: y,
        width: 0.24,
        height: 0.12,
        colorArgb: _drawColor.toARGB32(),
      ),
    );
    await _persistStrokes();
  }

  void _deleteSelectedNote() {
    final id = _selectedNoteId;
    if (id == null) return;
    _annotationController.removeNote(id);
    setState(() => _selectedNoteId = null);
    unawaited(_persistStrokes());
  }

  Future<void> _linkLocation({String? name, int? planId}) async {
    setState(() {
      _locationName = name;
      if (name != null &&
          name.isNotEmpty &&
          !_assignedSections.contains(BibleSectionId.location)) {
        _assignedSections = [..._assignedSections, BibleSectionId.location];
      }
    });
    await _saveMetaSilent();
    await MoodboardCatalogService.updateImagePlacement(
      db: ref.read(databaseProvider),
      image: _image,
      assignedSections: _assignedSections,
      linkedLocationName: name,
      linkedLocationBasePlanId: planId,
    );
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
          decoration: const InputDecoration(hintText: 'Nombre del set / lugar'),
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

  Future<void> _handleClose() async {
    await _saveMetaSilent();
    await _persistStrokes();
    widget.onClose();
  }

  void _openExpandedImage() {
    if (_annotateMode) return;
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar imagen',
      barrierColor: Colors.black.withValues(alpha: 0.92),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (ctx, anim, secondary) {
        return _ExpandedImageViewer(
          imagePath: _image.imagePath,
          onClose: () => Navigator.of(ctx).pop(),
        );
      },
      transitionBuilder: (ctx, anim, secondary, child) {
        return FadeTransition(opacity: anim, child: child);
      },
    );
  }

  _Stage _buildStage() {
    return _Stage(
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
      annotationController: _annotationController,
      tool: _tool,
      drawColor: _drawColor,
      onTool: (t) => setState(() {
        _tool = t;
        if (t != _LightboxTool.select) {
          _selectedNoteId = null;
        }
      }),
      onColor: (c) => setState(() => _drawColor = c),
      onUndo: _undoStroke,
      onExitAnnotate: () => setState(() {
        _annotateMode = false;
        _selectedNoteId = null;
      }),
      onAnnotationChanged: _persistStrokes,
      onTapForText: _addTextLabel,
      selectedNoteId: _selectedNoteId,
      onNoteSelected: (id) => setState(() => _selectedNoteId = id),
      onNoteEdit: (note) => _editNote(note.id),
      onDeleteNote: _deleteSelectedNote,
      onExpandImage: _annotateMode ? null : _openExpandedImage,
    );
  }

  _ShotTitleNotes _buildTitleNotes({
    int notesMaxLines = 3,
    bool showTitle = true,
  }) {
    return _ShotTitleNotes(
      titleCtrl: _titleCtrl,
      notesCtrl: _notesCtrl,
      locationLabel: (_locationName ?? _image.linkedLocationName)?.trim(),
      notesMaxLines: notesMaxLines,
      showTitle: showTitle,
    );
  }

  _BibleCatalogBlock _buildCatalog() {
    return _BibleCatalogBlock(
      intExtOptions: _intExtOptions,
      timeOptions: _timeOptions,
      lightingLookOptions: _lightingLookOptions,
      lightSourceOptions: _lightSourceOptions,
      lightTextureOptions: _lightTextureOptions,
      compositionOptions: _compositionOptions,
      colorMoodOptions: _colorMoodOptions,
      projectLocations: _projectLocations,
      locationKind: _locationKind,
      locationName: _locationName,
      timeOfDay: _timeOfDay,
      lightingLook: _lightingLook,
      lightSource: _lightSource,
      lightTexture: _lightTexture,
      composition: _composition,
      colorMood: _colorMood,
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
      onColorMood: (v) {
        setState(() => _colorMood = v);
        _saveMetaSilent();
      },
      onAddCatalogOption: _addCatalogOption,
    );
  }

  _BibleScreensBlock _buildScreens() {
    return _BibleScreensBlock(
      assignedSections: _assignedSections,
      linkedLocationName: _locationName ?? _image.linkedLocationName,
      onAssignedSectionsChanged: (next) async {
        setState(() => _assignedSections = next);
        await _persistPlacement();
      },
      onSuggestSections: _applySuggestedSections,
    );
  }

  _TechnicalCreditsBlock _buildCredits() {
    return _TechnicalCreditsBlock(
      yearCtrl: _yearCtrl,
      aspectCtrl: _aspectCtrl,
      directorCtrl: _directorCtrl,
      dopCtrl: _dopCtrl,
      cameraCtrl: _cameraCtrl,
      lensesCtrl: _lensesCtrl,
      tagsCtrl: _tagsCtrl,
      onSave: _saveMetaSilent,
    );
  }

  _UserNotesBlock _buildUserNotes() {
    return _UserNotesBlock(
      bibleId: widget.bibleId,
      imageId: _image.id,
      commentCtrl: _commentCtrl,
      onPostComment: _postComment,
    );
  }

  _LightboxActionBar _buildActions() {
    return _LightboxActionBar(
      annotateMode: _annotateMode,
      onAdd: () => widget.onAddToProject(_image),
      onShare: _share,
      onToggleAnnotate: () => setState(() {
        _annotateMode = !_annotateMode;
        if (_annotateMode) _tool = _LightboxTool.draw;
      }),
    );
  }

  Widget _buildChromeHeader({required bool showTitle}) {
    return _LightboxChromeHeader(
      annotateMode: _annotateMode,
      pendingReview: _pendingReview,
      showTitle: showTitle,
      titleCtrl: showTitle ? _titleCtrl : null,
      onPendingReview: (v) {
        setState(() => _pendingReview = v);
        _saveMetaSilent();
      },
      onClose: _handleClose,
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 16, 4),
                child: _buildTitleNotes(notesMaxLines: 2),
              ),
              Expanded(
                flex: 3,
                child: _buildStage(),
              ),
              Expanded(
                flex: 2,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: _buildCatalog(),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 360,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF121214),
              border: Border(
                left: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildChromeHeader(showTitle: false),
                if (_pendingReview)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: _PendingReviewBanner(),
                  ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      _buildScreens(),
                      const SizedBox(height: 16),
                      _buildCredits(),
                      const SizedBox(height: 20),
                      _buildUserNotes(),
                    ],
                  ),
                ),
                _buildActions(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    final stageHeight = MediaQuery.sizeOf(context).height * 0.42;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildChromeHeader(showTitle: true),
        if (_pendingReview)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _PendingReviewBanner(),
          ),
        SizedBox(height: stageHeight, child: _buildStage()),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              _buildTitleNotes(notesMaxLines: 4, showTitle: false),
              const SizedBox(height: 16),
              _buildCatalog(),
              const SizedBox(height: 16),
              _buildScreens(),
              const SizedBox(height: 16),
              _buildCredits(),
              const SizedBox(height: 20),
              _buildUserNotes(),
            ],
          ),
        ),
        _buildActions(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: Material(
        color: const Color(0xF20E0E10),
        child: wide ? _buildDesktopLayout() : _buildMobileLayout(),
      ),
    );
  }
}

class _ExpandedImageViewer extends StatelessWidget {
  final String imagePath;
  final VoidCallback onClose;

  const _ExpandedImageViewer({
    required this.imagePath,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          onClose();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Material(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Center(
                child: Image.file(
                  File(imagePath),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.broken_image_outlined,
                    color: palette.textTertiary,
                    size: 48,
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  tooltip: 'Cerrar',
                  onPressed: onClose,
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ),
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
  final AnnotationCanvasController annotationController;
  final _LightboxTool tool;
  final Color drawColor;
  final ValueChanged<_LightboxTool> onTool;
  final ValueChanged<Color> onColor;
  final VoidCallback onUndo;
  final VoidCallback onExitAnnotate;
  final VoidCallback onAnnotationChanged;
  final Future<void> Function(Size size, Offset local) onTapForText;
  final String? selectedNoteId;
  final ValueChanged<String?> onNoteSelected;
  final Future<void> Function(AnnotationNote note) onNoteEdit;
  final VoidCallback onDeleteNote;
  final VoidCallback? onExpandImage;

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
    required this.annotationController,
    required this.tool,
    required this.drawColor,
    required this.onTool,
    required this.onColor,
    required this.onUndo,
    required this.onExitAnnotate,
    required this.onAnnotationChanged,
    required this.onTapForText,
    required this.selectedNoteId,
    required this.onNoteSelected,
    required this.onNoteEdit,
    required this.onDeleteNote,
    this.onExpandImage,
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
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Center(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final size = Size(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          );
                          final canvas = ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: AnnotationCanvas(
                              controller: widget.annotationController,
                              enabled: widget.annotateMode &&
                                  widget.tool != _LightboxTool.text &&
                                  widget.tool != _LightboxTool.select,
                              tool: widget.tool == _LightboxTool.arrow
                                  ? AnnotationToolType.arrow
                                  : widget.tool == _LightboxTool.eraser
                                      ? AnnotationToolType.eraser
                                      : AnnotationToolType.pen,
                              color: widget.drawColor,
                              width: widget.tool == _LightboxTool.arrow ? 4 : 3,
                              acceptTouch: true,
                              onChanged: (_) => widget.onAnnotationChanged(),
                              interactiveNotes: widget.annotateMode &&
                                  (widget.tool == _LightboxTool.select ||
                                      widget.tool == _LightboxTool.text),
                              selectedNoteId: widget.selectedNoteId,
                              onNoteSelected: widget.onNoteSelected,
                              onNoteEditRequested: widget.onNoteEdit,
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
                                  if (widget.strokesLoading)
                                    const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  if (widget.annotateMode &&
                                      widget.tool == _LightboxTool.text)
                                    GestureDetector(
                                      behavior: HitTestBehavior.translucent,
                                      onTapUp: (details) => widget.onTapForText(
                                        size,
                                        details.localPosition,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                          if (widget.onExpandImage == null) return canvas;
                          return MouseRegion(
                            cursor: SystemMouseCursors.zoomIn,
                            child: GestureDetector(
                              onTap: widget.onExpandImage,
                              child: canvas,
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
                          drawColor: widget.drawColor,
                          onTool: widget.onTool,
                          onColor: widget.onColor,
                          onUndo: widget.onUndo,
                          onDone: widget.onExitAnnotate,
                          onDeleteNote: widget.onDeleteNote,
                          canDeleteNote: widget.selectedNoteId != null,
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
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: widget.extracting
                        ? const Padding(
                            padding: EdgeInsets.only(bottom: 4),
                            child: SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : TextButton(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: widget.onReextract,
                            child: Text(
                              'Re-extraer',
                              style: AppTypography.caption(palette).copyWith(
                                color: palette.accent,
                                fontSize: 11,
                              ),
                            ),
                          ),
                  ),
                  SizedBox(
                    height: 28,
                    child: widget.palette.isEmpty
                        ? Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.04),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.18),
                              ),
                            ),
                            child: Text(
                              widget.extracting
                                  ? 'Extrayendo paleta…'
                                  : 'Sin paleta · pulsa Re-extraer',
                              style: AppTypography.caption(
                                palette,
                              ).copyWith(color: palette.textSecondary),
                            ),
                          )
                        : Row(
                            children: [
                              for (var i = 0; i < widget.palette.length; i++)
                                Expanded(
                                  child: ColoredBox(
                                    color: widget.palette[i],
                                    child: const SizedBox.expand(),
                                  ),
                                ),
                            ],
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
  final Color drawColor;
  final ValueChanged<_LightboxTool> onTool;
  final ValueChanged<Color> onColor;
  final VoidCallback onUndo;
  final VoidCallback onDone;
  final VoidCallback onDeleteNote;
  final bool canDeleteNote;
  final AppPalette palette;

  static const _swatches = [
    Color(0xFF2997FF),
    Color(0xFFFF3B30),
    Color(0xFFFFCC00),
    Color(0xFF34C759),
    Color(0xFFFFFFFF),
  ];

  const _AnnotateToolbar({
    required this.tool,
    required this.drawColor,
    required this.onTool,
    required this.onColor,
    required this.onUndo,
    required this.onDone,
    required this.onDeleteNote,
    required this.canDeleteNote,
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
          _ToolBtn(
            icon: Icons.pan_tool_alt_outlined,
            selected: tool == _LightboxTool.select,
            onTap: () => onTool(_LightboxTool.select),
            palette: palette,
          ),
          _ToolBtn(
            icon: Icons.auto_fix_off,
            selected: tool == _LightboxTool.eraser,
            onTap: () => onTool(_LightboxTool.eraser),
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
          for (final swatch in _swatches)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: GestureDetector(
                onTap: () => onColor(swatch),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: swatch,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: drawColor == swatch
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.25),
                      width: drawColor == swatch ? 2 : 1,
                    ),
                  ),
                ),
              ),
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
            icon: Icons.delete_outline,
            selected: false,
            onTap: canDeleteNote ? onDeleteNote : () {},
            palette: palette,
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

class _LightboxChromeHeader extends StatelessWidget {
  final bool annotateMode;
  final bool pendingReview;
  final bool showTitle;
  final TextEditingController? titleCtrl;
  final ValueChanged<bool> onPendingReview;
  final VoidCallback onClose;

  const _LightboxChromeHeader({
    required this.annotateMode,
    required this.pendingReview,
    required this.showTitle,
    this.titleCtrl,
    required this.onPendingReview,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: showTitle && titleCtrl != null
                ? TextField(
                    controller: titleCtrl,
                    style: AppTypography.titleMedium(palette).copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Título del plano / referencia',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  )
                : Text(
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
            tooltip: pendingReview ? 'Quitar pendiente' : 'Marcar pendiente',
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
    );
  }
}

class _PendingReviewBanner extends StatelessWidget {
  const _PendingReviewBanner();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: palette.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: palette.warning.withValues(alpha: 0.35)),
      ),
      child: Text(
        'Pendiente de revisar',
        style: AppTypography.caption(palette).copyWith(
          color: palette.warning,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ShotTitleNotes extends StatelessWidget {
  final TextEditingController titleCtrl;
  final TextEditingController notesCtrl;
  final String? locationLabel;
  final int notesMaxLines;
  final bool showTitle;

  const _ShotTitleNotes({
    required this.titleCtrl,
    required this.notesCtrl,
    required this.locationLabel,
    this.notesMaxLines = 3,
    this.showTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final loc = locationLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTitle)
          TextField(
            controller: titleCtrl,
            style: AppTypography.titleMedium(
              palette,
            ).copyWith(fontSize: 20, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(
              hintText: 'Título del plano / referencia',
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (loc != null && loc.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              loc.toUpperCase(),
              style: AppTypography.mono(palette).copyWith(
                fontSize: 10,
                letterSpacing: 0.8,
                color: palette.textTertiary,
              ),
            ),
          ),
        TextField(
          controller: notesCtrl,
          maxLines: notesMaxLines,
          style: AppTypography.bodyMedium(
            palette,
          ).copyWith(height: 1.4, color: palette.textSecondary, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Apunte principal del plano…',
            hintStyle: AppTypography.bodyMedium(
              palette,
            ).copyWith(color: palette.textTertiary, fontSize: 13),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.03),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: palette.accent.withValues(alpha: 0.45),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BibleCatalogBlock extends StatelessWidget {
  final List<String> intExtOptions;
  final List<String> timeOptions;
  final List<String> lightingLookOptions;
  final List<String> lightSourceOptions;
  final List<String> lightTextureOptions;
  final List<String> compositionOptions;
  final List<String> colorMoodOptions;
  final List<LocationBasePlan> projectLocations;
  final String? locationKind;
  final String? locationName;
  final String? timeOfDay;
  final String? lightingLook;
  final String? lightSource;
  final String? lightTexture;
  final String? composition;
  final String? colorMood;
  final ValueChanged<String?> onLocationKind;
  final Future<void> Function(LocationBasePlan? plan) onSelectLocation;
  final Future<void> Function() onAddLocation;
  final ValueChanged<String?> onTimeOfDay;
  final ValueChanged<String?> onLightingLook;
  final ValueChanged<String?> onLightSource;
  final ValueChanged<String?> onLightTexture;
  final ValueChanged<String?> onComposition;
  final ValueChanged<String?> onColorMood;
  final Future<void> Function(MoodboardCatalogKey key) onAddCatalogOption;

  const _BibleCatalogBlock({
    required this.intExtOptions,
    required this.timeOptions,
    required this.lightingLookOptions,
    required this.lightSourceOptions,
    required this.lightTextureOptions,
    required this.compositionOptions,
    required this.colorMoodOptions,
    required this.projectLocations,
    required this.locationKind,
    required this.locationName,
    required this.timeOfDay,
    required this.lightingLook,
    required this.lightSource,
    required this.lightTexture,
    required this.composition,
    required this.colorMood,
    required this.onLocationKind,
    required this.onSelectLocation,
    required this.onAddLocation,
    required this.onTimeOfDay,
    required this.onLightingLook,
    required this.onLightSource,
    required this.onLightTexture,
    required this.onComposition,
    required this.onColorMood,
    required this.onAddCatalogOption,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CatalogSectionLabel(text: 'Catálogo biblia', palette: palette),
        const SizedBox(height: 8),
        _ChipRow(
          label: 'INT / EXT (guion)',
          options: intExtOptions,
          value: locationKind,
          onChanged: onLocationKind,
          palette: palette,
          onAddCustom: () => onAddCatalogOption(MoodboardCatalogKey.intExt),
        ),
        const SizedBox(height: 8),
        Text(
          'Localización',
          style: AppTypography.caption(palette).copyWith(
            color: palette.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          runSpacing: 4,
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
              side: BorderSide(color: palette.accent.withValues(alpha: 0.35)),
            ),
          ],
        ),
        if (projectLocations.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Sin sets aún. Añade uno o crea localizaciones desde el guion.',
              style: AppTypography.caption(
                palette,
              ).copyWith(color: palette.textTertiary),
            ),
          ),
        const SizedBox(height: 8),
        _ChipRow(
          label: 'Hora del día',
          options: timeOptions,
          value: timeOfDay,
          onChanged: onTimeOfDay,
          palette: palette,
          onAddCustom: () => onAddCatalogOption(MoodboardCatalogKey.timeOfDay),
        ),
        const SizedBox(height: 8),
        _ChipRow(
          label: 'Calidad de luz',
          options: lightingLookOptions,
          value: lightingLook,
          onChanged: onLightingLook,
          palette: palette,
          onAddCustom: () =>
              onAddCatalogOption(MoodboardCatalogKey.lightingLook),
        ),
        const SizedBox(height: 8),
        _ChipRow(
          label: 'Tipo / fuente de luz',
          options: lightSourceOptions,
          value: lightSource,
          onChanged: onLightSource,
          palette: palette,
          onAddCustom: () =>
              onAddCatalogOption(MoodboardCatalogKey.lightSource),
        ),
        const SizedBox(height: 8),
        _ChipRow(
          label: 'Textura de la luz',
          options: lightTextureOptions,
          value: lightTexture,
          onChanged: onLightTexture,
          palette: palette,
          onAddCustom: () =>
              onAddCatalogOption(MoodboardCatalogKey.lightTexture),
        ),
        const SizedBox(height: 8),
        _ChipRow(
          label: 'Composición',
          options: compositionOptions,
          value: composition,
          onChanged: onComposition,
          palette: palette,
          onAddCustom: () =>
              onAddCatalogOption(MoodboardCatalogKey.composition),
        ),
        const SizedBox(height: 8),
        _ChipRow(
          label: 'Look color',
          options: colorMoodOptions,
          value: colorMood,
          onChanged: onColorMood,
          palette: palette,
          onAddCustom: () => onAddCatalogOption(MoodboardCatalogKey.colorMood),
        ),
      ],
    );
  }
}

class _BibleScreensBlock extends StatelessWidget {
  final List<String> assignedSections;
  final String? linkedLocationName;
  final ValueChanged<List<String>> onAssignedSectionsChanged;
  final Future<void> Function() onSuggestSections;

  const _BibleScreensBlock({
    required this.assignedSections,
    required this.linkedLocationName,
    required this.onAssignedSectionsChanged,
    required this.onSuggestSections,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CatalogSectionLabel(text: 'Aparece en la biblia', palette: palette),
        const SizedBox(height: 8),
        MoodboardAssignmentBadges(
          assignedSections: assignedSections,
          linkedLocationName: linkedLocationName,
        ),
        const SizedBox(height: 10),
        MoodboardSectionAssignField(
          selected: assignedSections,
          onChanged: onAssignedSectionsChanged,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onSuggestSections,
            icon: const Icon(Icons.auto_awesome_outlined, size: 16),
            label: const Text('Sugerir pantallas desde catálogo'),
          ),
        ),
      ],
    );
  }
}

class _TechnicalCreditsBlock extends StatelessWidget {
  final TextEditingController yearCtrl;
  final TextEditingController aspectCtrl;
  final TextEditingController directorCtrl;
  final TextEditingController dopCtrl;
  final TextEditingController cameraCtrl;
  final TextEditingController lensesCtrl;
  final TextEditingController tagsCtrl;
  final Future<void> Function() onSave;

  const _TechnicalCreditsBlock({
    required this.yearCtrl,
    required this.aspectCtrl,
    required this.directorCtrl,
    required this.dopCtrl,
    required this.cameraCtrl,
    required this.lensesCtrl,
    required this.tagsCtrl,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
      ],
    );
  }
}

class _UserNotesBlock extends ConsumerWidget {
  final int? bibleId;
  final int imageId;
  final TextEditingController commentCtrl;
  final Future<void> Function() onPostComment;

  const _UserNotesBlock({
    required this.bibleId,
    required this.imageId,
    required this.commentCtrl,
    required this.onPostComment,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
              targetId: imageId,
            ),
            builder: (context, snap) {
              final comments = snap.data ?? [];
              if (comments.isEmpty) {
                return Text(
                  'Sin notas aún.',
                  style: AppTypography.caption(
                    palette,
                  ).copyWith(color: palette.textTertiary),
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
                            style: AppTypography.bodyMedium(
                              palette,
                            ).copyWith(fontSize: 13, height: 1.4),
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
                                onTap: () => db.deleteBibleComment(c.id),
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
    );
  }
}

class _LightboxActionBar extends StatelessWidget {
  final bool annotateMode;
  final VoidCallback onAdd;
  final VoidCallback onShare;
  final VoidCallback onToggleAnnotate;

  const _LightboxActionBar({
    required this.annotateMode,
    required this.onAdd,
    required this.onShare,
    required this.onToggleAnnotate,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
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
      style: AppTypography.mono(
        palette,
      ).copyWith(fontSize: 10, letterSpacing: 1.1, color: palette.textTertiary),
    );
  }
}

class _ChipRow extends StatelessWidget {
  final String label;
  final List<String> options;
  final String? value;
  final ValueChanged<String?> onChanged;
  final AppPalette palette;
  final VoidCallback? onAddCustom;

  const _ChipRow({
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    required this.palette,
    this.onAddCustom,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.caption(
            palette,
          ).copyWith(color: palette.textSecondary, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          runSpacing: 4,
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
            if (onAddCustom != null)
              ActionChip(
                avatar: Icon(Icons.add, size: 14, color: palette.accent),
                label: const Text('Añadir'),
                onPressed: onAddCustom,
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
