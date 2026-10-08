import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/visual_bible/bible_table.dart';
import '../../../shared/visual_bible/bible_text_specs.dart';
import 'bible_point_panel.dart';

InputDecoration _bare(AppPalette palette, String hint, TextStyle style) =>
    InputDecoration(
      hintText: hint,
      hintStyle: style.copyWith(color: palette.textTertiary),
      isDense: true,
      filled: false,
      contentPadding: const EdgeInsets.symmetric(vertical: 6),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
    );

/// Guarda con un pequeño retraso para no escribir en cada tecla, y sin
/// perder lo último al cerrar.
mixin _DebouncedSave<T extends StatefulWidget> on State<T> {
  Timer? _debounce;
  VoidCallback? _pending;

  void saveSoon(VoidCallback save) {
    _pending = save;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final run = _pending;
      _pending = null;
      run?.call();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _pending?.call();
    super.dispose();
  }
}

/// Tabla que se escribe en el sitio: los títulos de columna y las celdas
/// son campos de texto; filas y columnas se añaden y se quitan.
class BibleTableWidget extends StatefulWidget {
  final BibleTableValue value;
  final ValueChanged<BibleTableValue> onChanged;

  const BibleTableWidget({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  State<BibleTableWidget> createState() => _BibleTableWidgetState();
}

class _BibleTableWidgetState extends State<BibleTableWidget>
    with _DebouncedSave {
  late BibleTableValue _value = widget.value;

  /// Cambia al añadir o quitar filas y columnas, para remontar los campos.
  int _shape = 0;

  void _edit(BibleTableValue next) {
    _value = next;
    saveSoon(() => widget.onChanged(_value));
  }

  void _reshape(BibleTableValue next) {
    setState(() {
      _value = next;
      _shape++;
    });
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final head = BiblePointPanel.labelStyle(palette);
    final cell = AppTypography.bodyMedium(palette);
    final columns = _value.columns;

    Widget removeButton(String tooltip, VoidCallback onTap) => IconButton(
      icon: Icon(
        Icons.remove_circle_outline,
        size: 14,
        color: palette.textTertiary,
      ),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 28, height: 28),
      onPressed: onTap,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: palette.borderBright)),
          ),
          child: Row(
            children: [
              for (var c = 0; c < columns.length; c++)
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: ValueKey('col_${_shape}_$c'),
                          initialValue: columns[c],
                          style: head,
                          textCapitalization: TextCapitalization.characters,
                          decoration: _bare(palette, 'COLUMNA', head),
                          onChanged: (v) => _edit(_value.withColumnName(c, v)),
                        ),
                      ),
                      if (columns.length > 1)
                        removeButton(
                          'Quitar columna',
                          () => _reshape(_value.removeColumn(c)),
                        ),
                    ],
                  ),
                ),
              const SizedBox(width: 28),
            ],
          ),
        ),
        for (var r = 0; r < _value.rows.length; r++)
          Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: palette.divider)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var c = 0; c < columns.length; c++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: TextFormField(
                        key: ValueKey('cell_${_shape}_${r}_$c'),
                        initialValue: _value.rows[r][c],
                        minLines: 1,
                        maxLines: null,
                        style: cell,
                        decoration: _bare(palette, '—', cell),
                        onChanged: (v) => _edit(_value.withCell(r, c, v)),
                      ),
                    ),
                  ),
                removeButton('Quitar fila', () => _reshape(_value.removeRow(r))),
              ],
            ),
          ),
        Row(
          children: [
            TextButton.icon(
              onPressed: () => _reshape(_value.addRow()),
              icon: Icon(Icons.add, size: 16, color: palette.textSecondary),
              label: Text('AÑADIR FILA', style: head),
            ),
            TextButton.icon(
              onPressed: () => _reshape(_value.addColumn('')),
              icon: Icon(
                Icons.view_column_outlined,
                size: 16,
                color: palette.textSecondary,
              ),
              label: Text('AÑADIR COLUMNA', style: head),
            ),
          ],
        ),
      ],
    );
  }
}

/// Medidores: cada uno es un dato escrito; si es un número y el medidor
/// tiene escala, una barra enseña dónde cae.
class BibleMetersWidget extends StatefulWidget {
  final List<BibleMeter> meters;
  final ValueChanged<List<BibleMeter>> onChanged;

  const BibleMetersWidget({
    super.key,
    required this.meters,
    required this.onChanged,
  });

  @override
  State<BibleMetersWidget> createState() => _BibleMetersWidgetState();
}

