import 'package:flutter/material.dart';

/// Celda de texto de la tabla. Mientras no se edita es solo texto, que es
/// barato de pintar; al tocarla (o al llegar con Tab) monta su campo con el
/// cursor donde se hizo clic, y al salir guarda y vuelve a ser texto.
class EditableCell extends StatefulWidget {
  final String? value;
  final String hint;
  final TextStyle style;
  final TextStyle hintStyle;
  final TextAlign textAlign;
  final int minLines;
  final ValueChanged<String> onChanged;

  const EditableCell({
    super.key,
    required this.value,
    required this.hint,
    required this.style,
    required this.hintStyle,
    required this.onChanged,
    this.textAlign = TextAlign.start,
    this.minLines = 1,
  });

  @override
  State<EditableCell> createState() => _EditableCellState();
}

class _EditableCellState extends State<EditableCell> {
  /// Foco de la celda en reposo: deja llegar con Tab.
  final _restFocus = FocusNode(debugLabel: 'EditableCell.rest');
  FocusNode? _editFocus;
  TextEditingController? _ctrl;

  bool get _editing => _ctrl != null;
  String get _value => widget.value ?? '';

  @override
  void initState() {
    super.initState();
    _restFocus.addListener(_onRestFocus);
  }

  void _onRestFocus() {
    if (_restFocus.hasFocus && !_editing) _startEditing();
  }

  void _startEditing([Offset? tapPosition]) {
    if (_editing) return;
    var offset = _value.length;
    if (tapPosition != null && _value.isNotEmpty) {
      final box = context.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        final painter = TextPainter(
          text: TextSpan(text: _value, style: widget.style),
          textAlign: widget.textAlign,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(minWidth: box.size.width, maxWidth: box.size.width);
        offset = painter.getPositionForOffset(tapPosition).offset;
        painter.dispose();
      }
    }
    final focus = FocusNode(debugLabel: 'EditableCell.edit')
      ..addListener(_onEditFocus);
    setState(() {
      _editFocus = focus;
      _ctrl = TextEditingController.fromValue(
        TextEditingValue(
          text: _value,
          selection: TextSelection.collapsed(offset: offset),
        ),
      );
    });
    focus.requestFocus();
  }

  void _onEditFocus() {
    final focus = _editFocus;
    if (focus == null || focus.hasFocus) return;
    _finishEditing();
  }

  void _finishEditing() {
    final ctrl = _ctrl;
    final focus = _editFocus;
    if (ctrl == null) return;
    final text = ctrl.text;
    if (mounted) {
      setState(() {
        _ctrl = null;
        _editFocus = null;
      });
    } else {
      _ctrl = null;
      _editFocus = null;
    }
    // Se sueltan después del cuadro: el campo aún los usa mientras se quita.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      focus?.removeListener(_onEditFocus);
      focus?.dispose();
      ctrl.dispose();
    });
    if (text != _value) widget.onChanged(text);
  }

  @override
  void dispose() {
    final ctrl = _ctrl;
    if (ctrl != null && ctrl.text != _value) widget.onChanged(ctrl.text);
    _restFocus
      ..removeListener(_onRestFocus)
      ..dispose();
    _editFocus?.removeListener(_onEditFocus);
    _editFocus?.dispose();
    ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lineHeight =
        (widget.style.fontSize ?? 14) * (widget.style.height ?? 1.2);
    final minHeight = lineHeight * widget.minLines;

    final ctrl = _ctrl;
    if (ctrl != null) {
      return ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: TextField(
          controller: ctrl,
          focusNode: _editFocus,
          minLines: 1,
          maxLines: null,
          textAlign: widget.textAlign,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          style: widget.style,
          cursorColor: widget.style.color,
          decoration: const InputDecoration(
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            isCollapsed: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      );
    }

    return Focus(
      focusNode: _restFocus,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => _startEditing(d.localPosition),
        child: MouseRegion(
          cursor: SystemMouseCursors.text,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: minHeight,
              minWidth: double.infinity,
            ),
            child: Text(
              _value.isEmpty ? widget.hint : _value,
              textAlign: widget.textAlign,
              style: _value.isEmpty ? widget.hintStyle : widget.style,
            ),
          ),
        ),
      ),
    );
  }
}
