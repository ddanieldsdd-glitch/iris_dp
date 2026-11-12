import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/export_cancel.dart';
import '../../core/utils/export_file_saver.dart';
import '../../core/utils/share_origin.dart';
import '../../core/utils/shot_reference_import.dart';
import '../../core/utils/user_error.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../shared/technical_script_export/technical_script_doc.dart';
import '../camera_plan/plan_data.dart';
import '../camera_plan/plan_renderer.dart' show PlanExportView;
import '../camera_plan/plan_view_picker.dart';
import '../projects/project_card_actions.dart' show pickMoodboardCover;
import '../shoot_documents/shoot_days_board.dart';
import '../storyboard/shot_sheet_data.dart';
import '../technical_script/script_export_dialog.dart';
import '../technical_script/technical_script_export.dart';
import '../technical_script/technical_script_settings.dart';
import 'export_options.dart';
import 'export_runner.dart';
import 'export_selection.dart';

/// Una sola pantalla para sacar el storyboard, la planta de cámara y luz y el
/// guion técnico: se elige el documento, qué entra y cómo sale, y a la derecha
/// se ve el PDF de verdad.
class ExportCenterScreen extends ConsumerStatefulWidget {
  final int projectId;
  final ExportDocument? document;

  /// Abre con esta jornada elegida.
  final int? dayId;

  /// Abre con estos planos elegidos.
  final Set<int>? shotIds;

  /// Abre con el formato PDF o Word ya puesto en el guion técnico.
  final bool? word;

  const ExportCenterScreen({
    super.key,
    required this.projectId,
    this.document,
    this.dayId,
    this.shotIds,
    this.word,
  });

  static Future<void> open(
    BuildContext context, {
    required int projectId,
    ExportDocument? document,
    int? dayId,
    Set<int>? shotIds,
    bool? word,
  }) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ExportCenterScreen(
        projectId: projectId,
        document: document,
        dayId: dayId,
        shotIds: shotIds,
        word: word,
      ),
    ),
  );

  @override
  ConsumerState<ExportCenterScreen> createState() => _ExportCenterScreenState();
}

class _ExportCenterScreenState extends ConsumerState<ExportCenterScreen> {
  ExportSource? _source;
  PlanProjectData? _plans;
  ExportOptions _options = const ExportOptions();
  ExportSelection _selection = const ExportSelection();
  bool _ready = false;
  bool _saving = false;

  _PreviewDoc? _preview;
  Object? _previewError;
  bool _building = false;
  int _version = 0;
  Timer? _debounce;

  /// Lo ya montado en esta sesión: volver a un modo es inmediato.
  final _previewCache = <String, _PreviewDoc>{};
  static const _previewsKept = 8;
  int _previewSerial = 0;

  /// Vista previa de todo el documento, en vez de los primeros planos.
  bool _previewAll = false;

  final _openDays = <int>{};

  TechnicalScriptSettings get _settings =>
      ref.read(technicalScriptSettingsProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Set<int> _blocksOfDay(ExportSource source, int dayId) => {
    for (final b
        in source.plan.blocksByDay[dayId] ?? const <ShootDocumentBlock>[])
      if (b.shotId != null) b.id,
  };

  Set<int> _allBlocks(ExportSource source) => {
    for (final day in source.plan.days) ..._blocksOfDay(source, day.id),
  };

  Set<int> _allShots(ExportSource source) => {
    for (final s in source.shots) s.id,
  };

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final source = await ExportSource.load(db, widget.projectId);
    final plans = await PlanProjectData.load(db, widget.projectId);
    var options = await ExportOptions.load(widget.projectId, _settings);
    if (!mounted || source == null) return;
    if (widget.document != null) {
      options = options.copyWith(document: widget.document);
    }
    if (widget.word != null) {
      options = options.copyWith(
        script: options.script.copyWith(word: widget.word),
      );
    }
    final ExportSelection selection;
    if (widget.dayId != null) {
      selection = ExportSelection(
        scope: ExportScope.days,
        blockIds: _blocksOfDay(source, widget.dayId!),
      );
      _openDays.add(widget.dayId!);
    } else if (widget.shotIds != null) {
      selection = ExportSelection(
        scope: ExportScope.shots,
        shotIds: widget.shotIds!,
      );
    } else {
      final scope = options.scope == ExportScope.shots
          ? ExportScope.all
          : options.scope;
      selection = ExportSelection(
        scope: scope,
        blockIds: _allBlocks(source),
        shotIds: _allShots(source),
      );
    }
    setState(() {
      _source = source;
      _plans = plans;
      _options = options;
      _selection = selection;
      _ready = true;
    });
    _schedulePreview();
  }