class _BibleMetersWidgetState extends State<BibleMetersWidget>
    with _DebouncedSave {
  late List<BibleMeter> _meters = [...widget.meters];
  int _shape = 0;

  void _edit(int index, BibleMeter next) {
    setState(() => _meters[index] = next);
    saveSoon(() => widget.onChanged(_meters));
  }

  void _reshape(List<BibleMeter> next) {
    setState(() {
      _meters = next;
      _shape++;
    });
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final labelStyle = BiblePointPanel.labelStyle(palette);
    final valueStyle = AppTypography.mono(
      palette,
    ).copyWith(color: palette.accent, fontWeight: FontWeight.w600);
    final noteStyle = AppTypography.caption(palette);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _meters.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        key: ValueKey('meter_label_${_shape}_$i'),
                        initialValue: _meters[i].label,
                        style: labelStyle,
                        textCapitalization: TextCapitalization.characters,
                        decoration: _bare(palette, 'DATO', labelStyle),
                        onChanged: (v) =>
                            _edit(i, _meters[i].copyWith(label: v)),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        key: ValueKey('meter_value_${_shape}_$i'),
                        initialValue: _meters[i].value,
                        style: valueStyle,
                        textAlign: TextAlign.end,
                        decoration: _bare(palette, 'Valor', valueStyle),
                        onChanged: (v) =>
                            _edit(i, _meters[i].copyWith(value: v)),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.remove_circle_outline,
                        size: 14,
                        color: palette.textTertiary,
                      ),
                      tooltip: 'Quitar',
                      visualDensity: VisualDensity.compact,
                      onPressed: () =>
                          _reshape([..._meters]..removeAt(i)),
                    ),
                  ],
                ),
                if (_meters[i].fraction != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: _meters[i].fraction,
                        minHeight: 3,
                        backgroundColor: palette.divider,
                        color: palette.accent,
                      ),
                    ),
                  ),
                TextFormField(
                  key: ValueKey('meter_note_${_shape}_$i'),
                  initialValue: _meters[i].note,
                  minLines: 1,
                  maxLines: null,
                  style: noteStyle,
                  decoration: _bare(palette, 'Para qué, cuándo…', noteStyle),
                  onChanged: (v) => _edit(i, _meters[i].copyWith(note: v)),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _reshape([..._meters, const BibleMeter()]),
            icon: Icon(Icons.add, size: 16, color: palette.textSecondary),
            label: Text('AÑADIR DATO', style: labelStyle),
          ),
        ),
      ],
    );
  }
}

/// Un desarrollo escrito y, debajo, datos sueltos (dato y valor) en
/// casillas. Todo se escribe en el sitio.
class BibleTextSpecsWidget extends StatefulWidget {
  final BibleTextSpecsValue value;
  final String hint;
  final ValueChanged<BibleTextSpecsValue> onChanged;

  const BibleTextSpecsWidget({
    super.key,
    required this.value,
    required this.onChanged,
    this.hint = 'Escribe aquí…',
  });

  @override
  State<BibleTextSpecsWidget> createState() => _BibleTextSpecsWidgetState();
}

class _BibleTextSpecsWidgetState extends State<BibleTextSpecsWidget>
    with _DebouncedSave {
  late BibleTextSpecsValue _value = widget.value;
  int _shape = 0;

  void _edit(BibleTextSpecsValue next) {
    _value = next;
    saveSoon(() => widget.onChanged(_value));
  }

  void _reshape(BibleTextSpecsValue next) {
    setState(() {
      _value = next;
      _shape++;
    });
    widget.onChanged(next);
  }

  List<(String, String)> _withRow(int index, (String, String) row) => [
    for (var i = 0; i < _value.rows.length; i++)
      i == index ? row : _value.rows[i],
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final body = AppTypography.bodyLarge(palette);
    final labelStyle = BiblePointPanel.labelStyle(palette);
    final valueStyle = AppTypography.bodyMedium(palette);
    final rows = _value.rows;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          initialValue: _value.text,
          minLines: 1,
          maxLines: null,
          style: body,
          decoration: _bare(palette, widget.hint, body),
          onChanged: (v) => _edit(_value.copyWith(text: v)),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (var i = 0; i < rows.length; i++)
              Container(
                width: 168,
                padding: const EdgeInsets.fromLTRB(10, 6, 2, 6),
                decoration: BoxDecoration(
                  color: palette.background.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: palette.divider),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            key: ValueKey('ts_label_${_shape}_$i'),
                            initialValue: rows[i].$1,
                            style: labelStyle,
                            textCapitalization: TextCapitalization.characters,
                            decoration: _bare(palette, 'DATO', labelStyle),
                            onChanged: (v) => _edit(
                              _value.copyWith(
                                rows: _withRow(i, (v, _value.rows[i].$2)),
                              ),
                            ),
                          ),
                          TextFormField(
                            key: ValueKey('ts_value_${_shape}_$i'),
                            initialValue: rows[i].$2,
                            minLines: 1,
                            maxLines: null,
                            style: valueStyle,
                            decoration: _bare(palette, '—', valueStyle),
                            onChanged: (v) => _edit(
                              _value.copyWith(
                                rows: _withRow(i, (_value.rows[i].$1, v)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 12,
                        color: palette.textTertiary,
                      ),
                      tooltip: 'Quitar dato',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 22,
                        height: 22,
                      ),
                      onPressed: () => _reshape(
                        _value.copyWith(rows: [...rows]..removeAt(i)),
                      ),
                    ),
                  ],
                ),
              ),
            TextButton.icon(
              onPressed: () =>
                  _reshape(_value.copyWith(rows: [...rows, ('', '')])),
              icon: Icon(Icons.add, size: 16, color: palette.textSecondary),
              label: Text('AÑADIR DATO', style: labelStyle),
            ),
          ],
        ),
      ],
    );
  }
}
