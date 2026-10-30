import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Lo elegido al exportar un guion técnico.
typedef ScriptExportChoice = ({bool word, bool index});

/// Última elección, para proponerla la próxima vez.
ScriptExportChoice _last = (word: false, index: true);

/// Si la última exportación llevó índice; lo usan los botones directos de
/// PDF y Word, que no abren el diálogo.
bool get lastScriptExportIndex => _last.index;

/// Pregunta el formato (PDF o Word) y si lleva índice de escenas.
Future<ScriptExportChoice?> showScriptExportDialog(
  BuildContext context, {
  String title = 'Exportar guion técnico',
}) async {
  final choice = await showDialog<ScriptExportChoice>(
    context: context,
    builder: (_) => _ScriptExportDialog(title: title, initial: _last),
  );
  if (choice != null) _last = choice;
  return choice;
}

class _ScriptExportDialog extends StatefulWidget {
  final String title;
  final ScriptExportChoice initial;

  const _ScriptExportDialog({required this.title, required this.initial});

  @override
  State<_ScriptExportDialog> createState() => _ScriptExportDialogState();
}

class _ScriptExportDialogState extends State<_ScriptExportDialog> {
  late bool _word = widget.initial.word;
  late bool _index = widget.initial.index;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AlertDialog(
      backgroundColor: palette.surfaceElevated,
      title: Text(widget.title),
      content: SizedBox(
        width: 380,
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
              selected: {_word},
              onSelectionChanged: (v) => setState(() => _word = v.first),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _index,
              onChanged: (v) => setState(() => _index = v),
              title: const Text('Índice de escenas'),
              subtitle: Text(
                'Al principio, con la página de cada escena. Pulsando una '
                'línea se salta a ella.',
                style: AppTypography.caption(palette),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Sale con la tipografía de la hoja del guion técnico.',
              style: AppTypography.caption(palette),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, (word: _word, index: _index)),
          child: const Text('Exportar'),
        ),
      ],
    );
  }
}
