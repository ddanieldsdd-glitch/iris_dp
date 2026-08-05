import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'script_context_menu.dart';
import 'script_file_reader.dart';
import 'script_parser.dart';
import 'script_screenplay_layout.dart';
import 'script_selection_toolbar.dart';

enum _ScriptEntryKind { blank, pageBreak, slugline, screenplayLine, characterLine }

class _ScriptEntry {
  final _ScriptEntryKind kind;
  final double? height;
  final int? page;
  final RawSlugline? slug;
  final String? displayLine;
  final String? text;
  final int? charStartIndex;
  final ScreenplayLineKind? lineKind;
  final bool included;
  final bool isManualCharacter;
  final Color? sceneColor;
  final String? characterName;
  final Color? characterColor;

  const _ScriptEntry._({
    required this.kind,
    this.height,
    this.page,
    this.slug,
    this.displayLine,
    this.text,
    this.charStartIndex,
    this.lineKind,
    this.included = false,
    this.isManualCharacter = false,
    this.sceneColor,
    this.characterName,
    this.characterColor,
  });

  factory _ScriptEntry.blank(double height) => _ScriptEntry._(
        kind: _ScriptEntryKind.blank,
        height: height,
      );

  factory _ScriptEntry.pageBreak(int? page) => _ScriptEntry._(
        kind: _ScriptEntryKind.pageBreak,
        page: page,
      );

  factory _ScriptEntry.slugline({
    required RawSlugline slug,
    required String displayLine,
    required bool included,
    Color? sceneColor,
  }) =>
      _ScriptEntry._(
        kind: _ScriptEntryKind.slugline,
        slug: slug,
        displayLine: displayLine,
        included: included,
        sceneColor: sceneColor,
      );

  factory _ScriptEntry.screenplayLine({
    required String text,
    required ScreenplayLineKind lineKind,
    int? charStartIndex,
  }) =>
      _ScriptEntry._(
        kind: _ScriptEntryKind.screenplayLine,
        text: text,
        lineKind: lineKind,
        charStartIndex: charStartIndex,
      );

  factory _ScriptEntry.characterLine({
    required String text,
    required String characterName,
    required Color characterColor,
    int? charStartIndex,
    bool isManualCharacter = false,
  }) =>
      _ScriptEntry._(
        kind: _ScriptEntryKind.characterLine,
        text: text,
        lineKind: ScreenplayLineKind.character,
        characterName: characterName,
        characterColor: characterColor,
        charStartIndex: charStartIndex,
        isManualCharacter: isManualCharacter,
      );
}

/// Texto extraído del guion con formato cinematográfico y sluglines pulsables.
class ScriptScannedView extends StatefulWidget {
  final String text;
  final double fontSize;
  final ScrollController scrollController;
  final Set<int> includedStartIndices;
  final Map<int, Color> sceneColorsByStartIndex;
  final Map<String, Color> characterColorsByName;
  final Set<String> manualCharacterLines;
  final Map<String, String> lineTextOverrides;
  final ValueChanged<RawSlugline> onSluglineTap;
  final ValueChanged<String>? onCharacterTap;
  final Future<void> Function(ScriptLineContext line, ScriptContextAction action)?
      onLineContextAction;
  final ValueChanged<int?>? onActiveCharIndexChanged;
  final ValueChanged<ScriptTextSelection>? onTextSelectionChanged;

  const ScriptScannedView({
    super.key,
    required this.text,
    required this.fontSize,
    required this.scrollController,
    required this.includedStartIndices,
    this.sceneColorsByStartIndex = const {},
    this.characterColorsByName = const {},
    this.manualCharacterLines = const {},
    this.lineTextOverrides = const {},
    required this.onSluglineTap,
    this.onCharacterTap,
    this.onLineContextAction,
    this.onActiveCharIndexChanged,
    this.onTextSelectionChanged,
  });

  @override
  State<ScriptScannedView> createState() => ScriptScannedViewState();
}