  /// El documento elegido enseña la planta de cada plano.
  bool get _showsPlan => switch (_options.document) {
    ExportDocument.shootingPlan || ExportDocument.technicalScript => true,
    ExportDocument.storyboard => _options.look == StoryboardLook.shotPlan,
  };

  /// Vuelve a leer lo que ha podido cambiar al elegir una sección.
  Future<void> _reloadPlans() async {
    final db = ref.read(databaseProvider);
    final source = await ExportSource.load(db, widget.projectId);
    final plans = await PlanProjectData.load(db, widget.projectId);
    if (!mounted || source == null) return;
    _previewCache.clear();
    setState(() {
      _source = source;
      _plans = plans;
    });
    _schedulePreview();
  }

  Future<void> _pickShotSection(Shot shot) async {
    final plans = _plans;
    if (plans == null) return;
    await showPlanViewPicker(context, data: plans, shot: shot);
    await _reloadPlans();
  }

  Future<void> _pickSetupSection(LightSetup setup) async {
    final plans = _plans;
    if (plans == null) return;
    await showSetupViewPicker(
      context,
      db: ref.read(databaseProvider),
      data: plans,
      setup: setup,
    );
    await _reloadPlans();
  }

  /// Los esquemas de luz de lo elegido, una vez cada uno.
  List<LightSetup> _chosenSetups() {
    final plans = _plans;
    if (plans == null) return const [];
    final seen = <int>{};
    return [
      for (final section in _sections)
        for (final tract in section.scenes)
          for (final item in tract.shots)
            if (plans.setup(item.shot.lightSetupId) case final setup?)
              if (seen.add(setup.id)) setup,
    ];
  }

  List<ExportDaySection> get _sections =>
      _source == null ? const [] : resolveExportSections(_source!, _selection);

  /// Con lo elegido ahora, el reparto en archivos que tiene sentido.
  ExportOptions get _effective {
    final perDayWithoutDays =
        _options.split == ExportSplit.perDay &&
        _selection.scope != ExportScope.days;
    return _options.copyWith(
      scope: _selection.scope,
      split: perDayWithoutDays ? ExportSplit.single : null,
    );
  }

  int _shotCount(List<ExportDaySection> sections) =>
      sections.fold(0, (n, s) => n + s.shotCount);

  bool get _canExport {
    final sections = _sections;
    if (_options.document == ExportDocument.technicalScript &&
        _selection.scope == ExportScope.all) {
      return sections.any((s) => s.scenes.isNotEmpty);
    }
    return _shotCount(sections) > 0;
  }

  void _setOptions(ExportOptions options) {
    _previewAll = false;
    setState(() => _options = options);
    unawaited(options.copyWith(scope: _selection.scope).save(widget.projectId));
    _schedulePreview();
  }

  void _setSelection(ExportSelection selection) {
    setState(() => _selection = selection);
    _schedulePreview();
  }

  void _setScope(ExportScope scope) {
    _setSelection(_selection.copyWith(scope: scope));
    unawaited(_options.copyWith(scope: scope).save(widget.projectId));
  }

  /// Identifica lo que se ve: documento, formato, lo elegido y su alcance.
  String get _previewKey => jsonEncode([
    _effective.toJson(),
    _selection.blockIds.toList()..sort(),
    _selection.shotIds.toList()..sort(),
    _previewAll,
  ]);

  void _schedulePreview() {
    _debounce?.cancel();
    // Cualquier montaje en curso se queda viejo ya, no al acabar la espera.
    final version = ++_version;
    final cached = _previewCache[_previewKey];
    if (cached != null) {
      setState(() {
        _preview = cached;
        _previewError = null;
        _building = false;
      });
      return;
    }
    setState(() => _building = true);
    _debounce = Timer(
      const Duration(milliseconds: 250),
      () => _buildPreview(version),
    );
  }

  Future<void> _buildPreview(int version) async {
    final source = _source;
    if (source == null) return;
    if (!_canExport) {
      setState(() {
        _preview = null;
        _previewError = null;
        _building = false;
      });
      return;
    }
    final key = _previewKey;
    final sample = previewSample(
      _sections,
      _previewAll ? 1 << 30 : _options.previewShots,
    );
    final runner = ExportRunner(ref.read(databaseProvider), source, _settings);
    final options = _effective;
    try {
      final bytes = await ExportCancel.run(
        () => version != _version,
        () => runner.preview(sample.sections, options),
      );
      if (!mounted || version != _version) return;
      final preview = _PreviewDoc(
        bytes,
        'exportacion_${++_previewSerial}.pdf',
        shown: sample.shown,
        total: sample.total,
      );
      _previewCache[key] = preview;
      while (_previewCache.length > _previewsKept) {
        _previewCache.remove(_previewCache.keys.first);
      }
      setState(() {
        _preview = preview;
        _previewError = null;
        _building = false;
      });
    } catch (e) {
      if (!mounted || version != _version) return;
      setState(() {
        _preview = null;
        _previewError = e;
        _building = false;
      });
    }
  }

