import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'open_script_file.dart';
import 'script_file_reader.dart';
import 'script_parser.dart';
import 'script_pdf_viewer.dart';
import 'script_preview_controller.dart';
import 'script_scanned_view.dart';
import 'script_context_menu.dart';
import 'script_selection_toolbar.dart';
import '../../core/widgets/app_snackbar.dart';

enum ScriptPreviewMode { original, scanned }

/// Visor del guion: documento original o texto escaneado con sluglines pulsables.
class ScriptPreviewPanel extends StatefulWidget {
  static const defaultFontSize = 14.0;

  final LoadedScript? script;
  final ScriptPreviewController? controller;
  final Set<int> includedSceneStartIndices;
  final Map<int, Color> sceneColorsByStartIndex;
  final Map<String, Color> characterColorsByName;
  final Set<String> manualCharacterLines;
  final Map<String, String> lineTextOverrides;
  final ValueChanged<RawSlugline>? onSluglineTap;
  final ValueChanged<String>? onCharacterTap;
  final Future<void> Function(ScriptLineContext line, ScriptContextAction action)?
      onLineContextAction;
  final ValueChanged<int?>? onActiveCharIndexChanged;
  final VoidCallback? onFullscreenRequest;
  final bool showFullscreenButton;
  final bool isFullscreen;
  final List<String> existingCharacterNames;

  const ScriptPreviewPanel({
    super.key,
    this.script,
    this.controller,
    this.includedSceneStartIndices = const {},
    this.sceneColorsByStartIndex = const {},
    this.characterColorsByName = const {},
    this.manualCharacterLines = const {},
    this.lineTextOverrides = const {},
    this.onSluglineTap,
    this.onCharacterTap,
    this.onLineContextAction,
    this.onActiveCharIndexChanged,
    this.onFullscreenRequest,
    this.showFullscreenButton = true,
    this.isFullscreen = false,
    this.existingCharacterNames = const [],
  });

  @override
  State<ScriptPreviewPanel> createState() => _ScriptPreviewPanelState();
}

class _ScriptPreviewPanelState extends State<ScriptPreviewPanel> {
  static const _minFontSize = 11.0;
  static const _maxFontSize = 22.0;

  static const _paperColor = Color(0xFFF8F6F0);
  static const _inkColor = Color(0xFF1A1A1A);

  ScriptPreviewController? _ownedController;
  ScriptPreviewController get _ctrl =>
      widget.controller ?? _ownedController!;

  ScriptPreviewMode get _mode => _ctrl.mode;
  double get _fontSize => _ctrl.fontSize;