class ScriptScannedViewState extends State<ScriptScannedView> {
  static const _paperColor = Color(0xFFF8F6F0);
  static const _inkColor = Color(0xFF1A1A1A);
  static const _lineHeight = 1.65;
  static const _innerMaxWidth = 680.0;

  List<_ScriptEntry>? _entries;
  TextStyle? _baseStyle;
  final Map<int, GlobalKey> _sluglineKeys = {};
  final List<int> _scrollAnchorIndices = [];

  @override
  void initState() {
    super.initState();
    _rebuildEntries();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  Future<void> scrollToCharIndex(int charIndex) async {
    GlobalKey? key;
    var nearestDistance = 1 << 30;
    for (final entry in _sluglineKeys.entries) {
      final distance = (entry.key - charIndex).abs();
      if (distance < nearestDistance) {
        nearestDistance = distance;
        key = entry.value;
      }
    }
    if (key?.currentContext != null) {
      await Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        alignment: 0.08,
      );
      return;
    }

    if (_scrollAnchorIndices.isEmpty) return;
    var targetListIndex = 0;
    for (var i = 0; i < _scrollAnchorIndices.length; i++) {
      if (_scrollAnchorIndices[i] <= charIndex) {
        targetListIndex = i;
      } else {
        break;
      }
    }
    final estimatedOffset = targetListIndex * widget.fontSize * _lineHeight * 1.2;
    if (widget.scrollController.hasClients) {
      await widget.scrollController.animateTo(
        estimatedOffset.clamp(
          0.0,
          widget.scrollController.position.maxScrollExtent,
        ),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onScroll() {
    if (!widget.scrollController.hasClients || _scrollAnchorIndices.isEmpty) {
      return;
    }
    final offset = widget.scrollController.offset + 48;
    var activeIndex = _scrollAnchorIndices.first;
    final lineHeight = widget.fontSize * _lineHeight;
    final approxLine = (offset / (lineHeight * 0.95)).floor();
    if (approxLine >= 0 && approxLine < _scrollAnchorIndices.length) {
      activeIndex = _scrollAnchorIndices[approxLine.clamp(
        0,
        _scrollAnchorIndices.length - 1,
      )];
    } else {
      for (final anchor in _scrollAnchorIndices) {
        if (anchor <= offset) activeIndex = anchor;
      }
    }
    widget.onActiveCharIndexChanged?.call(activeIndex);
  }

  @override
  void didUpdateWidget(covariant ScriptScannedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.fontSize != widget.fontSize ||
        oldWidget.includedStartIndices != widget.includedStartIndices ||
        oldWidget.sceneColorsByStartIndex != widget.sceneColorsByStartIndex ||
        oldWidget.characterColorsByName != widget.characterColorsByName ||
        oldWidget.manualCharacterLines != widget.manualCharacterLines ||
        oldWidget.lineTextOverrides != widget.lineTextOverrides) {
      _rebuildEntries();
    }
  }

  String _displayTextForLine(String rawLine) {
    return widget.lineTextOverrides[rawLine.trim()] ?? rawLine.trim();
  }

  bool _isManualCharacterLine(String trimmed) =>
      widget.manualCharacterLines.contains(trimmed);

  _ScriptEntry? _tryBuildCharacterEntry({
    required String rawLine,
    required String trimmed,
    required int charStartIndex,
    required bool forced,
  }) {
    final display = _displayTextForLine(rawLine);
    final parsedName =
        ScreenplayLineClassifier.parseCharacterName(display) ??
            ScreenplayLineClassifier.parseCharacterName(trimmed);
    final characterName = parsedName ?? display.toUpperCase();
    final colorKey = characterName.toUpperCase();
    final characterColor = widget.characterColorsByName[colorKey];
    if (characterColor == null && !forced) return null;

    return _ScriptEntry.characterLine(
      text: display,
      characterName: characterName,
      characterColor: characterColor ?? const Color(0xFF2997FF),
      charStartIndex: charStartIndex,
      isManualCharacter: forced || _isManualCharacterLine(trimmed),
    );
  }

  void _rebuildEntries() {
    _baseStyle = GoogleFonts.courierPrime(
      fontSize: widget.fontSize,
      height: _lineHeight,
      letterSpacing: 0.15,
      color: _inkColor,
    );

    final lines =
        widget.text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    final classifier = ScreenplayLineClassifier();
    final entries = <_ScriptEntry>[];
    var charIndex = 0;
    var pendingBlankLines = 0;

    void flushBlanks() {
      if (pendingBlankLines <= 0) return;
      final gap = widget.fontSize *
          _lineHeight *
          (pendingBlankLines == 1 ? 0.85 : 1.4);
      entries.add(_ScriptEntry.blank(gap));
      pendingBlankLines = 0;
    }

    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];
      final trimmed = line.trim();
      final lineStartIndex = charIndex;

      if (trimmed.isEmpty) {
        pendingBlankLines++;
        charIndex += line.length + 1;
        continue;
      }

      line = widget.lineTextOverrides[trimmed] ?? line;
      final displayTrimmed = line.trim();

      if (isScriptPageMarker(displayTrimmed)) {
        flushBlanks();
        classifier.reset();
        entries.add(_ScriptEntry.pageBreak(pageNumberFromMarker(trimmed)));
        charIndex += line.length + 1;
        continue;
      }

      flushBlanks();

      final end = (i + 4).clamp(0, lines.length);
      final attempt = ScriptParser.tryParseSluglineFromLines(
        lines,
        lineIndex: i,
        startIndex: charIndex,
        followingLines: lines.sublist(i + 1, end),
      );

      if (attempt != null) {
        classifier.reset();
        final slug = attempt.slugline;
        final included = widget.includedStartIndices.contains(slug.startIndex);
        final display = _displaySlugline(line, slug);
        final sceneColor = widget.sceneColorsByStartIndex[slug.startIndex];
        entries.add(_ScriptEntry.slugline(
          slug: slug,
          displayLine: display,
          included: included,
          sceneColor: sceneColor,
        ));
        i += attempt.linesConsumed - 1;
        charIndex += attempt.charactersConsumed;
        continue;
      }

      if (RegExp(r'^\d+\.?\s*$').hasMatch(displayTrimmed)) {
        entries.add(_ScriptEntry.screenplayLine(
          text: displayTrimmed,
          lineKind: ScreenplayLineKind.pageNumber,
          charStartIndex: lineStartIndex,
        ));
        charIndex += lines[i].length + 1;
        continue;
      }

      if (_isManualCharacterLine(trimmed)) {
        classifier.reset();
        final manualEntry = _tryBuildCharacterEntry(
          rawLine: lines[i],
          trimmed: trimmed,
          charStartIndex: lineStartIndex,
          forced: true,
        );
        if (manualEntry != null) {
          entries.add(manualEntry);
          charIndex += lines[i].length + 1;
          continue;
        }
      }

      final leadingSpaces = line.length - line.trimLeft().length;
      final kind = classifier.classifyLine(
        displayTrimmed,
        isSlugline: false,
        leadingSpaces: leadingSpaces,
      );
      if (kind == ScreenplayLineKind.blank) {
        charIndex += lines[i].length + 1;
        continue;
      }

      if (kind == ScreenplayLineKind.character) {
        final characterEntry = _tryBuildCharacterEntry(
          rawLine: lines[i],
          trimmed: trimmed,
          charStartIndex: lineStartIndex,
          forced: false,
        );
        if (characterEntry != null) {
          entries.add(characterEntry);
          charIndex += lines[i].length + 1;
          continue;
        }
      }

      entries.add(_ScriptEntry.screenplayLine(
        text: displayTrimmed,
        lineKind: kind,
        charStartIndex: lineStartIndex,
      ));
      charIndex += lines[i].length + 1;
    }

    flushBlanks();
    _entries = entries;
    _sluglineKeys.clear();
    _scrollAnchorIndices.clear();
    for (final entry in entries) {
      if (entry.charStartIndex != null) {
        _scrollAnchorIndices.add(entry.charStartIndex!);
      }
      if (entry.kind == _ScriptEntryKind.slugline && entry.slug != null) {
        _sluglineKeys.putIfAbsent(entry.slug!.startIndex, () => GlobalKey());
      }
    }
  }

