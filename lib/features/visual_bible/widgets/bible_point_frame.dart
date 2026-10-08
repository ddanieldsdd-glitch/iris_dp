import '../../../shared/visual_bible/bible_section_fields.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/visual_bible/bible_point_extras.dart';
import 'bible_point_images.dart';

/// Marca que un panel está dentro de un [BiblePointFrame]: deja libre la
/// esquina donde va el menú «⋯» del punto.
class BiblePointFrameScope extends InheritedWidget {
  const BiblePointFrameScope({super.key, required super.child});

  /// Hueco que el menú ocupa a la derecha de la cabecera del panel.
  static const double menuWidth = 32;

  static bool isIn(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BiblePointFrameScope>() !=
      null;

  @override
  bool updateShouldNotify(BiblePointFrameScope oldWidget) => false;
}

enum _PointAction { duplicate, images, text, remove, widthFull, widthTwoThirds, widthHalf, widthThird }

/// Marco común de un punto de la biblia: su menú «⋯» (duplicar, añadir
/// imágenes, añadir texto complementario, eliminar) y, bajo el punto, los
/// complementos que tenga.
class BiblePointFrame extends StatelessWidget {
  final int projectId;
  final int bibleId;
  final String sectionId;
  final BiblePointExtras extras;
  final ValueChanged<BiblePointExtras> onExtrasChanged;

  /// `null` si el punto no se puede duplicar.
  final VoidCallback? onDuplicate;
  final VoidCallback onRemove;

  /// Ancho actual del punto y cómo cambiarlo; sin [onWidthChanged] el menú
  /// no lo ofrece.
  final BiblePointWidth width;
  final ValueChanged<BiblePointWidth>? onWidthChanged;
  final Widget child;

  const BiblePointFrame({
    super.key,
    required this.projectId,
    required this.bibleId,
    required this.sectionId,
    required this.extras,
    required this.onExtrasChanged,
    required this.onRemove,
    required this.child,
    this.onDuplicate,
    this.width = BiblePointWidth.full,
    this.onWidthChanged,
  });

  Future<void> _pickImages(BuildContext context) async {
    final picked = await showMoodboardImagePicker(
      context,
      projectId: projectId,
      bibleId: bibleId,
      sectionId: sectionId,
      selected: extras.imageIds,
    );
    if (picked != null) onExtrasChanged(extras.withImages(picked));
  }

  void _run(BuildContext context, _PointAction action) {
    switch (action) {
      case _PointAction.duplicate:
        onDuplicate?.call();
      case _PointAction.images:
        _pickImages(context);
      case _PointAction.text:
        onExtrasChanged(extras.withText(extras.hasText ? null : ''));
      case _PointAction.remove:
        onRemove();
      case _PointAction.widthFull:
        onWidthChanged?.call(BiblePointWidth.full);
      case _PointAction.widthTwoThirds:
        onWidthChanged?.call(BiblePointWidth.twoThirds);
      case _PointAction.widthHalf:
        onWidthChanged?.call(BiblePointWidth.half);
      case _PointAction.widthThird:
        onWidthChanged?.call(BiblePointWidth.third);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    PopupMenuItem<_PointAction> item(
      _PointAction action,
      IconData icon,
      String label, {
      bool enabled = true,
      Color? color,
    }) => PopupMenuItem(
      value: action,
      enabled: enabled,
      child: Row(
        children: [
          Icon(icon, size: 16, color: color ?? palette.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              label,
              style: color == null ? null : TextStyle(color: color),
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            BiblePointFrameScope(child: child),
            Positioned(
              top: AppSpacing.sm,
              right: AppSpacing.sm,
              child: PopupMenuButton<_PointAction>(
                tooltip: 'Opciones del punto',
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.more_horiz,
                  size: 18,
                  color: palette.textSecondary,
                ),
                onSelected: (action) => _run(context, action),
                itemBuilder: (_) => [
                  item(
                    _PointAction.images,
                    Icons.add_photo_alternate_outlined,
                    extras.imageIds.isEmpty
                        ? 'Añadir imágenes'
                        : 'Cambiar imágenes',
                  ),
                  item(
                    _PointAction.text,
                    Icons.notes_outlined,
                    extras.hasText
                        ? 'Quitar texto complementario'
                        : 'Añadir texto complementario',
                  ),
                  if (onWidthChanged != null) ...[
                    const PopupMenuDivider(),
                    for (final (action, w) in const [
                      (_PointAction.widthFull, BiblePointWidth.full),
                      (_PointAction.widthTwoThirds, BiblePointWidth.twoThirds),
                      (_PointAction.widthHalf, BiblePointWidth.half),
                      (_PointAction.widthThird, BiblePointWidth.third),
                    ])
                      item(
                        action,
                        w == width
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        'Ancho: ${w.label.toLowerCase()}',
                      ),
                  ],
                  const PopupMenuDivider(),
                  item(
                    _PointAction.duplicate,
                    Icons.copy_outlined,
                    'Duplicar',
                    enabled: onDuplicate != null,
                  ),
                  item(
                    _PointAction.remove,
                    Icons.delete_outline,
                    'Eliminar',
                    color: palette.error,
                  ),
                ],
              ),
            ),
          ],
        ),
        if (extras.imageIds.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          BiblePointImages(
            projectId: projectId,
            bibleId: bibleId,
            sectionId: sectionId,
            imageIds: extras.imageIds,
            onChanged: (ids) => onExtrasChanged(extras.withImages(ids)),
          ),
        ],
        if (extras.hasText) ...[
          const SizedBox(height: AppSpacing.sm),
          _ExtraText(
            text: extras.text!,
            onChanged: (text) => onExtrasChanged(extras.withText(text)),
          ),
        ],
      ],
    );
  }
}

/// Texto complementario de un punto: se escribe en el sitio y se guarda tras
/// una pausa.
class _ExtraText extends StatefulWidget {
  final String text;
  final ValueChanged<String> onChanged;

  const _ExtraText({required this.text, required this.onChanged});

  @override
  State<_ExtraText> createState() => _ExtraTextState();
}

class _ExtraTextState extends State<_ExtraText> {
  late final _controller = TextEditingController(text: widget.text);
  Timer? _debounce;

  @override
  void dispose() {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
      widget.onChanged(_controller.text);
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = AppTypography.bodyMedium(
      palette,
    ).copyWith(height: 1.5, color: palette.textSecondary);
    return Container(
      padding: const EdgeInsets.only(left: AppSpacing.md),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: palette.borderBright, width: 2)),
      ),
      child: TextField(
        controller: _controller,
        minLines: 1,
        maxLines: null,
        style: style,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: 'Texto complementario…',
          hintStyle: style.copyWith(color: palette.textTertiary),
          isDense: true,
          filled: false,
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
        onChanged: (_) {
          _debounce?.cancel();
          _debounce = Timer(
            const Duration(milliseconds: 500),
            () => widget.onChanged(_controller.text),
          );
        },
      ),
    );
  }
}
