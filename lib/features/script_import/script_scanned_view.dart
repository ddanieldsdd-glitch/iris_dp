import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'script_file_reader.dart';
import 'script_parser.dart';
import 'script_screenplay_layout.dart';

enum _ScriptEntryKind { blank, pageBreak, slugline, screenplayLine }

class _ScriptEntry {
  final _ScriptEntryKind kind;
  final double? height;
  final int? page;
  final RawSlugline? slug;
  final String? displayLine;
  final String? text;
  final ScreenplayLineKind? lineKind;
  final bool included;
  final Color? sceneColor;

  const _ScriptEntry._({
    required this.kind,
    this.height,
    this.page,
    this.slug,
    this.displayLine,
    this.text,
    this.lineKind,
    this.included = false,
    this.sceneColor,
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
  }) =>
      _ScriptEntry._(
        kind: _ScriptEntryKind.screenplayLine,
        text: text,
        lineKind: lineKind,
      );
}

/// Texto extraído del guion con formato cinematográfico y sluglines pulsables.
class ScriptScannedView extends StatefulWidget {
  final String text;
  final double fontSize;
  final ScrollController scrollController;
  final Set<int> includedStartIndices;
  final Map<int, Color> sceneColorsByStartIndex;
  final ValueChanged<RawSlugline> onSluglineTap;

  const ScriptScannedView({
    super.key,
    required this.text,
    required this.fontSize,
    required this.scrollController,
    required this.includedStartIndices,
    this.sceneColorsByStartIndex = const {},
    required this.onSluglineTap,
  });

  @override
  State<ScriptScannedView> createState() => _ScriptScannedViewState();
}

class _ScriptScannedViewState extends State<ScriptScannedView> {
  static const _paperColor = Color(0xFFF8F6F0);
  static const _inkColor = Color(0xFF1A1A1A);
  static const _lineHeight = 1.65;
  static const _innerMaxWidth = 680.0;

  List<_ScriptEntry>? _entries;
  TextStyle? _baseStyle;

  @override
  void initState() {
    super.initState();
    _rebuildEntries();
  }

  @override
  void didUpdateWidget(covariant ScriptScannedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.fontSize != widget.fontSize ||
        oldWidget.includedStartIndices != widget.includedStartIndices ||
        oldWidget.sceneColorsByStartIndex != widget.sceneColorsByStartIndex) {
      _rebuildEntries();
    }
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
      final line = lines[i];
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        pendingBlankLines++;
        charIndex += line.length + 1;
        continue;
      }

      if (isScriptPageMarker(trimmed)) {
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

      if (RegExp(r'^\d+\.?\s*$').hasMatch(trimmed)) {
        entries.add(_ScriptEntry.screenplayLine(
          text: trimmed,
          lineKind: ScreenplayLineKind.pageNumber,
        ));
        charIndex += line.length + 1;
        continue;
      }

      final leadingSpaces = line.length - line.trimLeft().length;
      final kind = classifier.classifyLine(
        trimmed,
        isSlugline: false,
        leadingSpaces: leadingSpaces,
      );
      if (kind == ScreenplayLineKind.blank) {
        charIndex += line.length + 1;
        continue;
      }

      entries.add(_ScriptEntry.screenplayLine(text: trimmed, lineKind: kind));
      charIndex += line.length + 1;
    }

    flushBlanks();
    _entries = entries;
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
                    itemBuilder: (context, index) =>
                        _buildEntry(context, entries[index], baseStyle, palette),
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
          slug: entry.slug!,
          displayLine: entry.displayLine!,
          baseStyle: baseStyle,
          included: entry.included,
          sceneColor: entry.sceneColor,
          palette: palette,
          innerWidth: _innerMaxWidth,
          onTap: () => widget.onSluglineTap(entry.slug!),
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

  const _ScreenplayLine({
    required this.text,
    required this.kind,
    required this.style,
    required this.innerWidth,
  });

  @override
  Widget build(BuildContext context) {
    final margins = ScreenplayMargins.forKind(kind, innerWidth);
    return Padding(
      padding: EdgeInsets.only(
        left: margins.left,
        right: margins.right,
        bottom: kind == ScreenplayLineKind.character ? 2 : 0,
      ),
      child: SelectableText(
        text,
        style: style,
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

  const _SluglineRow({
    required this.slug,
    required this.displayLine,
    required this.baseStyle,
    required this.included,
    required this.sceneColor,
    required this.palette,
    required this.innerWidth,
    required this.onTap,
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
                  included ? Icons.check_circle_outline : Icons.add_circle_outline,
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