  void _notifySelection({
    required String lineText,
    required TextSelection selection,
    int? charStartIndex,
    ScreenplayLineKind? lineKind,
  }) {
    if (selection.isCollapsed || widget.onTextSelectionChanged == null) return;
    final start = selection.start.clamp(0, lineText.length);
    final end = selection.end.clamp(0, lineText.length);
    if (start >= end) return;
    widget.onTextSelectionChanged!(ScriptTextSelection(
      selectedText: lineText.substring(start, end),
      lineText: lineText,
      charStartIndex:
          charStartIndex != null ? charStartIndex + start : null,
      charEndIndex: charStartIndex != null ? charStartIndex + end : null,
      lineKind: lineKind,
    ));
  }

  Future<void> _openContextMenu(
    BuildContext context,
    Offset globalPosition,
    _ScriptEntry entry,
  ) async {
    if (widget.onLineContextAction == null) return;

    final lineContext = switch (entry.kind) {
      _ScriptEntryKind.slugline => ScriptLineContext(
          lineText: entry.displayLine!,
          charStartIndex: entry.slug!.startIndex,
          lineKind: ScreenplayLineKind.slugline,
          slugline: entry.slug,
        ),
      _ScriptEntryKind.characterLine => ScriptLineContext(
          lineText: entry.text!,
          charStartIndex: entry.charStartIndex,
          lineKind: ScreenplayLineKind.character,
          characterName: entry.characterName,
          isManualCharacter: entry.isManualCharacter,
        ),
      _ScriptEntryKind.screenplayLine => ScriptLineContext(
          lineText: entry.text!,
          charStartIndex: entry.charStartIndex,
          lineKind: entry.lineKind,
        ),
      _ => null,
    };
    if (lineContext == null) return;

    final action = await showScriptContextMenu(
      context,
      globalPosition: globalPosition,
      line: lineContext,
    );
    if (action == null) return;
    await widget.onLineContextAction!(lineContext, action);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final baseStyle = _baseStyle!;
    final entries = _entries ?? [];

    return Scrollbar(
      controller: widget.scrollController,
      thumbVisibility: true,
      child: ListView.builder(
        controller: widget.scrollController,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        itemCount: 1,
        itemBuilder: (context, _) {
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _paperColor,
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
                    horizontal: 40,
                    vertical: 44,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: entries.length,
                    itemBuilder: (context, index) => _buildEntry(
                      context,
                      entries[index],
                      baseStyle,
                      palette,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEntry(
    BuildContext context,
    _ScriptEntry entry,
    TextStyle baseStyle,
    AppPalette palette,
  ) {
    return switch (entry.kind) {
      _ScriptEntryKind.blank => SizedBox(height: entry.height),
      _ScriptEntryKind.pageBreak => _PageBreak(page: entry.page, palette: palette),
      _ScriptEntryKind.slugline => _SluglineRow(
          key: _sluglineKeys[entry.slug!.startIndex],
          slug: entry.slug!,
          displayLine: entry.displayLine!,
          baseStyle: baseStyle,
          included: entry.included,
          sceneColor: entry.sceneColor,
          palette: palette,
          innerWidth: _innerMaxWidth,
          onTap: () => widget.onSluglineTap(entry.slug!),
          onSecondaryTap: widget.onLineContextAction == null
              ? null
              : (position) => _openContextMenu(context, position, entry),
          onLongPress: widget.onLineContextAction == null
              ? null
              : (position) => _openContextMenu(context, position, entry),
        ),
      _ScriptEntryKind.screenplayLine => _ScreenplayLine(
          text: entry.text!,
          kind: entry.lineKind!,
          style: entry.lineKind == ScreenplayLineKind.pageNumber
              ? baseStyle.copyWith(
                  fontSize: widget.fontSize * 0.9,
                  color: _inkColor.withValues(alpha: 0.55),
                )
              : _styleForKind(baseStyle, entry.lineKind!),
          innerWidth: _innerMaxWidth,
          onSecondaryTap: widget.onLineContextAction == null
              ? null
              : (position) => _openContextMenu(context, position, entry),
          onLongPress: widget.onLineContextAction == null
              ? null
              : (position) => _openContextMenu(context, position, entry),
          onSelectionChanged: widget.onTextSelectionChanged == null
              ? null
              : (selection, _) => _notifySelection(
                    lineText: entry.text!,
                    selection: selection,
                    charStartIndex: entry.charStartIndex,
                    lineKind: entry.lineKind,
                  ),
        ),
      _ScriptEntryKind.characterLine => _CharacterLineRow(
          text: entry.text!,
          characterName: entry.characterName!,
          color: entry.characterColor!,
          baseStyle: baseStyle,
          palette: palette,
          innerWidth: _innerMaxWidth,
          onTap: widget.onCharacterTap == null
              ? null
              : () => widget.onCharacterTap!(entry.characterName!),
          onSecondaryTap: widget.onLineContextAction == null
              ? null
              : (position) => _openContextMenu(context, position, entry),
          onLongPress: widget.onLineContextAction == null
              ? null
              : (position) => _openContextMenu(context, position, entry),
          onSelectionChanged: widget.onTextSelectionChanged == null
              ? null
              : (selection, _) => _notifySelection(
                    lineText: entry.text!,
                    selection: selection,
                    charStartIndex: entry.charStartIndex,
                    lineKind: ScreenplayLineKind.character,
                  ),
        ),
    };
  }

  static TextStyle _styleForKind(TextStyle base, ScreenplayLineKind kind) {
    return switch (kind) {
      ScreenplayLineKind.character => base.copyWith(fontWeight: FontWeight.w700),
      ScreenplayLineKind.transition => base.copyWith(fontWeight: FontWeight.w600),
      _ => base,
    };
  }

  static String _displaySlugline(String rawLine, RawSlugline slug) {
    final trimmed = rawLine.trim();
    if (slug.scriptNumber != null && !trimmed.contains('${slug.scriptNumber}')) {
      return '$trimmed  ${slug.scriptNumber}';
    }
    return trimmed.isEmpty ? slug.rawLine : trimmed;
  }
}

class _ScreenplayLine extends StatelessWidget {
  final String text;
  final ScreenplayLineKind kind;
  final TextStyle style;
  final double innerWidth;
  final ValueChanged<Offset>? onSecondaryTap;
  final ValueChanged<Offset>? onLongPress;
  final void Function(TextSelection selection, SelectionChangedCause? cause)?
      onSelectionChanged;

  const _ScreenplayLine({
    required this.text,
    required this.kind,
    required this.style,
    required this.innerWidth,
    this.onSecondaryTap,
    this.onLongPress,
    this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final margins = ScreenplayMargins.forKind(kind, innerWidth);
    return GestureDetector(
      onSecondaryTapUp: onSecondaryTap == null
          ? null
          : (details) => onSecondaryTap!(details.globalPosition),
      onLongPressStart: onLongPress == null
          ? null
          : (details) => onLongPress!(details.globalPosition),
      child: Padding(
        padding: EdgeInsets.only(
          left: margins.left,
          right: margins.right,
          bottom: kind == ScreenplayLineKind.character ? 2 : 0,
        ),
        child: SelectableText(
          text,
          style: style,
          onSelectionChanged: onSelectionChanged,
        ),
      ),
    );
  }
}

class _PageBreak extends StatelessWidget {
  final int? page;
  final AppPalette palette;

  const _PageBreak({required this.page, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Row(
        children: [
          Expanded(child: Divider(color: palette.divider)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              page != null ? 'Página $page' : '—',
              style: AppTypography.caption(palette),
            ),
          ),
          Expanded(child: Divider(color: palette.divider)),
        ],
      ),
    );
  }
}

class _SluglineRow extends StatelessWidget {
  final RawSlugline slug;
  final String displayLine;
  final TextStyle baseStyle;
  final bool included;
  final Color? sceneColor;
  final AppPalette palette;
  final double innerWidth;
  final VoidCallback onTap;
  final ValueChanged<Offset>? onSecondaryTap;
  final ValueChanged<Offset>? onLongPress;

  const _SluglineRow({
    super.key,
    required this.slug,
    required this.displayLine,
    required this.baseStyle,
    required this.included,
    required this.sceneColor,
    required this.palette,
    required this.innerWidth,
    required this.onTap,
    this.onSecondaryTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final accent = included ? sceneColor : null;
    final bg = included
        ? (accent ?? palette.accent).withValues(alpha: 0.18)
        : const Color(0xFFFFE8B3);
    final border = included
        ? (accent ?? palette.accent)
        : const Color(0xFFE6A800);
    final iconColor = included
        ? (accent ?? palette.accent)
        : const Color(0xFFB8860B);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: onTap,
          onSecondaryTapUp: onSecondaryTap == null
              ? null
              : (details) => onSecondaryTap!(details.globalPosition),
          onLongPress: onLongPress == null
              ? null
              : () {
                  final box = context.findRenderObject() as RenderBox?;
                  if (box == null) return;
                  onLongPress!(box.localToGlobal(Offset.zero));
                },
          child: Container(
            width: innerWidth,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: border.withValues(alpha: 0.6)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  included ? Icons.edit_outlined : Icons.add_circle_outline,
                  size: 16,
                  color: iconColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    displayLine,
                    style: baseStyle.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (slug.scriptNumber != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${slug.scriptNumber}',
                    style: AppTypography.mono(palette).copyWith(
                      fontSize: baseStyle.fontSize,
                      color: iconColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CharacterLineRow extends StatelessWidget {
  final String text;
  final String characterName;
  final Color color;
  final TextStyle baseStyle;
  final AppPalette palette;
  final double innerWidth;
  final VoidCallback? onTap;
  final ValueChanged<Offset>? onSecondaryTap;
  final ValueChanged<Offset>? onLongPress;
  final void Function(TextSelection selection, SelectionChangedCause? cause)?
      onSelectionChanged;

  const _CharacterLineRow({
    required this.text,
    required this.characterName,
    required this.color,
    required this.baseStyle,
    required this.palette,
    required this.innerWidth,
    this.onTap,
    this.onSecondaryTap,
    this.onLongPress,
    this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final margins = ScreenplayMargins.forKind(
      ScreenplayLineKind.character,
      innerWidth,
    );
    final bg = color.withValues(alpha: 0.2);
    final border = color;

    return Padding(
      padding: EdgeInsets.only(
        left: margins.left,
        right: margins.right,
        bottom: 2,
      ),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: onTap,
          onSecondaryTapUp: onSecondaryTap == null
              ? null
              : (details) => onSecondaryTap!(details.globalPosition),
          onLongPress: onLongPress == null
              ? null
              : () {
                  final box = context.findRenderObject() as RenderBox?;
                  if (box == null) return;
                  onLongPress!(box.localToGlobal(Offset.zero));
                },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: border.withValues(alpha: 0.55)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: border,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    text,
                    style: baseStyle.copyWith(fontWeight: FontWeight.w700),
                    onSelectionChanged: onSelectionChanged,
                  ),
                ),
                if (onTap != null)
                  Icon(
                    Icons.palette_outlined,
                    size: 14,
                    color: border,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
