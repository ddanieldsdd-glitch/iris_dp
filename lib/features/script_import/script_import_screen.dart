import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/character_colors.dart';
import '../../core/utils/color_edit_scope.dart';
import '../../core/utils/media_storage.dart';
import '../../core/utils/project_scene_colors.dart';
import '../../core/utils/scene_color.dart';
import '../../core/utils/scene_characters.dart';
import '../../core/utils/scene_format.dart';
import '../../core/utils/user_error.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/scene_character_chips.dart';
import '../../core/widgets/scene_meta_display.dart';
import '../technical_script/technical_script_screen.dart';
import 'import_scene_sheet.dart';
import 'normalized_scene.dart';
import 'script_character_extractor.dart';
import 'character_color_sheet.dart';
import 'script_file_reader.dart';
import 'script_parser.dart';
import 'script_preview_panel.dart';
import 'script_scene_mapper.dart';
import '../../core/widgets/app_snackbar.dart';

class _SceneListItem {
  final String id;
  NormalizedScene data;
  final int? sourceStartIndex;

  _SceneListItem({
    required this.id,
    required this.data,
    this.sourceStartIndex,
  });

  factory _SceneListItem.from(
    NormalizedScene scene, {
    int? sourceStartIndex,
  }) =>
      _SceneListItem(
        id: const Uuid().v4(),
        data: scene,
        sourceStartIndex: sourceStartIndex,
      );
}

class ScriptImportScreen extends ConsumerStatefulWidget {
  final int projectId;
  const ScriptImportScreen({super.key, required this.projectId});

  @override
  ConsumerState<ScriptImportScreen> createState() => _ScriptImportScreenState();
}