  Future<void> _export() async {
    final source = _source;
    if (source == null || _saving) return;
    setState(() => _saving = true);
    try {
      final files = ExportRunner(
        ref.read(databaseProvider),
        source,
        _settings,
      ).files(_sections, _effective);
      final path = await ExportRunner.save(
        files,
        shareOrigin: shareOrigin(context),
      );
      if (!mounted || path == null) return;
      AppSnackBar.show(
        context,
        files.length == 1
            ? 'Guardado en $path'
            : '${files.length} archivos guardados en $path',
      );
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, userFriendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openPlan() async {
    await ShootDaysBoardScreen.open(context, projectId: widget.projectId);
    if (!mounted) return;
    final source = await ExportSource.load(
      ref.read(databaseProvider),
      widget.projectId,
    );
    if (!mounted || source == null) return;
    _previewCache.clear();
    setState(() {
      _source = source;
      _selection = _selection.copyWith(blockIds: _allBlocks(source));
    });
    _schedulePreview();
  }

  void _openPreviewPage() {
    final preview = _preview;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Vista previa')),
          body: preview == null
              ? const Center(child: CircularProgressIndicator())
              : PdfViewer.data(
                  preview.bytes,
                  sourceName: preview.name,
                  params: const PdfViewerParams(margin: 12),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: palette.surface,
        title: Text('Exportar', style: AppTypography.titleMedium(palette)),
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 860;
                final panel = _panel(palette, wide: wide);
                if (!wide) return panel;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: (constraints.maxWidth * 0.46).clamp(420.0, 620.0),
                      child: panel,
                    ),
                    VerticalDivider(width: 1, color: palette.divider),
                    Expanded(child: _previewPane(palette)),
                  ],
                );
              },
            ),
    );
  }

  Widget _title(AppPalette palette, String text) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
    child: Text(text, style: AppTypography.label(palette)),
  );

  Widget _panel(AppPalette palette, {required bool wide}) {
    final sections = _sections;
    final shots = _shotCount(sections);
    final scenes = {
      for (final s in sections)
        for (final t in s.scenes)
          if (t.shots.isNotEmpty) t.scene.id,
    }.length;
    final days = sections.where((s) => s.day != null).length;
    final repeated = {
      for (final s in sections)
        for (final t in s.scenes)
          for (final x in t.shots)
            if (x.alsoIn.isNotEmpty) x.shot.id,
    }.length;
    final count = [
      '$shots ${shots == 1 ? 'plano' : 'planos'}',
      '$scenes ${scenes == 1 ? 'escena' : 'escenas'}',
      if (days > 0) '$days ${days == 1 ? 'jornada' : 'jornadas'}',
    ].join(' · ');
    final effective = _effective;
    final files = _source == null
        ? 0
        : ExportRunner(
            ref.read(databaseProvider),
            _source!,
            _settings,
          ).files(sections, effective).length;
    final word =
        _options.document == ExportDocument.technicalScript &&
        _options.script.word;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            children: [
              _title(palette, 'Documento'),
              _DocumentPicker(
                value: _options.document,
                onChanged: (d) => _setOptions(_options.copyWith(document: d)),
              ),
              _title(palette, 'Qué entra'),
              _scopeSelector(),
              const SizedBox(height: AppSpacing.sm),
              ..._scopeBody(palette),
              _title(palette, 'Cómo sale'),
              ..._format(palette),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: palette.surface,
            border: Border(top: BorderSide(color: palette.divider)),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(count, style: AppTypography.bodyMedium(palette)),
                      if (repeated > 0)
                        Text(
                          repeated == 1
                              ? '1 plano se repite en otra jornada'
                              : '$repeated planos se repiten en otra jornada',
                          style: AppTypography.caption(
                            palette,
                          ).copyWith(color: palette.warning),
                        ),
                    ],
                  ),
                ),
                if (!wide)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: IconButton(
                      tooltip: 'Vista previa',
                      icon: const Icon(Icons.visibility_outlined),
                      onPressed: _preview == null || _building
                          ? null
                          : _openPreviewPage,
                    ),
                  ),
                FilledButton.icon(
                  onPressed: _canExport && !_saving ? _export : null,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.ios_share, size: 18),
                  label: Text(
                    files > 1 ? 'Exportar $files' : (word ? 'Word' : 'PDF'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _scopeSelector() => SegmentedButton<ExportScope>(
    showSelectedIcon: false,
    segments: const [
      ButtonSegment(value: ExportScope.all, label: Text('Todo')),
      ButtonSegment(value: ExportScope.days, label: Text('Jornadas')),
      ButtonSegment(value: ExportScope.scenes, label: Text('Escenas')),
      ButtonSegment(value: ExportScope.shots, label: Text('Planos')),
    ],
    selected: {_selection.scope},
    onSelectionChanged: (v) => _setScope(v.first),
  );

  List<Widget> _scopeBody(AppPalette palette) {
    final source = _source!;
    switch (_selection.scope) {
      case ExportScope.all:
        return [
          Text(
            'Todo el proyecto, en el orden del guion.',
            style: AppTypography.caption(palette),
          ),
        ];
      case ExportScope.days:
        if (source.plan.days.isEmpty) {
          return [
            Text(
              'Aún no hay jornadas. Reparte las escenas por días en el plan '
              'de rodaje.',
              style: AppTypography.caption(palette),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _openPlan,
                icon: const Icon(Icons.view_week_outlined, size: 18),
                label: const Text('Abrir plan de rodaje'),
              ),
            ),
          ];
        }
        return _dayTree(palette, source);
      case ExportScope.scenes:
      case ExportScope.shots:
        final loose = _selection.scope == ExportScope.shots;
        return [
          _allOrNone(
            onAll: () =>
                _setSelection(_selection.copyWith(shotIds: _allShots(source))),
            onNone: () => _setSelection(_selection.copyWith(shotIds: const {})),
          ),
          for (final scene in source.scenes)
            if (source.shotsOfScene(scene.id).isNotEmpty)
              _sceneBlock(palette, source, scene, loose: loose),
        ];
    }
  }

  Widget _allOrNone({
    required VoidCallback onAll,
    required VoidCallback onNone,
  }) => Row(
    children: [
      TextButton(onPressed: onAll, child: const Text('Todo')),
      TextButton(onPressed: onNone, child: const Text('Nada')),
    ],
  );

  /// Casilla de un grupo: marcada, vacía o a medias.
  Widget _tri(int chosen, int total, VoidCallback onTap) => Checkbox(
    tristate: true,
    value: chosen == 0 ? false : (chosen == total ? true : null),
    onChanged: (_) => onTap(),
  );

  void _toggleShots(Iterable<int> ids) {
    final next = {..._selection.shotIds};
    if (ids.every(next.contains)) {
      next.removeAll(ids);
    } else {
      next.addAll(ids);
    }
    _setSelection(_selection.copyWith(shotIds: next));
  }

  void _toggleBlocks(Iterable<int> ids) {
    final next = {..._selection.blockIds};
    if (ids.every(next.contains)) {
      next.removeAll(ids);
    } else {
      next.addAll(ids);
    }
    _setSelection(_selection.copyWith(blockIds: next));
  }

  Widget _sceneBlock(
    AppPalette palette,
    ExportSource source,
    Scene scene, {
    required bool loose,
  }) {
    final shots = source.shotsOfScene(scene.id);
    final ids = [for (final s in shots) s.id];
    final chosen = ids.where(_selection.shotIds.contains).length;
    return _Group(
      leading: _tri(chosen, ids.length, () => _toggleShots(ids)),
      title: 'Esc ${scene.label} · ${scene.locationPureName}',
      trailing: '$chosen de ${ids.length}',
      onTap: () => _toggleShots(ids),
      child: _ShotStrip(
        shots: [
          for (final s in shots)
            _ShotItem(s, _selection.shotIds.contains(s.id), s.id),
        ],
        onTap: loose ? (id) => _toggleShots([id]) : null,
        onSection: _showsPlan ? _pickShotSection : null,
      ),
    );
  }

  List<Widget> _dayTree(AppPalette palette, ExportSource source) {
    final whole = resolveExportSections(
      source,
      ExportSelection(scope: ExportScope.days, blockIds: _allBlocks(source)),
    );
    final free = source.plan.unassigned.fold<int>(
      0,
      (n, u) => n + u.shots.length,
    );
    return [
      _allOrNone(
        onAll: () =>
            _setSelection(_selection.copyWith(blockIds: _allBlocks(source))),
        onNone: () => _setSelection(_selection.copyWith(blockIds: const {})),
      ),
      for (final section in whole) _dayBlock(palette, section),
      if (free > 0)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Text(
            free == 1
                ? '1 plano sin jornada no entra en esta exportación.'
                : '$free planos sin jornada no entran en esta exportación.',
            style: AppTypography.caption(palette),
          ),
        ),
    ];
  }

  Widget _dayBlock(AppPalette palette, ExportDaySection section) {
    final day = section.day!;
    final ids = [
      for (final t in section.scenes)
        for (final x in t.shots) x.block!.id,
    ];
    final chosen = ids.where(_selection.blockIds.contains).length;
    final open = _openDays.contains(day.id);
    void toggleOpen() =>
        setState(() => open ? _openDays.remove(day.id) : _openDays.add(day.id));
    return _Group(
      leading: _tri(chosen, ids.length, () => _toggleBlocks(ids)),
      title: [
        day.name,
        if (day.shootDate != null) formatShootDate(day.shootDate),
      ].join(' · '),
      trailing: '$chosen de ${ids.length}',
      onTap: toggleOpen,
      expanded: open,
      child: !open
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final tract in section.scenes) ...[
                  Row(
                    children: [
                      _tri(
                        tract.shots
                            .where(
                              (x) => _selection.blockIds.contains(x.block!.id),
                            )
                            .length,
                        tract.shots.length,
                        () => _toggleBlocks([
                          for (final x in tract.shots) x.block!.id,
                        ]),
                      ),
                      Expanded(
                        child: Text(
                          'Esc ${tract.scene.label} · '
                          '${tract.scene.locationPureName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption(palette),
                        ),
                      ),
                    ],
                  ),
                  _ShotStrip(
                    shots: [
                      for (final x in tract.shots)
                        _ShotItem(
                          x.shot,
                          _selection.blockIds.contains(x.block!.id),
                          x.block!.id,
                          repeated: x.alsoIn.isNotEmpty,
                        ),
                    ],
                    onTap: (id) => _toggleBlocks([id]),
                    onSection: _showsPlan ? _pickShotSection : null,
                  ),
                ],
              ],
            ),
    );
  }

  /// Las plantas generales del final, con la sección de cada una.
  List<Widget> _overviewRows(AppPalette palette) => [
    for (final setup in _chosenSetups())
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(
                setup.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyMedium(palette),
              ),
            ),
            TextButton.icon(
              onPressed: () => _pickSetupSection(setup),
              icon: Icon(
                Icons.crop_free,
                size: 16,
                color: _plans?.documentViewOf(setup) == null
                    ? null
                    : palette.accent,
              ),
              label: Text(
                _plans?.documentViewOf(setup) == null
                    ? 'Elegir sección'
                    : 'Cambiar sección',
              ),
            ),
          ],
        ),
      ),
  ];

  /// Copia la imagen elegida a la carpeta de la app: la ruta original puede
  /// dejar de valer, sobre todo en el iPad.
  Future<String?> _importPlanImage() async {
    final file = await UserFilePicker.pickImage(dialogTitle: 'Elegir imagen');
    if (file == null) return null;
    final bytes =
        file.bytes ??
        (file.path == null ? null : await File(file.path!).readAsBytes());
    if (bytes == null || bytes.isEmpty) return null;
    final folder = Directory(
      p.join((await getApplicationSupportDirectory()).path, 'export_center'),
    );
    await folder.create(recursive: true);
    final target = File(
      p.join(
        folder.path,
        '${widget.projectId}_${DateTime.now().microsecondsSinceEpoch}'
        '${p.extension(file.name)}',
      ),
    );
    await target.writeAsBytes(bytes);
    return target.path;
  }

  Widget _planImageRow(
    AppPalette palette, {
    required String title,
    required String empty,
    required String? path,
    required ValueChanged<String> onPick,
    required VoidCallback onClear,
    bool moodboard = false,
  }) => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Row(
      children: [
        Expanded(
          child: Text(
            '$title · ${path == null ? empty : 'Imagen'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyMedium(palette),
          ),
        ),
        if (path != null)
          TextButton(onPressed: onClear, child: const Text('Quitar')),
        if (moodboard)
          PopupMenuButton<bool>(
            tooltip: 'Elegir imagen',
            onSelected: (fromMoodboard) async {
              final chosen = fromMoodboard
                  ? await pickMoodboardCover(
                      context,
                      ref.read(databaseProvider),
                      widget.projectId,
                    )
                  : await _importPlanImage();
              if (chosen != null && mounted) onPick(chosen);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: true,
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.dashboard_outlined, size: 18),
                  title: Text('Del moodboard'),
                ),
              ),
              PopupMenuItem(
                value: false,
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.folder_open_outlined, size: 18),
                  title: Text('De un archivo'),
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.image_outlined, size: 16, color: palette.accent),
                  const SizedBox(width: 6),
                  Text(
                    path == null ? 'Añadir' : 'Cambiar',
                    style: AppTypography.bodyMedium(
                      palette,
                    ).copyWith(color: palette.accent),
                  ),
                ],
              ),
            ),
          )
        else
          TextButton.icon(
            onPressed: () async {
              final imported = await _importPlanImage();
              if (imported != null && mounted) onPick(imported);
            },
            icon: const Icon(Icons.image_outlined, size: 16),
            label: Text(path == null ? 'Añadir' : 'Cambiar'),
          ),
      ],
    ),
  );

  /// La portada, la misma para la planta, el guion técnico y el orden del
  /// día: del moodboard o de un archivo. Sin elegir, la del proyecto.
  Widget _coverRow(AppPalette palette, {required String empty}) =>
      _planImageRow(
        palette,
        title: 'Imagen de portada',
        empty: empty,
        path: _options.planCoverImage,
        moodboard: true,
        onPick: (path) => _setOptions(_options.copyWith(planCoverImage: path)),
        onClear: () =>
            _setOptions(_options.copyWith(clearPlanCoverImage: true)),
      );

  List<Widget> _format(AppPalette palette) {
    final canSplitDays = _selection.scope == ExportScope.days;
    final split = _effective.split;
    final body = switch (_options.document) {
      ExportDocument.storyboard => _storyboardFormat(palette),
      ExportDocument.shootingPlan => [
        SegmentedButton<PlanExportView>(
          showSelectedIcon: false,
          segments: [
            for (final view in PlanExportView.values)
              ButtonSegment(value: view, label: Text(view.label)),
          ],
          selected: {_options.planView},
          onSelectionChanged: (v) =>
              _setOptions(_options.copyWith(planView: v.first)),
        ),
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Text(switch (_options.planView) {
            PlanExportView.stage =>
              'Cámaras, actores y recorridos, con los nombres al margen. '
                  'Sin luces.',
            PlanExportView.light =>
              'Las luces numeradas, con su lista al lado. Cámaras y actores '
                  'atenuados.',
            PlanExportView.both =>
              'Cada plano lleva su planta de cámara y actores y, debajo, la '
                  'de luz.',
          }, style: AppTypography.caption(palette)),
        ),
        if (_options.planView.hasLight)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _options.planBeams,
            onChanged: (v) => _setOptions(_options.copyWith(planBeams: v)),
            title: const Text('Con haces de luz'),
            subtitle: const Text(
              'Apágalo para ver los aparatos sin la luz que proyectan.',
            ),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _options.planOverviews,
          onChanged: (v) => _setOptions(_options.copyWith(planOverviews: v)),
          title: const Text('Plantas generales al final'),
          subtitle: const Text(
            'Una página por esquema. La sección también se aplica a los '
            'planos que no tengan la suya.',
          ),
        ),
        if (_options.planOverviews) ..._overviewRows(palette),
        _coverRow(palette, empty: 'Banda negra'),
        _planImageRow(
          palette,
          title: 'Fondo de las plantas',
          empty: 'Negro',
          path: _options.planBackdropImage,
          onPick: (path) =>
              _setOptions(_options.copyWith(planBackdropImage: path)),
          onClear: () =>
              _setOptions(_options.copyWith(clearPlanBackdropImage: true)),
        ),
      ],
      ExportDocument.technicalScript => _scriptFormat(palette),
    };
    return [
      ...body,
      ..._documentSwitches(),
      const SizedBox(height: AppSpacing.sm),
      Wrap(
        spacing: AppSpacing.sm,
        children: [
          for (final option in ExportSplit.values)
            if (option != ExportSplit.perDay || canSplitDays)
              ChoiceChip(
                label: Text(option.label),
                selected: split == option,
                onSelected: (_) =>
                    _setOptions(_options.copyWith(split: option)),
              ),
        ],
      ),
    ];
  }

  /// Lo que abre el documento: índice, plan de rodaje y tiempo.
  List<Widget> _documentSwitches() {
    final document = _options.document;
    final schedule = _options.withSchedule;
    return [
      if (document == ExportDocument.shootingPlan)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _options.planIndex,
          onChanged: (v) => _setOptions(_options.copyWith(planIndex: v)),
          title: const Text('Índice'),
          subtitle: const Text('En la portada, con la página de cada plano.'),
        ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: schedule,
        onChanged: (v) => _setOptions(_options.withScheduleSet(v)),
        title: Text(
          document == ExportDocument.technicalScript
              ? 'Portada de la jornada'
              : 'Plan de rodaje al principio',
        ),
        subtitle: Text(
          document == ExportDocument.technicalScript
              ? 'Lugar, mapa, tiempo y horario. Solo al exportar una jornada.'
              : 'El orden del día de cada jornada exportada, antes de los '
                    'planos.',
        ),
      ),
      if (schedule)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _options.withWeather,
          onChanged: (v) => _setOptions(_options.copyWith(withWeather: v)),
          title: const Text('Meteorología'),
          subtitle: const Text('La previsión del tiempo. El sol se queda.'),
        ),
    ];
  }

  Widget _lookChips(AppPalette palette, String title, bool sheets) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.caption(palette)),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            for (final look in StoryboardLook.values)
              if (look.isSheet == sheets)
                Tooltip(
                  message: look.hint,
                  child: ChoiceChip(
                    label: Text(look.label),
                    selected: _options.look == look,
                    onSelected: (_) =>
                        _setOptions(_options.copyWith(look: look)),
                  ),
                ),
          ],
        ),
      ],
    ),
  );

  List<Widget> _storyboardFormat(AppPalette palette) => [
    _lookChips(palette, 'Varios planos por hoja', false),
    _lookChips(palette, 'Una hoja por plano', true),
    Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Text(_options.look.hint, style: AppTypography.caption(palette)),
    ),
    if (_options.look.isSheet) ...[
      const SizedBox(height: AppSpacing.sm),
      SegmentedButton<ShotImageSource>(
        showSelectedIcon: false,
        segments: [
          for (final source in ShotImageSource.values)
            ButtonSegment(value: source, label: Text(source.label)),
        ],
        selected: {_options.imageSource},
        onSelectionChanged: (v) =>
            _setOptions(_options.copyWith(imageSource: v.first)),
      ),
    ],
  ];

  List<Widget> _scriptFormat(AppPalette palette) {
    final script = _options.script;
    void set(ScriptExportOptions next) =>
        _setOptions(_options.copyWith(script: next));
    final columnLabels = {for (final c in kScriptDocColumns) c.key: c.label};
    return [
      SegmentedButton<bool>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: false, label: Text('PDF')),
          ButtonSegment(value: true, label: Text('Word')),
        ],
        selected: {script.word},
        onSelectionChanged: (v) => set(script.copyWith(word: v.first)),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: script.index,
        onChanged: (v) => set(script.copyWith(index: v)),
        title: const Text('Índice de escenas'),
      ),
      Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          for (final key in ScriptExportOptions.optionalColumns)
            FilterChip(
              label: Text(columnLabels[key] ?? key),
              selected: script.shows(key),
              onSelected: (on) => set(
                script.copyWith(
                  hiddenColumns: on
                      ? ({...script.hiddenColumns}..remove(key))
                      : {...script.hiddenColumns, key},
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: [
          for (final size in ScriptExportOptions.fontSizes.entries)
            ChoiceChip(
              label: Text(size.value),
              selected: script.fontSize == size.key,
              onSelected: (_) => set(script.copyWith(fontSize: size.key)),
            ),
          for (final paper in ScriptDocPaper.values)
            ChoiceChip(
              label: Text(paper.label),
              selected: script.paper == paper,
              onSelected: (_) => set(script.copyWith(paper: paper)),
            ),
          ChoiceChip(
            label: const Text('Apaisado'),
            selected: script.landscape,
            onSelected: (v) => set(script.copyWith(landscape: v)),
          ),
        ],
      ),
      if (!script.word) ...[
        const SizedBox(height: AppSpacing.sm),
        _coverRow(palette, empty: 'Foto de la localización o del proyecto'),
      ],
    ];
  }

  Widget _partialNotice(AppPalette palette, _PreviewDoc preview) => Material(
    color: palette.surfaceElevated,
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Vista previa con los ${preview.shown} primeros de '
              '${preview.total} planos. El archivo sale completo.',
              style: AppTypography.caption(palette),
            ),
          ),
          TextButton(
            onPressed: () {
              _previewAll = true;
              _schedulePreview();
            },
            child: const Text('Ver todo'),
          ),
        ],
      ),
    ),
  );

  Widget _previewPane(AppPalette palette) {
    final Widget content;
    if (_previewError != null) {
      content = Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            userFriendlyError(_previewError!),
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium(palette),
          ),
        ),
      );
    } else if (_preview != null) {
      // El visor guarda cada documento por su nombre: uno nuevo necesita un
      // nombre nuevo o enseñaría el anterior.
      content = PdfViewer.data(
        _preview!.bytes,
        key: ValueKey(_preview!.name),
        sourceName: _preview!.name,
        params: const PdfViewerParams(margin: 16),
      );
    } else if (_building) {
      content = const Center(child: CircularProgressIndicator());
    } else {
      content = Center(
        child: Text(
          'Elige qué entra para ver el documento.',
          style: AppTypography.bodyMedium(palette),
        ),
      );
    }
    return ColoredBox(
      color: palette.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          content,
          if (_preview case final preview? when preview.partial && !_building)
            Positioned(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: AppSpacing.md,
              child: _partialNotice(palette, preview),
            ),
          // Lo que se ve ya no es lo elegido: que no parezca que no cambia.
          if (_building && _preview != null)
            Positioned.fill(
              child: ColoredBox(
                color: palette.background.withValues(alpha: 0.78),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Actualizando la vista previa…',
                        style: AppTypography.bodyMedium(palette),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Una vista previa ya montada.
class _PreviewDoc {
  final Uint8List bytes;

  /// Único para cada documento: el visor los guarda por nombre.
  final String name;
  final int shown;
  final int total;

  const _PreviewDoc(
    this.bytes,
    this.name, {
    required this.shown,
    required this.total,
  });

  bool get partial => shown < total;
}

/// Las tres tarjetas de documento, cada una con su dibujo.
class _DocumentPicker extends StatelessWidget {
  final ExportDocument value;
  final ValueChanged<ExportDocument> onChanged;

  const _DocumentPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    Widget card(ExportDocument document, String title, Widget glyph) {
      final selected = value == document;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Material(
            color: selected ? palette.accentMuted : palette.surfaceElevated,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: selected ? palette.accent : palette.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onChanged(document),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  children: [
                    SizedBox(height: 54, child: glyph),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: AppTypography.caption(
                        palette,
                      ).copyWith(color: palette.textPrimary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    Widget block(double width, double height) => Container(
      width: width,
      height: height,
      color: palette.textTertiary.withValues(alpha: 0.55),
    );
    final storyboard = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var row = 0; row < 2; row++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var c = 0; c < 3; c++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: block(24, 18),
                  ),
              ],
            ),
          ),
      ],
    );
    final plan = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.grid_on_outlined, size: 40, color: palette.textTertiary),
        const SizedBox(width: 6),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            block(28, 3),
            const SizedBox(height: 4),
            block(20, 3),
            const SizedBox(height: 4),
            block(28, 12),
          ],
        ),
      ],
    );
    final script = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var row = 0; row < 4; row++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                block(14, 6),
                const SizedBox(width: 3),
                block(22, 6),
                const SizedBox(width: 3),
                block(36, 6),
              ],
            ),
          ),
      ],
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        card(ExportDocument.storyboard, 'Storyboard', storyboard),
        card(ExportDocument.shootingPlan, 'Planta de cámara y luz', plan),
        card(ExportDocument.technicalScript, 'Guion técnico', script),
      ],
    );
  }
}

