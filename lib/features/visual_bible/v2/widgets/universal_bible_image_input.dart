import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/clipboard_image_reader.dart';
import '../../../../core/utils/media_storage.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../bible_paste_helpers.dart';
import '../../widgets/moodboard_drag.dart';
import '../model/bible_image_content.dart';

/// Entrada universal de imagen para Biblia (legacy + v2).
///
/// Fuentes: paste, drag&drop moodboard, file picker, path local.
class UniversalBibleImageInput extends StatefulWidget {
  final int projectId;
  final BibleImageContent? value;
  final ValueChanged<BibleImageContent> onChanged;
  final VoidCallback? onClear;
  final String hint;
  final double minHeight;
  final bool autofocusForPaste;
  final bool showCropControls;

  const UniversalBibleImageInput({
    super.key,
    required this.projectId,
    required this.onChanged,
    this.value,
    this.onClear,
    this.hint = 'Arrastra, pega (⌘V) o elige una imagen',
    this.minHeight = 120,
    this.autofocusForPaste = false,
    this.showCropControls = true,
  });

  @override
  State<UniversalBibleImageInput> createState() =>
      _UniversalBibleImageInputState();
}

class _UniversalBibleImageInputState extends State<UniversalBibleImageInput> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
    if (widget.autofocusForPaste) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _applyBytes(
    Uint8List bytes,
    String extension, {
    String source = 'local',
  }) async {
    try {
      final path = await MediaStorage.writeProjectFileBytes(
        projectId: widget.projectId,
        subfolder: 'bible_images',
        bytes: bytes,
        fileName: 'img_${DateTime.now().millisecondsSinceEpoch}$extension',
      );
      widget.onChanged(
        (widget.value ?? const BibleImageContent()).copyWith(
          source: source,
          path: path,
          imageId: null,
        ),
      );
    } catch (_) {
      if (mounted) {
        AppSnackBar.show(
          context,
          'No se pudo guardar la imagen',
          isError: true,
        );
      }
    }
  }

  Future<void> _paste() async {
    final status = await BiblePasteHelpers.pasteFromClipboard(
      onPayload: (payload) => _applyBytes(payload.bytes, payload.extension),
    );
    if (!mounted) return;
    if (status != ClipboardImageReadStatus.success) {
      AppSnackBar.show(context, _pasteError(status), isError: true);
    }
  }

  String _pasteError(ClipboardImageReadStatus status) => switch (status) {
    ClipboardImageReadStatus.noImage => 'Copia una imagen y pulsa ⌘V.',
    ClipboardImageReadStatus.pluginUnavailable =>
      'Reinicia la app para activar el pegado.',
    ClipboardImageReadStatus.invalidUrl =>
      'La URL del portapapeles no es una imagen.',
    ClipboardImageReadStatus.downloadFailed =>
      'No se pudo descargar la imagen.',
    ClipboardImageReadStatus.success => '',
  };

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes != null) {
      final ext = file.extension != null ? '.${file.extension}' : '.jpg';
      await _applyBytes(bytes, ext);
      return;
    }
    final path = file.path;
    if (path == null) return;
    widget.onChanged(
      (widget.value ?? const BibleImageContent()).copyWith(
        source: 'local',
        path: path,
      ),
    );
  }

  Future<void> _onMoodboardDrop(MoodboardDragPayload payload) async {
    widget.onChanged(
      (widget.value ?? const BibleImageContent()).copyWith(
        source: 'moodboard',
        imageId: payload.moodboardImageId?.toString(),
        path: payload.imagePath,
        caption: payload.suggestedCaption,
      ),
    );
  }

  void _updateCrop(BibleImageCrop crop) {
    final current = widget.value;
    if (current == null) return;
    widget.onChanged(current.copyWith(crop: crop));
  }

  void _updateFit(String fit) {
    final current = widget.value;
    if (current == null) return;
    widget.onChanged(current.copyWith(fit: fit));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final value = widget.value;
    final hasImage = value?.path != null && value!.path!.isNotEmpty;

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final isPaste =
            (HardwareKeyboard.instance.isMetaPressed ||
                HardwareKeyboard.instance.isControlPressed) &&
            event.logicalKey == LogicalKeyboardKey.keyV;
        if (isPaste) {
          _paste();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: () => _focusNode.requestFocus(),
        child: BibleImageDropZone(
          onMoodboardDropped: _onMoodboardDrop,
          onBytesDropped: (bytes, _) => _applyBytes(bytes, '.png'),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            constraints: BoxConstraints(minHeight: widget.minHeight),
            decoration: BoxDecoration(
              color: palette.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _focusNode.hasFocus ? palette.accent : palette.border,
                width: _focusNode.hasFocus ? 1.5 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: hasImage
                ? _ImagePreview(
                    content: value,
                    palette: palette,
                    onReplace: _pickFile,
                    onPaste: _paste,
                    onClear: widget.onClear,
                    showCropControls: widget.showCropControls,
                    onCropChanged: _updateCrop,
                    onFitChanged: _updateFit,
                  )
                : _EmptyState(
                    hint: widget.hint,
                    palette: palette,
                    onPick: _pickFile,
                    onPaste: _paste,
                  ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String hint;
  final AppPalette palette;
  final VoidCallback onPick;
  final VoidCallback onPaste;

  const _EmptyState({
    required this.hint,
    required this.palette,
    required this.onPick,
    required this.onPaste,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 32,
            color: palette.textTertiary,
          ),
          const SizedBox(height: 8),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: AppTypography.caption(palette),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.folder_open, size: 16),
                label: const Text('Elegir'),
              ),
              TextButton.icon(
                onPressed: onPaste,
                icon: const Icon(Icons.content_paste, size: 16),
                label: const Text('Pegar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  final BibleImageContent content;
  final AppPalette palette;
  final VoidCallback onReplace;
  final VoidCallback onPaste;
  final VoidCallback? onClear;
  final bool showCropControls;
  final ValueChanged<BibleImageCrop> onCropChanged;
  final ValueChanged<String> onFitChanged;

  const _ImagePreview({
    required this.content,
    required this.palette,
    required this.onReplace,
    required this.onPaste,
    required this.onClear,
    required this.showCropControls,
    required this.onCropChanged,
    required this.onFitChanged,
  });

  BoxFit get _boxFit => switch (content.fit) {
    'contain' => BoxFit.contain,
    'fill' => BoxFit.fill,
    _ => BoxFit.cover,
  };

  @override
  Widget build(BuildContext context) {
    final path = content.path!;
    final file = File(path);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (file.existsSync())
                Image.file(
                  file,
                  fit: _boxFit,
                  alignment: Alignment(
                    content.positionX * 2 - 1,
                    content.positionY * 2 - 1,
                  ),
                )
              else
                const Center(child: Icon(Icons.broken_image_outlined)),
              if (content.overlayOpacity > 0)
                ColoredBox(
                  color: Colors.black.withValues(alpha: content.overlayOpacity),
                ),
              Positioned(
                right: 8,
                top: 8,
                child: Row(
                  children: [
                    _IconBtn(icon: Icons.content_paste, onTap: onPaste),
                    _IconBtn(icon: Icons.swap_horiz, onTap: onReplace),
                    if (onClear != null)
                      _IconBtn(icon: Icons.delete_outline, onTap: onClear!),
                  ],
                ),
              ),
              if (content.caption != null && content.caption!.isNotEmpty)
                Positioned(
                  left: 8,
                  bottom: 8,
                  right: 8,
                  child: Text(
                    content.caption!,
                    style: AppTypography.caption(
                      palette,
                    ).copyWith(color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
        if (showCropControls)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Fit', style: AppTypography.label(palette)),
                for (final fit in ['cover', 'contain', 'fill'])
                  ChoiceChip(
                    label: Text(fit),
                    selected: content.fit == fit,
                    onSelected: (_) => onFitChanged(fit),
                    visualDensity: VisualDensity.compact,
                  ),
                Text('Crop X', style: AppTypography.label(palette)),
                SizedBox(
                  width: 100,
                  child: Slider(
                    value: content.crop.x.clamp(0.0, 0.9),
                    onChanged: (v) => onCropChanged(
                      BibleImageCrop(
                        x: v,
                        y: content.crop.y,
                        width: content.crop.width,
                        height: content.crop.height,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}
