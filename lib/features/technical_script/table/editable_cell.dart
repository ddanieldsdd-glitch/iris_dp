import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/rich_text/script_markup.dart';

/// Campo de texto con formato que se está editando ahora, si lo hay. La
/// barra de formato actúa sobre él.
final activeScriptEditor = ValueNotifier<TextEditingController?>(null);

/// Fondo de cada color de marcador.
const kScriptMarkerFills = {
  'y': Color(0xFFFFF176),
  'g': Color(0xFFA5D6A7),
  'p': Color(0xFFF48FB1),
  'b': Color(0xFF90CAF9),
};

/// Limpia un texto pegado: los espacios «duros» y tabuladores de Word o de
/// un PDF pasan a espacio normal, los repetidos se juntan, las líneas no
/// acaban en espacio y no quedan más de dos saltos seguidos.
String cleanPastedText(String text) => text
    .replaceAll('\r\n', '\n')
    .replaceAll('\r', '\n')
    .replaceAll(RegExp('[\t   ​]'), ' ')
    .replaceAll(RegExp(' {2,}'), ' ')
    .replaceAll(RegExp(r' *\n *'), '\n')
    .replaceAll(RegExp(r'\n{3,}'), '\n\n');

/// Aplica [cleanPastedText] a lo que entra de golpe en un campo (pegar);
/// lo que se teclea letra a letra no se toca.
class PastedTextCleaner extends TextInputFormatter {
  const PastedTextCleaner();

  static final _blank = RegExp(r'\s');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final from = oldValue.selection;
    final to = newValue.selection;
    if (!from.isValid || !to.isValid || !to.isCollapsed) return newValue;
    if (newValue.composing.isValid && !newValue.composing.isCollapsed) {
      return newValue;
    }
    final start = from.start;
    final end = to.end;
    // Lo que queda detrás del cursor tiene que ser lo que ya había.
    final tail = oldValue.text.substring(from.end);
    if (end - start < 2 ||
        end > newValue.text.length ||
        newValue.text.substring(end) != tail ||
        newValue.text.substring(0, start) !=
            oldValue.text.substring(0, start)) {
      return newValue;
    }
    final before = newValue.text.substring(0, start);
    var pasted = cleanPastedText(newValue.text.substring(start, end));
    // Al principio de la celda o tras un espacio, sin blancos delante; al
    // final de la celda, sin blancos detrás.
    if (before.isEmpty || _blank.hasMatch(before[before.length - 1])) {
      pasted = pasted.trimLeft();
    }
    if (tail.isEmpty) {
      pasted = pasted.trimRight();
    } else if (pasted.endsWith('\n')) {
      pasted = '${pasted.trimRight()}${_blank.hasMatch(tail[0]) ? '' : ' '}';
    }
    final text = '$before$pasted$tail';
    if (text == newValue.text) return newValue;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: before.length + pasted.length),
    );
  }
}

/// Pone o quita un formato en la selección de [controller].
void applyScriptMark(
  TextEditingController controller,
  ScriptMark mark, {
  String? color,
}) {
  final selection = controller.selection;
  if (!selection.isValid || selection.isCollapsed) return;
  final edit = toggleScriptMarkup(
    controller.text,
    selection.start,
    selection.end,
    mark,
    color: color,
  );
  controller.value = TextEditingValue(
    text: edit.text,
    selection: TextSelection(baseOffset: edit.start, extentOffset: edit.end),
  );
}

/// Estilo de un trozo de texto con formato sobre el estilo [base].
TextStyle scriptSpanStyle(TextStyle base, ScriptSpan span) {
  final marked = span.marker != null;
  return base.copyWith(
    fontWeight: span.bold ? FontWeight.w700 : null,
    fontStyle: span.italic ? FontStyle.italic : null,
    decoration: span.underline ? TextDecoration.underline : null,
    decorationColor: marked ? const Color(0xFF111111) : base.color,
    backgroundColor: marked ? kScriptMarkerFills[span.marker] : null,
    // Sobre el marcador el texto va siempre oscuro, también en vista oscura.
    color: marked ? const Color(0xFF111111) : null,
  );
}

