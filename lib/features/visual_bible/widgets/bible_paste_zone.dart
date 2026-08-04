import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/clipboard_image_reader.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../bible_paste_helpers.dart';
import 'moodboard_drag.dart';

/// Zona activable con clic: arrastra refs del moodboard o ⌘V para pegar.
class BibleTargetZone extends StatefulWidget {
  final String hint;
  final String activeHint;
  final double minHeight;
  final Widget? child;
  final Future<void> Function(ClipboardImagePayload payload) onPaste;
  final Future<void> Function(MoodboardDragPayload payload)? onMoodboardDropped;

  const BibleTargetZone({
    super.key,
    required this.hint,
    required this.onPaste,
    this.activeHint = 'Pulsa ⌘V para pegar aquí',
    this.minHeight = 56,
    this.child,
    this.onMoodboardDropped,
  });

  @override
  State<BibleTargetZone> createState() => _BibleTargetZoneState();
}

class _BibleTargetZoneState extends State<BibleTargetZone> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handlePaste() async {
    final status = await BiblePasteHelpers.pasteFromClipboard(
      onPayload: widget.onPaste,
    );
    if (!mounted) return;
    if (status != ClipboardImageReadStatus.success) {
      AppSnackBar.show(
        context,
        _pasteErrorMessage(status),
        isError: true,
      );
    } else {
      AppSnackBar.show(context, 'Imagen pegada');
    }
  }

  String _pasteErrorMessage(ClipboardImageReadStatus status) =>
      switch (status) {
        ClipboardImageReadStatus.downloadFailed =>
          'No se pudo descargar la imagen del portapapeles.',
        ClipboardImageReadStatus.invalidUrl =>
          'La URL del portapapeles no parece ser una imagen.',
        ClipboardImageReadStatus.noImage =>
          'Copia una imagen (ShotDeck → Copiar imagen) y pulsa ⌘V.',
        ClipboardImageReadStatus.pluginUnavailable =>
          'Reinicia la app para activar el pegado de imágenes.',
        ClipboardImageReadStatus.success => '',
      };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final focused = _focusNode.hasFocus;

    Widget inner = widget.child ??
        Container(
          constraints: BoxConstraints(minHeight: widget.minHeight),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: focused ? palette.accent : palette.divider,
              width: focused ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: focused
                ? palette.accent.withValues(alpha: 0.08)
                : palette.surfaceOverlay.withValues(alpha: 0.35),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                focused ? Icons.content_paste : Icons.touch_app_outlined,
                size: 16,
                color: focused ? palette.accent : palette.textTertiary,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  focused ? widget.activeHint : widget.hint,
                  style: AppTypography.caption(palette).copyWith(
                    color: focused ? palette.accent : palette.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );

    inner = BibleImageDropZone(
      onMoodboardDropped: widget.onMoodboardDropped,
      onBytesDropped: (bytes, _) async {
        await widget.onPaste(
          ClipboardImagePayload(bytes: bytes, extension: '.png'),
        );
      },
      child: inner,
    );

    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.keyV, LogicalKeyboardKey.meta):
            const _BiblePasteIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyV, LogicalKeyboardKey.control):
            const _BiblePasteIntent(),
      },
      child: Actions(
        actions: {
          _BiblePasteIntent: CallbackAction<_BiblePasteIntent>(
            onInvoke: (_) {
              _handlePaste();
              return null;
            },
          ),
        },
        child: Focus(
          focusNode: _focusNode,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _focusNode.requestFocus(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: focused && widget.child != null
                  ? BoxDecoration(
                      border: Border.all(color: palette.accent, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    )
                  : null,
              child: inner,
            ),
          ),
        ),
      ),
    );
  }
}

class _BiblePasteIntent extends Intent {
  const _BiblePasteIntent();
}