/// Una jornada o escena con su casilla.
class _Group extends StatelessWidget {
  final Widget leading;
  final String title;
  final String trailing;
  final VoidCallback onTap;
  final bool? expanded;
  final Widget? child;

  const _Group({
    required this.leading,
    required this.title,
    required this.trailing,
    required this.onTap,
    this.expanded,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: palette.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Row(
                children: [
                  leading,
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMedium(palette),
                    ),
                  ),
                  Text(trailing, style: AppTypography.caption(palette)),
                  if (expanded != null)
                    Icon(
                      expanded! ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: palette.textTertiary,
                    ),
                ],
              ),
            ),
          ),
          if (child != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                0,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: child,
            ),
        ],
      ),
    );
  }
}

class _ShotItem {
  final Shot shot;
  final bool selected;

  /// Lo que se conmuta al tocarlo: el plano o su bloque de la jornada.
  final int key;
  final bool repeated;

  const _ShotItem(this.shot, this.selected, this.key, {this.repeated = false});
}

/// Miniaturas de planos; se pueden tocar o solo enseñar lo elegido.
class _ShotStrip extends StatelessWidget {
  final List<_ShotItem> shots;
  final ValueChanged<int>? onTap;

  /// Elegir la parte de la planta del plano; sin él no hay botón.
  final ValueChanged<Shot>? onSection;

