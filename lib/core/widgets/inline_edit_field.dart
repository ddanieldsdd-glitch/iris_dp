import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Campo de texto inline con guardado al perder foco (guion técnico / storyboard).
class InlineEditField extends StatefulWidget {
  final String? value;
  final String hint;
  final int minLines;
  final int? maxLines;
  final TextStyle? style;
  final TextAlign textAlign;
  final AppPalette palette;
  final ValueChanged<String> onChanged;
  final VoidCallback? onExpand;

  const InlineEditField({
    super.key,
    required this.value,
    required this.hint,
    required this.palette,
    required this.onChanged,
    this.minLines = 1,
    this.maxLines,
    this.style,
    this.textAlign = TextAlign.start,
    this.onExpand,
  });

  @override
  State<InlineEditField> createState() => _InlineEditFieldState();
}

class _InlineEditFieldState extends State<InlineEditField> {
  late TextEditingController _ctrl;
  late FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value ?? '');
    _focus = FocusNode()..addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_focus.hasFocus) {
      widget.onChanged(_ctrl.text);
    }
  }

  @override
  void didUpdateWidget(InlineEditField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value &&
        widget.value != _ctrl.text &&
        !_focus.hasFocus) {
      _ctrl.text = widget.value ?? '';
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _openExpandedEditor() async {
    final palette = widget.palette;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final expanded = TextEditingController(text: _ctrl.text);
        return AlertDialog(
          backgroundColor: palette.surfaceElevated,
          title: Text(widget.hint, style: AppTypography.titleMedium(palette)),
          content: TextField(
            controller: expanded,
            autofocus: true,
            minLines: 4,
            maxLines: 12,
            style: AppTypography.bodyLarge(palette),
            decoration: InputDecoration(hintText: widget.hint),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar', style: AppTypography.bodyMedium(palette)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, expanded.text),
              child: Text(
                'Guardar',
                style: AppTypography.bodyMedium(palette)
                    .copyWith(color: palette.accent),
              ),
            ),
          ],
        );
      },
    );
    if (result != null) {
      _ctrl.text = result;
      widget.onChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onExpand = widget.onExpand ?? _openExpandedEditor;
    return GestureDetector(
      onDoubleTap: onExpand,
      child: TextField(
        controller: _ctrl,
        focusNode: _focus,
        minLines: widget.minLines,
        maxLines: widget.maxLines,
        textAlign: widget.textAlign,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        style: widget.style ??
            AppTypography.bodyMedium(widget.palette)
                .copyWith(color: widget.palette.textPrimary),
        decoration: InputDecoration(
          hintText: widget.hint,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
          isDense: true,
        ),
        onSubmitted: widget.onChanged,
        onEditingComplete: () => widget.onChanged(_ctrl.text),
      ),
    );
  }
}

/// Desplegable compacto para movimiento / ángulo.
class InlineDropdownField extends StatelessWidget {
  final String? value;
  final List<String> options;
  final String hint;
  final AppPalette palette;
  final ValueChanged<String?> onChanged;

  const InlineDropdownField({
    super.key,
    required this.value,
    required this.options,
    required this.hint,
    required this.palette,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: options.contains(value) ? value : null,
        hint: Text(hint, style: AppTypography.caption(palette)),
        style: AppTypography.caption(palette)
            .copyWith(color: palette.textPrimary),
        dropdownColor: palette.surfaceElevated,
        isDense: true,
        isExpanded: true,
        items: options
            .map((o) => DropdownMenuItem(value: o, child: Text(o)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}
