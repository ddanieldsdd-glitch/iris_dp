import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_layout.dart';
import '../../shared/technical_script_export/technical_script_doc.dart';
import 'technical_script_settings.dart';

/// Lo elegido al exportar un guion técnico: formato, índice, columnas,
/// cuerpo de letra y papel. Se guarda en el equipo y se propone la próxima
/// vez; las columnas no dependen de las que se ven en pantalla.
class ScriptExportOptions {
  final bool word;
  final bool index;

  /// Claves de [kScriptDocColumns] que no salen en el documento.
  final Set<String> hiddenColumns;

  /// Cuerpo del texto de la tabla, en puntos.
  final double fontSize;
  final ScriptDocPaper paper;
  final bool landscape;

  const ScriptExportOptions({
    this.word = false,
    this.index = true,
    this.hiddenColumns = const {'dur', 'story'},
    this.fontSize = 8.5,
    this.paper = ScriptDocPaper.a4,
    this.landscape = true,
  });

  /// Columnas que se pueden quitar del documento; ESC, PLANO y ACCIÓN
  /// salen siempre.
  static const optionalColumns = [
    'encuadre',
    'lens',
    'f',
    'pers',
    'dur',
    'ref',
    'story',
    'planta',
    'notes',
  ];

  /// Cuerpos de letra que se ofrecen, con su nombre.
  static final fontSizes = {7.5: 'Pequeña', 8.5: 'Normal', 10.0: 'Grande'};

  /// La primera vez: las columnas que se ven en la hoja del guion técnico.
  factory ScriptExportOptions.fromScreen(TechnicalScriptSettings screen) =>
      ScriptExportOptions(
        hiddenColumns: {
          for (final c in ScriptColumn.optional)
            if (!screen.shows(c)) c,
        },
      );

  bool shows(String column) => !hiddenColumns.contains(column);

  /// El documento con el índice, el papel y la letra elegidos.
  TechnicalScriptDoc applyTo(TechnicalScriptDoc doc) => doc.copyWith(
    includeIndex: index,
    paper: paper,
    landscape: landscape,
    fontSize: fontSize,
  );

  ScriptExportOptions copyWith({
    bool? word,
    bool? index,
    Set<String>? hiddenColumns,
    double? fontSize,
    ScriptDocPaper? paper,
    bool? landscape,
  }) => ScriptExportOptions(
    word: word ?? this.word,
    index: index ?? this.index,
    hiddenColumns: hiddenColumns ?? this.hiddenColumns,
    fontSize: fontSize ?? this.fontSize,
    paper: paper ?? this.paper,
    landscape: landscape ?? this.landscape,
  );

  Map<String, dynamic> toJson() => {
    'word': word,
    'index': index,
    'hiddenColumns': hiddenColumns.toList(),
    'fontSize': fontSize,
    'paper': paper.name,
    'landscape': landscape,
  };

  factory ScriptExportOptions.fromJson(Map<String, dynamic> json) {
    const d = ScriptExportOptions();
    final size = json['fontSize'];
    return ScriptExportOptions(
      word: json['word'] == true,
      index: json['index'] != false,
      hiddenColumns: json['hiddenColumns'] is List
          ? {
              for (final c in json['hiddenColumns'] as List)
                if (c is String && optionalColumns.contains(c)) c,
            }
          : d.hiddenColumns,
      fontSize: size is num && fontSizes.containsKey(size.toDouble())
          ? size.toDouble()
          : d.fontSize,
      paper: ScriptDocPaper.parse(json['paper']) ?? d.paper,
      landscape: json['landscape'] != false,
    );
  }
}

const _prefsKey = 'iris_script_export_options';

/// Lo último que se eligió al exportar; la primera vez, las columnas de la
/// hoja [screen].
Future<ScriptExportOptions> savedScriptExportOptions(
  TechnicalScriptSettings screen,
) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      return ScriptExportOptions.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    }
  } catch (_) {
    // Ilegible: se parte de la hoja.
  }
  return ScriptExportOptions.fromScreen(screen);
}

