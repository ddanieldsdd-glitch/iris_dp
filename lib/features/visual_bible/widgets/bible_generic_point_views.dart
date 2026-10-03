import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/visual_bible/bible_section_fields.dart';
import 'bible_point_panel.dart';

/// Vista genérica de un punto sin widget dedicado (texto, lista o specs).
///
/// Lee y escribe el valor crudo de `values[field.key]`; [onChanged] recibe
/// `null` cuando el punto queda vacío.
class BibleGenericPointView extends StatefulWidget {
  final BibleSectionField field;
  final String? value;
  final ValueChanged<String?> onChanged;

  const BibleGenericPointView({
    super.key,
    required this.field,
    required this.value,
    required this.onChanged,
  });

  static bool supports(BibleSectionFieldType type) =>
      type == BibleSectionFieldType.text ||
      type == BibleSectionFieldType.list ||
      type == BibleSectionFieldType.specs;

  static IconData iconFor(BibleSectionFieldType type) => switch (type) {
        BibleSectionFieldType.list => Icons.format_list_bulleted,
        BibleSectionFieldType.specs => Icons.tune,
        _ => Icons.notes_outlined,
      };

  @override
  State<BibleGenericPointView> createState() => _BibleGenericPointViewState();
}

class _BibleGenericPointViewState extends State<BibleGenericPointView> {
  static const _saveDelay = Duration(milliseconds: 400);

  late List<String> _items;
  late List<(String, String)> _rows;
  Timer? _debounce;
  String? _pending;
  bool _hasPending = false;

  @override
  void initState() {
    super.initState();
    _items = BibleSectionPointValue.decodeList(widget.value);
    _rows = BibleSectionPointValue.decodeSpecs(widget.value);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (_hasPending) widget.onChanged(_pending);
    super.dispose();
  }

  void _emit(String? value) {
    _pending = value;
    _hasPending = true;
    _debounce?.cancel();
    _debounce = Timer(_saveDelay, () {
      _hasPending = false;
      widget.onChanged(_pending);
    });
  }

  void _setItems(List<String> next) {
    setState(() => _items = next);
    _emit(BibleSectionPointValue.encodeList(next));
  }

  void _setRows(List<(String, String)> next) {
    setState(() => _rows = next);
    _emit(BibleSectionPointValue.encodeSpecs(next));
  }

  @override
  Widget build(BuildContext context) {
    final field = widget.field;
    return BiblePointPanel(
      label: field.label,
      icon: BibleGenericPointView.iconFor(field.type),
      child: switch (field.type) {
        BibleSectionFieldType.list => _buildList(context),
        BibleSectionFieldType.specs => _buildSpecs(context),
        _ => _buildText(context),
      },
    );
  }

  InputDecoration _bare(AppPalette palette, String hint, TextStyle style) =>
      InputDecoration(
        hintText: hint,
        hintStyle: style.copyWith(color: palette.textTertiary),
        isDense: true,
        filled: false,
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
      );

  Widget _buildText(BuildContext context) {
    final palette = context.palette;
    final style = AppTypography.bodyLarge(palette);
    return TextFormField(
      initialValue: widget.value ?? '',
      minLines: 1,
      maxLines: null,
      style: style,
      decoration: _bare(palette, widget.field.hint ?? 'Escribe aquí…', style),
      onChanged: (v) => _emit(v.trim().isEmpty ? null : v),
    );
  }

  Widget _addButton(BuildContext context, String label, VoidCallback onTap) {
    final palette = context.palette;
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(Icons.add, size: 16, color: palette.textSecondary),
        label: Text(
          label.toUpperCase(),
          style: BiblePointPanel.labelStyle(palette),
        ),
      ),
    );
  }

  Widget _removeButton(BuildContext context, VoidCallback onTap) => IconButton(
        icon: Icon(
          Icons.remove_circle_outline,
          size: 16,
          color: context.palette.textTertiary,
        ),
        tooltip: 'Quitar',
        visualDensity: VisualDensity.compact,
        onPressed: onTap,
      );

  Widget _buildList(BuildContext context) {
    final palette = context.palette;
    final style = AppTypography.bodyLarge(palette);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 9, right: 10),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: palette.accent,
                    ),
                  ),
                ),
                Expanded(
                  child: TextFormField(
                    key: ValueKey('item_${_items.length}_$i'),
                    initialValue: _items[i],
                    minLines: 1,
                    maxLines: null,
                    style: style,
                    decoration: _bare(palette, 'Punto…', style),
                    onChanged: (v) {
                      _items[i] = v;
                      _emit(BibleSectionPointValue.encodeList(_items));
                    },
                  ),
                ),
                _removeButton(
                  context,
                  () => _setItems([..._items]..removeAt(i)),
                ),
              ],
            ),
          ),
        _addButton(context, 'Añadir punto', () => _setItems([..._items, ''])),
      ],
    );
  }

  Widget _buildSpecs(BuildContext context) {
    final palette = context.palette;
    final labelStyle = BiblePointPanel.labelStyle(palette);
    final valueStyle = AppTypography.mono(palette);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _rows.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: palette.divider)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    key: ValueKey('label_${_rows.length}_$i'),
                    initialValue: _rows[i].$1,
                    style: labelStyle,
                    textCapitalization: TextCapitalization.characters,
                    decoration: _bare(palette, 'DATO', labelStyle),
                    onChanged: (v) {
                      _rows[i] = (v, _rows[i].$2);
                      _emit(BibleSectionPointValue.encodeSpecs(_rows));
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    key: ValueKey('value_${_rows.length}_$i'),
                    initialValue: _rows[i].$2,
                    style: valueStyle,
                    decoration: _bare(palette, 'Valor', valueStyle),
                    onChanged: (v) {
                      _rows[i] = (_rows[i].$1, v);
                      _emit(BibleSectionPointValue.encodeSpecs(_rows));
                    },
                  ),
                ),
                _removeButton(
                  context,
                  () => _setRows([..._rows]..removeAt(i)),
                ),
              ],
            ),
          ),
        _addButton(context, 'Añadir dato', () => _setRows([..._rows, ('', '')])),
      ],
    );
  }
}