class _ScriptImportScreenState extends ConsumerState<ScriptImportScreen> {
  final List<_SceneListItem> _scenes = [];
  bool _loading = false;
  bool _initializing = true;
  bool _projectHasSyncedScenes = false;
  String _status = '';
  LoadedScript? _loadedScript;
  final Map<String, String> _pendingSetColors = {};
  final Map<String, String> _characterColors = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadWorkspace());
  }

  Future<void> _loadWorkspace() async {
    setState(() {
      _loading = true;
      _initializing = true;
    });

    try {
      final db = ref.read(databaseProvider);
      final project = await db.getProject(widget.projectId);
      final dbScenes = await db.watchScenesForProject(widget.projectId).first;
      final sites = await db.watchSitesForProject(widget.projectId).first;
      final siteNameById = {for (final s in sites) s.id: s.name};
      _projectHasSyncedScenes = dbScenes.isNotEmpty;

      if (project?.scriptFilePath != null &&
          File(project!.scriptFilePath!).existsSync()) {
        final loaded = await ScriptFileReader.load(project.scriptFilePath!);
        setState(() {
          _loadedScript = loaded;
          _characterColors
            ..clear()
            ..addAll(decodeCharacterColors(project.characterColorsJson));
          _syncCharacterColorsFromScript(loaded.parseText);
          _scenes.clear();
          for (final scene in dbScenes) {
            final siteName = scene.locationSiteId != null
                ? siteNameById[scene.locationSiteId] ?? scene.locationPureName
                : scene.locationPureName;
            _scenes.add(_SceneListItem.from(
              normalizedSceneFromDb(scene, locationSiteName: siteName),
              sourceStartIndex: scene.sourceStartIndex,
            ));
          }
          _status = dbScenes.isEmpty
              ? 'Guion cargado. Consulta el PDF o el texto escaneado y añade escenas.'
              : '${dbScenes.length} escenas sincronizadas con el guion técnico.';
          _syncPendingColorsFromScenes();
        });
      } else if (_projectHasSyncedScenes) {
        setState(() {
          _status =
              'Hay escenas en el guion técnico pero falta el archivo del guion. '
              'Selecciona el PDF o Word de referencia.';
        });
      }
    } catch (e) {
      setState(() => _status = userFriendlyError(e));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _initializing = false;
        });
      }
    }
  }

  Future<void> _persistScriptReference(
    String sourcePath,
    LoadedScript loaded,
  ) async {
    final storedPath = await MediaStorage.copyProjectScript(
      projectId: widget.projectId,
      sourcePath: sourcePath,
    );
    final db = ref.read(databaseProvider);
    final project = await db.getProject(widget.projectId);
    if (project != null) {
      await db.updateProject(project.copyWith(
        scriptFilePath: Value(storedPath),
        scriptFileName: Value(loaded.fileName),
        updatedAt: DateTime.now(),
      ));
    }

    setState(() {
      _loadedScript = LoadedScript(
        path: storedPath,
        fileName: loaded.fileName,
        kind: loaded.kind,
        displayText: loaded.displayText,
      );
    });
  }

  void _setScenesFromNormalized(
    List<NormalizedScene> scenes, {
    List<RawSlugline>? sluglines,
  }) {
    _scenes.clear();
    for (var i = 0; i < scenes.length; i++) {
      final startIndex =
          sluglines != null && i < sluglines.length ? sluglines[i].startIndex : null;
      _scenes.add(_SceneListItem.from(scenes[i], sourceStartIndex: startIndex));
    }
    _renumberScenes();
    _syncPendingColorsFromScenes();
  }

  void _syncPendingColorsFromScenes() {
    _pendingSetColors
      ..clear()
      ..addAll(buildPendingSetColorsFromScenes(
        _scenes.map(
          (item) => (
            locationSite: item.data.locationSite,
            shootSet: item.data.shootSet,
          ),
        ),
      ));
  }

  void _syncCharacterColorsFromScript(String scriptText) {
    final fromScript =
        ScriptCharacterExtractor.extractAllCharacterNames(scriptText);
    final fromScenes = _scenes
        .expand((item) => item.data.characters)
        .map(characterColorKey);
    final allNames = {...fromScript, ...fromScenes};
    _characterColors.addAll(
      buildDefaultCharacterColors(allNames, preserve: _characterColors),
    );
  }

  Map<String, Color> get _characterColorMap => {
        for (final entry in _characterColors.entries)
          entry.key: characterDisplayColor(entry.value),
      };

  Future<void> _persistCharacterColors() async {
    final db = ref.read(databaseProvider);
    final project = await db.getProject(widget.projectId);
    if (project == null) return;
    await db.updateProject(project.copyWith(
      characterColorsJson: Value(encodeCharacterColors(_characterColors)),
      updatedAt: DateTime.now(),
    ));
  }

  Future<void> _onCharacterTap(String characterName) async {
    final key = characterColorKey(characterName);
    final currentHex = _characterColors[key];
    final result = await showCharacterColorSheet(
      context,
      characterName: characterName,
      currentHex: currentHex,
    );
    if (result == null) return;

    setState(() {
      _characterColors[key] = result;
    });
    await _persistCharacterColors();
  }

  Set<int> get _includedStartIndices => {
        for (final item in _scenes)
          if (item.sourceStartIndex != null) item.sourceStartIndex!,
      };

  ProjectSceneColors _colorContext(
    List<LocationBasePlan> locations,
    List<LocationSite> sites,
  ) {
    return ProjectSceneColors(
      locations: locations,
      sites: sites,
      pendingSetColors: _pendingSetColors,
    );
  }

  Map<int, Color> _sluglineColors(ProjectSceneColors ctx) {
    return ctx.colorsBySourceStartIndex(
      scenes: _scenes.map(
        (item) => (
          sourceStartIndex: item.sourceStartIndex,
          shootSet: item.data.shootSet,
          sceneColorOverride: item.data.locationColor,
          locationSite: item.data.locationSite,
        ),
      ),
    );
  }

  int _siteIndexForName(String locationSite) {
    final siteKey = locationSite.trim().toLowerCase();
    final order = <String>[];
    for (final item in _scenes) {
      final key = item.data.locationSite.trim().toLowerCase();
      if (!order.contains(key)) order.add(key);
    }
    final idx = order.indexOf(siteKey);
    return idx >= 0 ? idx : order.length;
  }

  void _applySetColor(String locationSite, String shootSet, String hex) {
    final key = setColorKey(locationSite, shootSet);
    _pendingSetColors[key] = hex;
    final setKey = shootSet.trim().toLowerCase();
    for (var i = 0; i < _scenes.length; i++) {
      final scene = _scenes[i].data;
      if (scene.shootSet.trim().toLowerCase() == setKey &&
          scene.locationSite.trim().toLowerCase() ==
              locationSite.trim().toLowerCase()) {
        _scenes[i].data = scene.copyWith(locationColor: null);
      }
    }
  }

  void _applyLocationColor(String locationSite, String baseHex) {
    final siteKey = locationSite.trim().toLowerCase();
    final setNames = <String>{};
    for (final item in _scenes) {
      if (item.data.locationSite.trim().toLowerCase() == siteKey) {
        setNames.add(item.data.shootSet);
      }
    }
    _pendingSetColors.addAll(
      pendingSetColorsForSite(
        locationSite: locationSite,
        setNames: setNames,
        siteIndex: _siteIndexForName(locationSite),
        baseHex: baseHex,
      ),
    );
    for (var i = 0; i < _scenes.length; i++) {
      if (_scenes[i].data.locationSite.trim().toLowerCase() == siteKey) {
        _scenes[i].data = _scenes[i].data.copyWith(locationColor: null);
      }
    }
  }

  void _handleSceneEditResult(
    ImportSceneEditResult result, {
    int? replaceIndex,
    int? sourceStartIndex,
  }) {
    NormalizedScene sceneData = result.scene;
    switch (result.colorScope) {
      case ColorEditScope.scene:
        sceneData = result.scene.copyWith(
          locationColor: persistSceneColor(result.setColor),
        );
      case ColorEditScope.set:
        _applySetColor(
          result.scene.locationSite,
          result.scene.shootSet,
          result.setColor,
        );
        sceneData = result.scene.copyWith(locationColor: null);
      case ColorEditScope.location:
        _applyLocationColor(result.scene.locationSite, result.setColor);
        sceneData = result.scene.copyWith(locationColor: null);
    }

    if (replaceIndex != null) {
      _scenes[replaceIndex].data =
          sceneData.copyWith(number: replaceIndex + 1);
      _renumberScenes();
    } else {
      _insertScene(sceneData, sourceStartIndex: sourceStartIndex);
    }
  }

  Future<void> _pickAndProcess({bool detectScenes = true}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'txt', 'fountain', 'fdx'],
    );
    if (result == null || result.files.single.path == null) return;

    await _processScriptAtPath(
      result.files.single.path!,
      detectScenes: detectScenes,
    );
  }

  Future<void> _pickAndReplaceScript() async {
    await _pickAndProcess(detectScenes: false);
  }

  Future<void> _rescanScript() async {
    if (_loadedScript == null) return;

    if (_scenes.isNotEmpty && mounted) {
      final palette = context.palette;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: palette.surfaceElevated,
          title: Text('Detectar escenas de nuevo',
              style: AppTypography.titleLarge(palette)),
          content: Text(
            'La detección automática sustituirá la lista actual de escenas. '
            'El guion de referencia no cambia; puedes seguir editando escenas '
            'manualmente después.',
            style: AppTypography.bodyLarge(palette),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child:
                  Text('Cancelar', style: AppTypography.bodyMedium(palette)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Detectar',
                  style: AppTypography.bodyMedium(palette)
                      .copyWith(color: palette.accent)),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    await _processScriptAtPath(_loadedScript!.path, detectScenes: true);
  }

  Future<void> _processScriptAtPath(
    String path, {
    required bool detectScenes,
  }) async {
    setState(() {
      _loading = true;
      _status = 'Leyendo guion...';
    });

    try {
      final loaded = await ScriptFileReader.load(path);
      await _persistScriptReference(path, loaded);

      if (!detectScenes) {
        setState(() {
          _syncCharacterColorsFromScript(loaded.parseText);
          _status =
              'Guion de referencia actualizado. Las escenas del proyecto se mantienen.';
          _loading = false;
        });
        await _persistCharacterColors();
        return;
      }

      final sluglines = ScriptParser.parse(loaded.parseText);

      if (sluglines.isEmpty) {
        setState(() {
          if (detectScenes) _scenes.clear();
          _loading = false;
          _status =
              'No se encontraron escenas. Revisa el guion o añádelas manualmente.';
        });
        return;
      }

      setState(() =>
          _status = 'Detectando escenas (${sluglines.length})...');

      final charactersByStart = ScriptCharacterExtractor.extractBySlugStartIndex(
        loaded.parseText,
        sluglines,
      );

      final scenes = sluglines.map(NormalizedScene.fromRaw).toList();
      final scenesWithCharacters = ScriptCharacterExtractor.attachToScenes(
        scenes,
        sluglines,
        charactersByStart,
      );

      setState(() {
        _setScenesFromNormalized(scenesWithCharacters, sluglines: sluglines);
        _syncCharacterColorsFromScript(loaded.parseText);
        _status = 'Detectadas ${scenesWithCharacters.length} escenas.';
        _loading = false;
      });
      await _persistCharacterColors();
    } catch (e) {
      setState(() {
        _loading = false;
        _status = userFriendlyError(e);
      });
    }
  }

  void _renumberScenes() {
    for (var i = 0; i < _scenes.length; i++) {
      _scenes[i].data = _scenes[i].data.copyWith(number: i + 1);
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _scenes.removeAt(oldIndex);
      _scenes.insert(newIndex, item);
      _renumberScenes();
    });
  }

  int _scenesInSetCount(String shootSet) {
    final key = shootSet.trim().toLowerCase();
    return _scenes
        .where((s) => s.data.shootSet.trim().toLowerCase() == key)
        .length;
  }

  int _setsInSiteCount(String locationSite) {
    final key = locationSite.trim().toLowerCase();
    final sets = <String>{};
    for (final item in _scenes) {
      if (item.data.locationSite.trim().toLowerCase() == key) {
        sets.add(item.data.shootSet.trim().toLowerCase());
      }
    }
    return sets.length;
  }

  Future<void> _onSluglineTap(
    RawSlugline slug,
    ProjectSceneColors colorCtx,
  ) async {
    final existingIndex =
        _scenes.indexWhere((s) => s.sourceStartIndex == slug.startIndex);
    if (existingIndex >= 0) {
      await _editScene(existingIndex, colorCtx);
      return;
    }

    final nextNumber = slug.scriptNumber ?? _scenes.length + 1;
    var prefilled = NormalizedScene.fromRaw(
      slug.copyWith(number: nextNumber),
    );
    if (_loadedScript != null) {
      final charactersByStart =
          ScriptCharacterExtractor.extractBySlugStartIndex(
        _loadedScript!.parseText,
        [slug],
      );
      prefilled = prefilled.copyWith(
        characters: charactersByStart[slug.startIndex] ?? const [],
      );
    }

    final result = await showImportSceneSheet(
      context,
      scene: prefilled,
      nextNumber: nextNumber,
      colorContext: colorCtx,
      scenesInSet: _scenesInSetCount(prefilled.shootSet),
      setsInSite: _setsInSiteCount(prefilled.locationSite),
    );
    if (result == null) return;

    setState(() => _handleSceneEditResult(
          result,
          sourceStartIndex: slug.startIndex,
        ));
  }

  void _insertScene(NormalizedScene scene, {int? sourceStartIndex}) {
    final item = _SceneListItem.from(scene, sourceStartIndex: sourceStartIndex);
    var insertAt = _scenes.length;
    for (var i = 0; i < _scenes.length; i++) {
      if (scene.number < _scenes[i].data.number) {
        insertAt = i;
        break;
      }
    }
    _scenes.insert(insertAt, item);
    _renumberScenes();
  }

  Future<void> _addScene(ProjectSceneColors colorCtx) async {
    final result = await showImportSceneSheet(
      context,
      nextNumber: _scenes.length + 1,
      colorContext: colorCtx,
    );
    if (result == null) return;
    setState(() => _handleSceneEditResult(result));
  }

  Future<void> _editScene(int index, ProjectSceneColors colorCtx) async {
    final data = _scenes[index].data;
    final result = await showImportSceneSheet(
      context,
      scene: data,
      nextNumber: data.number,
      colorContext: colorCtx,
      scenesInSet: _scenesInSetCount(data.shootSet),
      setsInSite: _setsInSiteCount(data.locationSite),
    );
    if (result == null) return;
    setState(() => _handleSceneEditResult(result, replaceIndex: index));
  }

  Future<void> _deleteScene(int index) async {
    final palette = context.palette;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: palette.surfaceElevated,
        title: Text('Eliminar escena', style: AppTypography.titleLarge(palette)),
        content: Text(
          '¿Quitar esta escena de la lista de importación?',
          style: AppTypography.bodyLarge(palette),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: AppTypography.bodyMedium(palette)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Eliminar',
                style: AppTypography.bodyMedium(palette)
                    .copyWith(color: palette.error)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() {
      _scenes.removeAt(index);
      _renumberScenes();
    });
  }

  Future<void> _syncScenes() async {
    if (_scenes.isEmpty) return;

    final db = ref.read(databaseProvider);
    final sourceIndices =
        _scenes.map((item) => item.sourceStartIndex).toList(growable: false);

    final scenesWithShots = await db.findScenesWithShotsToRemoveOnSync(
      widget.projectId,
      sourceIndices,
      _scenes.length,
    );

    if (scenesWithShots.isNotEmpty && mounted) {
      final palette = context.palette;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: palette.surfaceElevated,
          title: Text('Escenas con planos', style: AppTypography.titleLarge(palette)),
          content: Text(
            '${scenesWithShots.length} escena(s) dejarán de existir y se '
            'eliminarán sus planos del guion técnico. ¿Continuar?',
            style: AppTypography.bodyLarge(palette),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancelar', style: AppTypography.bodyMedium(palette)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Sincronizar',
                  style: AppTypography.bodyMedium(palette)
                      .copyWith(color: palette.accent)),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    } else if (_projectHasSyncedScenes && mounted) {
      final palette = context.palette;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: palette.surfaceElevated,
          title: Text('Sincronizar escenas', style: AppTypography.titleLarge(palette)),
          content: Text(
            'Se actualizará el guion técnico con el orden y los datos actuales '
            'de esta lista. Los planos de escenas que sigan presentes se conservan.',
            style: AppTypography.bodyLarge(palette),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancelar', style: AppTypography.bodyMedium(palette)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Sincronizar',
                  style: AppTypography.bodyMedium(palette)
                      .copyWith(color: palette.accent)),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() => _loading = true);

    try {
      final items = _scenes
          .map(
            (item) => (
              intExt: item.data.intExt,
              dayNight: item.data.dayNight,
              location: item.data.location,
              shootSet: item.data.shootSet,
              locationSite: item.data.locationSite,
              name: item.data.name,
              description: item.data.description,
              locationColor: item.data.locationColor,
              charactersJson: encodeSceneCharacters(item.data.characters),
              sourceStartIndex: item.sourceStartIndex,
            ),
          )
          .toList(growable: false);

      await db.syncScenesFromWorkspace(widget.projectId, items);
      _syncPendingColorsFromScenes();
      final siteBySetKey = {
        for (final item in _scenes)
          setColorKey(item.data.locationSite, item.data.shootSet):
              item.data.locationSite.trim(),
      };
      await db.syncSetColorsFromWorkspace(
        widget.projectId,
        Map.from(_pendingSetColors),
        siteBySetKey,
      );
      await db.syncLocationsFromScenes(widget.projectId);

      if (!mounted) return;
      setState(() {
        _loading = false;
        _projectHasSyncedScenes = true;
        _status = '${_scenes.length} escenas sincronizadas con el guion técnico.';
      });

      AppSnackBar.show(context, 'Guion técnico actualizado.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppSnackBar.show(context, userFriendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final hasScript = _loadedScript != null;
    final db = ref.watch(databaseProvider);

    if (_initializing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder<List<LocationSite>>(
      stream: db.watchSitesForProject(widget.projectId),
      builder: (context, siteSnap) {
        return StreamBuilder<List<LocationBasePlan>>(
          stream: db.watchLocationsForProject(widget.projectId),
          builder: (context, locSnap) {
            final colorCtx = _colorContext(
              locSnap.data ?? [],
              siteSnap.data ?? [],
            );
            final slugColors = _sluglineColors(colorCtx);

            return Scaffold(
          appBar: AppBar(
            backgroundColor: palette.surface,
            title:
                Text('Guion literario', style: AppTypography.titleLarge(palette)),
            actions: [
              if (_projectHasSyncedScenes)
                TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          TechnicalScriptScreen(projectId: widget.projectId),
                    ),
                  ),
                  icon: Icon(Icons.table_rows, color: palette.accent, size: 18),
                  label: Text(
                    'Guion técnico',
                    style: AppTypography.caption(palette)
                        .copyWith(color: palette.accent),
                  ),
                ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= AppLayout.wideBreakpoint;

              if (!hasScript) {
                return _buildPickerState(palette, colorCtx, slugColors);
              }

              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 11,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border:
                              Border(right: BorderSide(color: palette.divider)),
                        ),
                        child: ScriptPreviewPanel(
                          script: _loadedScript,
                          includedSceneStartIndices: _includedStartIndices,
                          sceneColorsByStartIndex: slugColors,
                          characterColorsByName: _characterColorMap,
                          onSluglineTap: (slug) =>
                              _onSluglineTap(slug, colorCtx),
                          onCharacterTap: _onCharacterTap,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 9,
                      child: _buildScenesPanel(palette, colorCtx),
                    ),
                  ],
                );
              }

              return DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    TabBar(
                      labelColor: palette.accent,
                      unselectedLabelColor: palette.textSecondary,
                      indicatorColor: palette.accent,
                      tabs: const [
                        Tab(text: 'Guion de referencia'),
                        Tab(text: 'Escenas del proyecto'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          ScriptPreviewPanel(
                            script: _loadedScript,
                            includedSceneStartIndices: _includedStartIndices,
                            sceneColorsByStartIndex: slugColors,
                            characterColorsByName: _characterColorMap,
                            onSluglineTap: (slug) =>
                                _onSluglineTap(slug, colorCtx),
                            onCharacterTap: _onCharacterTap,
                          ),
                          _buildScenesPanel(palette, colorCtx),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
          },
        );
      },
    );
  }

  Widget _buildPickerState(
    AppPalette palette,
    ProjectSceneColors colorCtx,
    Map<int, Color> slugColors,
  ) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ScriptPreviewPanel(
              script: _loadedScript,
              includedSceneStartIndices: _includedStartIndices,
              sceneColorsByStartIndex: slugColors,
              characterColorsByName: _characterColorMap,
              onSluglineTap: (slug) => _onSluglineTap(slug, colorCtx),
              onCharacterTap: _onCharacterTap,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Seleccionar guion (PDF, Word, TXT, Fountain)',
            icon: Icons.upload_file,
            onTap: _loading ? null : _pickAndProcess,
            loading: _loading,
          ),
          if (_status.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(_status, style: AppTypography.bodyMedium(palette)),
          ],
        ],
      ),
    );
  }

  Widget _buildScenesPanel(AppPalette palette, ProjectSceneColors colorCtx) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppButton(
            label: 'Cambiar guion',
            icon: Icons.upload_file,
            variant: AppButtonVariant.secondary,
            onTap: _loading ? null : _pickAndReplaceScript,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  _loadedScript?.fileName ?? '',
                  style: AppTypography.bodyMedium(palette),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppButton(
                label: 'Detectar escenas',
                icon: Icons.refresh,
                variant: AppButtonVariant.secondary,
                onTap: _loading ? null : _rescanScript,
                loading: _loading,
              ),
            ],
          ),
          if (_status.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(_status, style: AppTypography.bodyMedium(palette)),
          ],
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Text(
                  _scenes.isEmpty
                      ? 'Sin escenas'
                      : '${_scenes.length} escenas',
                  style: AppTypography.titleMedium(palette),
                ),
              ),
              TextButton.icon(
                onPressed: _loading ? null : () => _addScene(colorCtx),
                icon: Icon(Icons.add, color: palette.accent, size: 18),
                label: Text('Añadir escena',
                    style: AppTypography.label(palette)
                        .copyWith(color: palette.accent)),
              ),
            ],
          ),
          if (_scenes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Arrastra para reordenar. Este orden define el guion técnico. '
              'La detección automática es solo una ayuda inicial.',
              style: AppTypography.caption(palette),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: _scenes.isEmpty
                ? Center(
                    child: Text(
                      'Consulta el guion (Original o Escaneado) y pulsa escenas '
                      'o personajes para marcarlos. «Detectar escenas» es solo una ayuda.',
                      style: AppTypography.bodyMedium(palette),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    itemCount: _scenes.length,
                    onReorder: _onReorder,
                    itemBuilder: (context, i) => _sceneCard(
                          palette,
                          colorCtx,
                          i,
                          key: ValueKey(_scenes[i].id),
                        ),
                  ),
          ),
          if (_scenes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: _projectHasSyncedScenes
                  ? 'Sincronizar ${_scenes.length} escenas'
                  : 'Importar ${_scenes.length} escenas',
              icon: Icons.sync,
              onTap: _syncScenes,
              loading: _loading,
            ),
          ],
        ],
      ),
    );
  }

  Widget _sceneCard(
    AppPalette palette,
    ProjectSceneColors colorCtx,
    int i, {
    required Key key,
  }) {
    final s = _scenes[i].data;
    final color = colorCtx.effective(
      shootSet: s.shootSet,
      sceneColorOverride: s.locationColor,
      locationSite: s.locationSite,
    );

    return AppCard(
      key: key,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReorderableDragStartListener(
            index: i,
            child: Padding(
              padding: const EdgeInsets.only(right: 8, top: 2),
              child: Icon(Icons.drag_handle,
                  color: palette.textTertiary, size: 22),
            ),
          ),
          Container(
            width: 4,
            height: 44,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text('${s.number}.',
              style: AppTypography.mono(palette)
                  .copyWith(color: palette.accent)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (s.name != null &&
                    s.name!.trim().isNotEmpty &&
                    !isAutoGeneratedSceneName(
                      name: s.name,
                      intExt: s.intExt,
                      dayNight: s.dayNight,
                      location: s.location,
                    )) ...[
                  Text(
                    s.name!,
                    style: AppTypography.label(palette),
                  ),
                  const SizedBox(height: 2),
                ],
                SceneMetaDisplay(
                  intExt: s.intExt,
                  dayNight: s.dayNight,
                  location: s.location,
                  style: AppTypography.bodyLarge(palette),
                ),
                if (s.shootSet != s.location || s.locationSite != s.shootSet)
                  Text(
                    '${s.locationSite} › ${s.shootSet}',
                    style: AppTypography.caption(palette)
                        .copyWith(color: palette.accent),
                  ),
                if (s.characters.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  SceneCharacterChips(
                    characters: s.characters,
                    palette: palette,
                    compact: true,
                    characterColors: _characterColorMap,
                  ),
                ],
                if (s.description != null && s.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    s.description!,
                    style: AppTypography.caption(palette),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Editar',
            icon: Icon(Icons.edit_outlined,
                color: palette.textSecondary, size: 18),
            onPressed: () => _editScene(i, colorCtx),
          ),
          IconButton(
            tooltip: 'Eliminar',
            icon: Icon(Icons.delete_outline, color: palette.error, size: 18),
            onPressed: () => _deleteScene(i),
          ),
        ],
      ),
    );
  }
}