Future<void> _save(ScriptExportOptions options) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(options.toJson()));
  } catch (_) {
    // La elección vale para esta exportación aunque no se guarde.
  }
}

/// Pregunta el formato (PDF o Word), el índice, las columnas, la letra y el
/// papel. Parte de lo último elegido y lo guarda.
Future<ScriptExportOptions?> showScriptExportDialog(
  BuildContext context, {
  required TechnicalScriptSettings screen,
  String title = 'Exportar guion técnico',
}) async {
  final initial = await savedScriptExportOptions(screen);
  if (!context.mounted) return null;
  final choice = await showDialog<ScriptExportOptions>(
    context: context,
    builder: (_) => _ScriptExportDialog(title: title, initial: initial),
  );
  if (choice != null) await _save(choice);
  return choice;
}

class _ScriptExportDialog extends StatefulWidget {
  final String title;
  final ScriptExportOptions initial;

  const _ScriptExportDialog({required this.title, required this.initial});

  @override
  State<_ScriptExportDialog> createState() => _ScriptExportDialogState();
}

class _ScriptExportDialogState extends State<_ScriptExportDialog> {
  late ScriptExportOptions _o = widget.initial;

  void _set(ScriptExportOptions next) => setState(() => _o = next);

  String _columnLabel(String key) =>
      kScriptDocColumns.firstWhere((c) => c.key == key).label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Text(text, style: AppTypography.label(palette)),
    );
    return AlertDialog(
      backgroundColor: palette.surfaceElevated,
      title: Text(widget.title),
      content: SizedBox(
        width: AppLayout.dialogWidth(context, 460),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: Text('PDF'),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.description_outlined, size: 18),
                    label: Text('Word (.docx)'),
                  ),
                ],
                selected: {_o.word},
                onSelectionChanged: (v) => _set(_o.copyWith(word: v.first)),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _o.index,
                onChanged: (v) => _set(_o.copyWith(index: v)),
                title: const Text('Índice de escenas'),
                subtitle: Text(
                  'Al principio, con la página de cada escena. Pulsando una '
                  'línea se salta a ella.',
                  style: AppTypography.caption(palette),
                ),
              ),
              heading('Columnas'),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final key in ScriptExportOptions.optionalColumns)
                    FilterChip(
                      label: Text(_columnLabel(key)),
                      selected: _o.shows(key),
                      onSelected: (on) {
                        final hidden = {..._o.hiddenColumns};
                        on ? hidden.remove(key) : hidden.add(key);
                        _set(_o.copyWith(hiddenColumns: hidden));
                      },
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'ESC, PLANO y ACCIÓN salen siempre.',
                style: AppTypography.caption(palette),
              ),
              heading('Letra'),
              SegmentedButton<double>(
                showSelectedIcon: false,
                segments: [
                  for (final e in ScriptExportOptions.fontSizes.entries)
                    ButtonSegment(value: e.key, label: Text(e.value)),
                ],
                selected: {_o.fontSize},
                onSelectionChanged: (v) =>
                    _set(_o.copyWith(fontSize: v.first)),
              ),
              heading('Papel'),
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<ScriptDocPaper>(
                      showSelectedIcon: false,
                      segments: [
                        for (final p in ScriptDocPaper.values)
                          ButtonSegment(value: p, label: Text(p.label)),
                      ],
                      selected: {_o.paper},
                      onSelectionChanged: (v) =>
                          _set(_o.copyWith(paper: v.first)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SegmentedButton<bool>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: true, label: Text('Horizontal')),
                        ButtonSegment(value: false, label: Text('Vertical')),
                      ],
                      selected: {_o.landscape},
                      onSelectionChanged: (v) =>
                          _set(_o.copyWith(landscape: v.first)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Sale con la tipografía de la hoja del guion técnico.',
                style: AppTypography.caption(palette),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _o),
          child: const Text('Exportar'),
        ),
      ],
    );
  }
}
