import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/share_origin.dart';
import '../../core/utils/shot_reference_import.dart';
import '../../core/utils/user_error.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../shared/technical_script_export/technical_script_doc.dart';
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
  ExportOptions _options = const ExportOptions();
  ExportSelection _selection = const ExportSelection();
  bool _ready = false;
  bool _saving = false;

  Uint8List? _preview;
  Object? _previewError;
  bool _building = false;
  int _version = 0;
  Timer? _debounce;

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
      _options = options;
      _selection = selection;
      _ready = true;
    });
    _schedulePreview();
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

  void _schedulePreview() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _buildPreview);
  }

  Future<void> _buildPreview() async {
    final source = _source;
    if (source == null) return;
    final version = ++_version;
    if (!_canExport) {
      setState(() {
        _preview = null;
        _previewError = null;
        _building = false;
      });
      return;
    }
    setState(() => _building = true);
    try {
      final bytes = await ExportRunner(
        ref.read(databaseProvider),
        source,
        _settings,
      ).preview(_sections, _effective);
      if (!mounted || version != _version) return;
      setState(() {
        _preview = bytes;
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
    setState(() {
      _source = source;
      _selection = _selection.copyWith(blockIds: _allBlocks(source));
    });
    _schedulePreview();
  }

  void _openPreviewPage() {
    final bytes = _preview;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Vista previa')),
          body: bytes == null
              ? const Center(child: CircularProgressIndicator())
              : PdfViewer.data(
                  bytes,
                  sourceName: 'exportacion_$_version.pdf',
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
                      onPressed: _preview == null ? null : _openPreviewPage,
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
                  ),
                ],
              ],
            ),
    );
  }

  List<Widget> _format(AppPalette palette) {
    final canSplitDays = _selection.scope == ExportScope.days;
    final split = _effective.split;
    final body = switch (_options.document) {
      ExportDocument.storyboard => _storyboardFormat(palette),
      ExportDocument.shootingPlan => [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _options.planWithLight,
          onChanged: (v) => _setOptions(_options.copyWith(planWithLight: v)),
          title: const Text('Con luz'),
          subtitle: const Text('Apágalo para una planta solo de cámara.'),
        ),
      ],
      ExportDocument.technicalScript => _scriptFormat(palette),
    };
    return [
      ...body,
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

  List<Widget> _storyboardFormat(AppPalette palette) => [
    Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        for (final look in StoryboardLook.values)
          Tooltip(
            message: look.hint,
            child: ChoiceChip(
              label: Text(look.label),
              selected: _options.look == look,
              onSelected: (_) => _setOptions(_options.copyWith(look: look)),
            ),
          ),
      ],
    ),
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
    ];
  }

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
      content = PdfViewer.data(
        _preview!,
        key: ValueKey(_preview),
        sourceName: 'exportacion_$_version.pdf',
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
          if (_building && _preview != null)
            const Positioned(
              top: AppSpacing.md,
              right: AppSpacing.md,
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }
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

  const _ShotStrip({required this.shots, this.onTap});

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
            ],
          ),
        ),
      ),
    );
  }
}