  const _ShotStrip({required this.shots, this.onTap, this.onSection});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [for (final item in shots) _thumb(palette, item)],
    );
  }

  Widget _thumb(AppPalette palette, _ShotItem item) {
    final shot = item.shot;
    final path = storyboardImageOf(shot) ?? referenceImageOf(shot);
    return GestureDetector(
      onTap: onTap == null ? null : () => onTap!(item.key),
      child: Opacity(
        opacity: item.selected ? 1 : 0.4,
        child: Container(
          width: 88,
          height: 50,
          decoration: BoxDecoration(
            color: palette.surfaceOverlay,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: item.selected ? palette.accent : palette.border,
              width: item.selected ? 1.5 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (path != null)
                Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  cacheWidth: 200,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              Positioned(
                left: 3,
                bottom: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  color: Colors.black54,
                  child: Text(
                    '${shot.number}',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ),
              if (item.repeated)
                Positioned(
                  right: 3,
                  top: 3,
                  child: Icon(Icons.repeat, size: 13, color: palette.warning),
                ),
              if (onSection != null)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Tooltip(
                    message: 'Sección de la planta',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onSection!(shot),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        color: Colors.black54,
                        child: Icon(
                          Icons.crop_free,
                          size: 14,
                          color: shot.planViewJson == null
                              ? Colors.white
                              : palette.accent,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