/// Campo que pinta el formato mientras se escribe, con las marcas atenuadas.
class ScriptMarkupController extends TextEditingController {
  ScriptMarkupController.fromValue(super.value) : super.fromValue();

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final base = style ?? const TextStyle();
    return TextSpan(
      style: base,
      children: [
        for (final span in parseScriptMarkup(text, keepMarkup: true))
          TextSpan(
            text: span.text,
            style: span.isMarkup
                ? base.copyWith(
                    color: (base.color ?? const Color(0xFF888888)).withValues(
                      alpha: 0.35,
                    ),
                  )
                : scriptSpanStyle(base, span),
          ),
      ],
    );
  }
}

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

  /// Admite negrita, cursiva, subrayado y marcador.
  final bool rich;

  const EditableCell({
    super.key,
    required this.value,
    required this.hint,
    required this.style,
    required this.hintStyle,
    required this.onChanged,
    this.textAlign = TextAlign.start,
    this.minLines = 1,
    this.rich = false,
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

  bool get _hasFormat => parseScriptMarkup(_value).any((span) => !span.isPlain);
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
    final shown = widget.rich ? scriptMarkupToPlain(_value) : _value;
    if (tapPosition != null && shown.isNotEmpty) {
      final box = context.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        final painter = TextPainter(
          text: TextSpan(text: shown, style: widget.style),
          textAlign: widget.textAlign,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(minWidth: box.size.width, maxWidth: box.size.width);
        offset = painter.getPositionForOffset(tapPosition).offset;
        painter.dispose();
        // El clic cae sobre el texto visible; el campo lleva las marcas.
        if (widget.rich) offset = scriptRawOffsetForPlain(_value, offset);
      }
    }
    final focus = FocusNode(debugLabel: 'EditableCell.edit')
      ..addListener(_onEditFocus);
    setState(() {
      _editFocus = focus;
      final value = TextEditingValue(
        text: _value,
        selection: TextSelection.collapsed(offset: offset),
      );
      _ctrl = widget.rich
          ? ScriptMarkupController.fromValue(value)
          : TextEditingController.fromValue(value);
    });
    if (widget.rich) activeScriptEditor.value = _ctrl;
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
    if (activeScriptEditor.value == ctrl) activeScriptEditor.value = null;
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
    if (ctrl != null && activeScriptEditor.value == ctrl) {
      // Fuera de este momento: avisar a la barra mientras se desmonta la
      // celda rompería el repintado.
      Future.microtask(() {
        if (activeScriptEditor.value == ctrl) activeScriptEditor.value = null;
      });
    }
    _restFocus
      ..removeListener(_onRestFocus)
      ..dispose();
    _editFocus?.removeListener(_onEditFocus);
    _editFocus?.dispose();
    ctrl?.dispose();
    super.dispose();
  }

  Widget _field(TextEditingController ctrl) => TextField(
    controller: ctrl,
    focusNode: _editFocus,
    minLines: 1,
    maxLines: null,
    textAlign: widget.textAlign,
    keyboardType: TextInputType.multiline,
    textInputAction: TextInputAction.newline,
    inputFormatters: const [PastedTextCleaner()],
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
  );

  @override
  Widget build(BuildContext context) {
    final lineHeight =
        (widget.style.fontSize ?? 14) * (widget.style.height ?? 1.2);
    final minHeight = lineHeight * widget.minLines;

    final ctrl = _ctrl;
    if (ctrl != null) {
      return ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: !widget.rich
            ? _field(ctrl)
            : CallbackShortcuts(
                bindings: {
                  for (final entry in {
                    LogicalKeyboardKey.keyB: ScriptMark.bold,
                    LogicalKeyboardKey.keyI: ScriptMark.italic,
                    LogicalKeyboardKey.keyU: ScriptMark.underline,
                  }.entries) ...{
                    SingleActivator(entry.key, meta: true): () =>
                        applyScriptMark(ctrl, entry.value),
                    SingleActivator(entry.key, control: true): () =>
                        applyScriptMark(ctrl, entry.value),
                  },
                },
                child: _field(ctrl),
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
            // Sin formato es texto normal, que es más barato de pintar.
            child: _value.isEmpty || !widget.rich || !_hasFormat
                ? Text(
                    _value.isEmpty ? widget.hint : _value,
                    textAlign: widget.textAlign,
                    style: _value.isEmpty ? widget.hintStyle : widget.style,
                  )
                : Text.rich(
                    TextSpan(
                      children: [
                        for (final span in parseScriptMarkup(_value))
                          TextSpan(
                            text: span.text,
                            style: scriptSpanStyle(widget.style, span),
                          ),
                      ],
                    ),
                    textAlign: widget.textAlign,
                    style: widget.style,
                  ),
          ),
        ),
      ),
    );
  }
}
