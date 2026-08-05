import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'script_file_reader.dart';
import 'script_parser.dart';
import 'script_preview_panel.dart';
import 'script_preview_controller.dart';
import 'script_scene_index_panel.dart';
import 'script_context_menu.dart';

/// Abre el visor de guion a pantalla completa con índice de escenas.
Future<void> showScriptFullscreenReader({
  required BuildContext context,
  required ScriptPreviewController controller,
  required LoadedScript script,
  required Set<int> includedSceneStartIndices,
  required Map<int, Color> sceneColorsByStartIndex,
  required Map<String, Color> characterColorsByName,
  required Set<String> manualCharacterLines,
  required Map<String, String> lineTextOverrides,
  required List<ScriptSceneIndexEntry> sceneIndexEntries,
  ValueChanged<RawSlugline>? onSluglineTap,
  ValueChanged<String>? onCharacterTap,
  Future<void> Function(ScriptLineContext line, ScriptContextAction action)?
      onLineContextAction,
  ValueChanged<int>? onActiveSceneIndexChanged,
  ValueChanged<int>? onEditScene,
}) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      opaque: true,
      fullscreenDialog: true,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => _ScriptFullscreenReaderPage(
        controller: controller,
        script: script,
        includedSceneStartIndices: includedSceneStartIndices,
        sceneColorsByStartIndex: sceneColorsByStartIndex,
        characterColorsByName: characterColorsByName,
        manualCharacterLines: manualCharacterLines,
        lineTextOverrides: lineTextOverrides,
        sceneIndexEntries: sceneIndexEntries,
        onSluglineTap: onSluglineTap,
        onCharacterTap: onCharacterTap,
        onLineContextAction: onLineContextAction,
        onActiveSceneIndexChanged: onActiveSceneIndexChanged,
        onEditScene: onEditScene,
      ),
      transitionsBuilder: (_, animation, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
    ),
  );
}

class _ScriptFullscreenReaderPage extends StatefulWidget {
  final ScriptPreviewController controller;
  final LoadedScript script;
  final Set<int> includedSceneStartIndices;
  final Map<int, Color> sceneColorsByStartIndex;
  final Map<String, Color> characterColorsByName;
  final Set<String> manualCharacterLines;
  final Map<String, String> lineTextOverrides;
  final List<ScriptSceneIndexEntry> sceneIndexEntries;
  final ValueChanged<RawSlugline>? onSluglineTap;
  final ValueChanged<String>? onCharacterTap;
  final Future<void> Function(ScriptLineContext line, ScriptContextAction action)?
      onLineContextAction;
  final ValueChanged<int>? onActiveSceneIndexChanged;
  final ValueChanged<int>? onEditScene;

  const _ScriptFullscreenReaderPage({
    required this.controller,
    required this.script,
    required this.includedSceneStartIndices,
    required this.sceneColorsByStartIndex,
    required this.characterColorsByName,
    required this.manualCharacterLines,
    required this.lineTextOverrides,
    required this.sceneIndexEntries,
    this.onSluglineTap,
    this.onCharacterTap,
    this.onLineContextAction,
    this.onActiveSceneIndexChanged,
    this.onEditScene,
  });

  @override
  State<_ScriptFullscreenReaderPage> createState() =>
      _ScriptFullscreenReaderPageState();
}

class _ScriptFullscreenReaderPageState extends State<_ScriptFullscreenReaderPage> {
  bool _showIndex = true;

  int? _sceneIndexForCharIndex(int? charIndex) {
    if (charIndex == null || widget.sceneIndexEntries.isEmpty) return null;
    int? bestSceneIndex;
    int? bestDistance;
    for (final entry in widget.sceneIndexEntries) {
      final start = entry.sourceStartIndex;
      if (start == null || start > charIndex) continue;
      final distance = charIndex - start;
      if (bestDistance == null || distance < bestDistance) {
        bestDistance = distance;
        bestSceneIndex = entry.sceneIndex;
      }
    }
    return bestSceneIndex ??
        widget.sceneIndexEntries.last.sceneIndex;
  }

  void _handleActiveCharIndex(int? charIndex) {
    final sceneIndex = _sceneIndexForCharIndex(charIndex);
    if (widget.controller.activeSceneIndex != sceneIndex) {
      setState(() => widget.controller.activeSceneIndex = sceneIndex);
      if (sceneIndex != null) {
        widget.onActiveSceneIndexChanged?.call(sceneIndex);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      backgroundColor: palette.surface,
      appBar: AppBar(
        backgroundColor: palette.surface,
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Salir de pantalla completa',
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lectura del guion',
              style: AppTypography.titleMedium(palette),
            ),
            Text(
              widget.script.fileName,
              style: AppTypography.caption(palette),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _showIndex ? 'Ocultar índice' : 'Mostrar índice',
            icon: Icon(
              _showIndex ? Icons.view_sidebar : Icons.view_sidebar_outlined,
              color: palette.accent,
            ),
            onPressed: () => setState(() => _showIndex = !_showIndex),
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ScriptPreviewPanel(
              controller: widget.controller,
              script: widget.script,
              includedSceneStartIndices: widget.includedSceneStartIndices,
              sceneColorsByStartIndex: widget.sceneColorsByStartIndex,
              characterColorsByName: widget.characterColorsByName,
              manualCharacterLines: widget.manualCharacterLines,
              lineTextOverrides: widget.lineTextOverrides,
              onSluglineTap: widget.onSluglineTap,
              onCharacterTap: widget.onCharacterTap,
              onLineContextAction: widget.onLineContextAction,
              onActiveCharIndexChanged: _handleActiveCharIndex,
              showFullscreenButton: false,
              isFullscreen: true,
              existingCharacterNames:
                  widget.characterColorsByName.keys.toList(growable: false),
            ),
          ),
          if (_showIndex)
            SizedBox(
              width: wide ? 320 : 280,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: palette.divider)),
                  color: palette.surfaceElevated,
                ),
                child: ScriptSceneIndexPanel(
                  entries: widget.sceneIndexEntries,
                  activeSceneIndex: widget.controller.activeSceneIndex,
                  compact: !wide,
                  onSceneTap: (entry) {
                    final start = entry.sourceStartIndex;
                    if (start != null) {
                      widget.controller.scrollToSluglineStartIndex(start);
                      setState(() =>
                          widget.controller.activeSceneIndex = entry.sceneIndex);
                    }
                  },
                  onEditActiveScene: widget.controller.activeSceneIndex != null
                      ? () => widget.onEditScene
                          ?.call(widget.controller.activeSceneIndex!)
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