  final _selectionLink = LayerLink();
  OverlayEntry? _selectionOverlay;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _ownedController = ScriptPreviewController();
    }
  }

  @override
  void dispose() {
    _removeSelectionOverlay();
    _ownedController?.dispose();
    super.dispose();
  }

  void _removeSelectionOverlay() {
    _selectionOverlay?.remove();
    _selectionOverlay = null;
  }

  void _setMode(ScriptPreviewMode mode) {
    setState(() => _ctrl.mode = mode);
  }

  void _setFontSize(double size) {
    setState(() => _ctrl.fontSize = size);
  }

  void _handleTextSelection(ScriptTextSelection selection) {
    if (_mode != ScriptPreviewMode.scanned) return;
    _removeSelectionOverlay();
    _selectionOverlay = showScriptSelectionOverlay(
      context: context,
      layerLink: _selectionLink,
      toolbar: ScriptSelectionToolbar(
        selection: selection,
        existingCharacters: widget.existingCharacterNames,
        onDismiss: _removeSelectionOverlay,
        onAction: (action) async {
          final line = selection.toLineContext();
          await widget.onLineContextAction?.call(line, action);
          _removeSelectionOverlay();
        },
        onAssignExistingCharacter: (name) async {
          await widget.onLineContextAction?.call(
            selection.toLineContext().copyWithCharacterName(name),
            ScriptContextAction.markAsCharacter,
          );
          _removeSelectionOverlay();
        },
      ),
    );
  }

  @override
  void didUpdateWidget(ScriptPreviewPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.script?.path != widget.script?.path) {
      _setFontSize(ScriptPreviewPanel.defaultFontSize);
      _setMode(ScriptPreviewMode.scanned);
    }
  }

  Future<void> _openExternally(String path) async {
    final ok = await openScriptInSystemApp(path);
    if (!ok && mounted) {
      AppSnackBar.show(context, 'No se pudo abrir el archivo en otra aplicación.');
    }
  }

  bool get _canScan =>
      widget.script != null && widget.script!.displayText.trim().isNotEmpty;

  bool get _showTextZoom =>
      _mode == ScriptPreviewMode.scanned ||
      widget.script?.kind == ScriptFileKind.text ||
      widget.script?.kind == ScriptFileKind.docx;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final script = widget.script;

    if (script == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined,
                color: palette.textTertiary, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text(
              'El guion aparecerá aquí',
              style: AppTypography.bodyMedium(palette),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Text(
                'Podrás leer el original o el texto escaneado y pulsar '
                'escenas que falten en la lista.',
                style: AppTypography.caption(palette),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PreviewToolbar(
          palette: palette,
          fileName: script.fileName,
          mode: _mode,
          canScan: _canScan,
          fontSize: _fontSize,
          showTextZoom: _showTextZoom,
          showFullscreenButton: widget.showFullscreenButton && !widget.isFullscreen,
          onModeChanged: _setMode,
          onZoomIn: () =>
              _setFontSize((_fontSize + 1).clamp(_minFontSize, _maxFontSize)),
          onZoomOut: () =>
              _setFontSize((_fontSize - 1).clamp(_minFontSize, _maxFontSize)),
          onResetZoom: () => _setFontSize(ScriptPreviewPanel.defaultFontSize),
          onOpenExternally: () => _openExternally(script.path),
          onFullscreen: widget.onFullscreenRequest,
        ),
        if (_mode == ScriptPreviewMode.scanned) ...[
          Divider(height: 1, color: palette.divider),
          _ScannedLegend(
            palette: palette,
            characterColors: widget.characterColorsByName,
          ),
        ],
        Divider(height: 1, color: palette.divider),
        Expanded(
          child: CompositedTransformTarget(
            link: _selectionLink,
            child: _buildDocumentView(script),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentView(LoadedScript script) {
    if (!_canScan && script.kind == ScriptFileKind.pdf) {
      return ScriptPdfViewer(path: script.path);
    }

    if (!_canScan) {
      return switch (script.kind) {
        ScriptFileKind.text => _PlainTextDocumentView(
            path: script.path,
            fontSize: _fontSize,
            scrollController: _ctrl.textScrollController,
          ),
        ScriptFileKind.docx => _DocxReferenceView(
            path: script.path,
            fallbackText: script.displayText,
            fontSize: _fontSize,
            scrollController: _ctrl.textScrollController,
            onOpenExternally: () => _openExternally(script.path),
          ),
        _ => const SizedBox.shrink(),
      };
    }

    // Mantener ambas vistas vivas para no perder scroll / página al cambiar modo.
    return IndexedStack(
      index: _mode == ScriptPreviewMode.scanned ? 1 : 0,
      sizing: StackFit.expand,
      children: [
        if (script.kind == ScriptFileKind.pdf)
          ScriptPdfViewer(path: script.path)
        else if (script.kind == ScriptFileKind.text)
          _PlainTextDocumentView(
            path: script.path,
            fontSize: _fontSize,
            scrollController: _ctrl.textScrollController,
          )
        else if (script.kind == ScriptFileKind.docx)
          _DocxReferenceView(
            path: script.path,
            fallbackText: script.displayText,
            fontSize: _fontSize,
            scrollController: _ctrl.textScrollController,
            onOpenExternally: () => _openExternally(script.path),
          )
        else
          const SizedBox.shrink(),
        ScriptScannedView(
          key: _ctrl.scannedViewKey,
          text: script.displayText,
          fontSize: _fontSize,
          scrollController: _ctrl.scannedScrollController,
          includedStartIndices: widget.includedSceneStartIndices,
          sceneColorsByStartIndex: widget.sceneColorsByStartIndex,
          characterColorsByName: widget.characterColorsByName,
          manualCharacterLines: widget.manualCharacterLines,
          lineTextOverrides: widget.lineTextOverrides,
          onSluglineTap: widget.onSluglineTap ?? (_) {},
          onCharacterTap: widget.onCharacterTap,
          onLineContextAction: widget.onLineContextAction,
          onActiveCharIndexChanged: widget.onActiveCharIndexChanged,
          onTextSelectionChanged: _handleTextSelection,
        ),
      ],
    );
  }
}

class _PreviewToolbar extends StatelessWidget {
  final AppPalette palette;
  final String fileName;
  final ScriptPreviewMode mode;
  final bool canScan;
  final double fontSize;
  final bool showTextZoom;
  final bool showFullscreenButton;
  final ValueChanged<ScriptPreviewMode> onModeChanged;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onResetZoom;
  final VoidCallback onOpenExternally;
  final VoidCallback? onFullscreen;

  const _PreviewToolbar({
    required this.palette,
    required this.fileName,
    required this.mode,
    required this.canScan,
    required this.fontSize,
    required this.showTextZoom,
    required this.showFullscreenButton,
    required this.onModeChanged,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onResetZoom,
    required this.onOpenExternally,
    this.onFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.auto_stories_outlined,
                  color: palette.accent, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  fileName,
                  style: AppTypography.label(palette),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                onPressed: onOpenExternally,
                icon: Icon(Icons.open_in_new,
                    color: palette.accent, size: 16),
                label: Text(
                  'Abrir fuera',
                  style: AppTypography.caption(palette)
                      .copyWith(color: palette.accent),
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
              if (showFullscreenButton && onFullscreen != null)
                IconButton(
                  tooltip: 'Pantalla completa',
                  icon: Icon(Icons.fullscreen, color: palette.accent, size: 20),
                  onPressed: onFullscreen,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (canScan)
            SegmentedButton<ScriptPreviewMode>(
              segments: const [
                ButtonSegment(
                  value: ScriptPreviewMode.original,
                  label: Text('Original'),
                  icon: Icon(Icons.picture_as_pdf_outlined, size: 16),
                ),
                ButtonSegment(
                  value: ScriptPreviewMode.scanned,
                  label: Text('Escaneado'),
                  icon: Icon(Icons.document_scanner_outlined, size: 16),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (values) => onModeChanged(values.first),
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  mode == ScriptPreviewMode.scanned
                      ? 'Selecciona texto o clic derecho para marcar personajes y escenas'
                      : 'Lectura fiel del documento',
                  style: AppTypography.caption(palette),
                ),
              ),
              if (showTextZoom) ...[
                Text(
                  '${fontSize.toInt()}pt',
                  style: AppTypography.caption(palette),
                ),
                IconButton(
                  tooltip: 'Reducir texto',
                  icon: Icon(Icons.remove,
                      color: palette.textSecondary, size: 18),
                  onPressed: onZoomOut,
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  tooltip: 'Ampliar texto',
                  icon:
                      Icon(Icons.add, color: palette.textSecondary, size: 18),
                  onPressed: onZoomIn,
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  tooltip: 'Tamaño predeterminado',
                  icon: Icon(Icons.fit_screen,
                      color: palette.textSecondary, size: 18),
                  onPressed: onResetZoom,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ScannedLegend extends StatelessWidget {
  final AppPalette palette;
  final Map<String, Color> characterColors;

  const _ScannedLegend({
    required this.palette,
    this.characterColors = const {},
  });

  @override
  Widget build(BuildContext context) {
    final sortedCharacters = characterColors.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: [
              _legendChip(
                palette,
                const Color(0xFFFFE8B3),
                Icons.add_circle_outline,
                'Escena pendiente',
              ),
              _legendChip(
                palette,
                palette.accent.withValues(alpha: 0.18),
                Icons.edit_outlined,
                'Escena en la lista',
              ),
              _legendChip(
                palette,
                palette.surfaceOverlay,
                Icons.touch_app_outlined,
                'Selecciona texto o clic derecho / pulsación larga',
              ),
            ],
          ),
          if (sortedCharacters.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('Personajes', style: AppTypography.caption(palette)),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final entry in sortedCharacters)
                  _characterLegendChip(palette, entry.key, entry.value),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _characterLegendChip(AppPalette palette, String name, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(name, style: AppTypography.caption(palette)),
        ],
      ),
    );
  }

  Widget _legendChip(
    AppPalette palette,
    Color bg,
    IconData icon,
    String label,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: palette.textSecondary),
          const SizedBox(width: 6),
          Text(label, style: AppTypography.caption(palette)),
        ],
      ),
    );
  }
}

class _PlainTextDocumentView extends StatelessWidget {
  final String path;
  final double fontSize;
  final ScrollController scrollController;

  const _PlainTextDocumentView({
    required this.path,
    required this.fontSize,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: File(path).readAsString(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'No se pudo leer el archivo: ${snapshot.error}',
              style: AppTypography.bodyMedium(context.palette),
              textAlign: TextAlign.center,
            ),
          );
        }

        return _ReadingSurface(
          scrollController: scrollController,
          child: SelectableText(
            snapshot.data ?? '',
            style: GoogleFonts.courierPrime(
              fontSize: fontSize,
              height: 1.65,
              letterSpacing: 0.2,
              color: _ScriptPreviewPanelState._inkColor,
            ),
          ),
        );
      },
    );
  }
}

class _DocxReferenceView extends StatelessWidget {
  final String path;
  final String fallbackText;
  final double fontSize;
  final ScrollController scrollController;
  final VoidCallback onOpenExternally;

  const _DocxReferenceView({
    required this.path,
    required this.fallbackText,
    required this.fontSize,
    required this.scrollController,
    required this.onOpenExternally,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: palette.surfaceElevated,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: palette.accent, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Para leer el Word con su formato original, ábrelo en '
                    'Word o Pages. Usa la vista Escaneado para marcar escenas.',
                    style: AppTypography.caption(palette),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                TextButton(
                  onPressed: onOpenExternally,
                  child: Text(
                    'Abrir en Word',
                    style: AppTypography.caption(palette)
                        .copyWith(color: palette.accent),
                  ),
                ),
              ],
            ),
          ),
        ),
        Divider(height: 1, color: palette.divider),
        Expanded(
          child: _ReadingSurface(
            scrollController: scrollController,
            child: SelectableText(
              fallbackText,
              style: GoogleFonts.courierPrime(
                fontSize: fontSize,
                height: 1.65,
                letterSpacing: 0.2,
                color: _ScriptPreviewPanelState._inkColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReadingSurface extends StatelessWidget {
  final ScrollController scrollController;
  final Widget child;

  const _ReadingSurface({
    required this.scrollController,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: scrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _ScriptPreviewPanelState._paperColor,
                borderRadius: BorderRadius.circular(4),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 56,
                  vertical: 48,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
