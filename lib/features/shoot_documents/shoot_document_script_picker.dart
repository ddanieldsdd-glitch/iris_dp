import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/rich_text/script_markup.dart';

/// Escenas y planos del guion técnico elegidos para un documento de rodaje,
/// en el orden del guion.
class ScriptSelection {
  final List<({Scene scene, List<Shot> shots})> scenes;
  const ScriptSelection(this.scenes);

  int get shotCount => scenes.fold(0, (n, s) => n + s.shots.length);
}

/// Deja elegir escenas y planos del guion técnico. Los planos de
/// [alreadyInDocument] salen marcados y no se pueden volver a añadir.
Future<ScriptSelection?> showShootDocumentScriptPicker(
  BuildContext context, {
  required AppDatabase db,
  required int projectId,
  required Set<int> alreadyInDocument,
}) async {
  final scenes = await db.watchScenesForProject(projectId).first;
  final shots = await db.getShotsForProject(projectId);
  if (!context.mounted) return null;
  final shotsByScene = <int, List<Shot>>{};
  for (final shot in shots) {
    shotsByScene.putIfAbsent(shot.sceneId, () => []).add(shot);
  }
  return showDialog<ScriptSelection>(
    context: context,
    builder: (_) => _ScriptPickerDialog(
      scenes: scenes,
      shotsByScene: shotsByScene,
      alreadyInDocument: alreadyInDocument,
    ),
  );
}

class _ScriptPickerDialog extends StatefulWidget {
  final List<Scene> scenes;
  final Map<int, List<Shot>> shotsByScene;
  final Set<int> alreadyInDocument;

  const _ScriptPickerDialog({
    required this.scenes,
    required this.shotsByScene,
    required this.alreadyInDocument,
  });

  @override
  State<_ScriptPickerDialog> createState() => _ScriptPickerDialogState();
}

class _ScriptPickerDialogState extends State<_ScriptPickerDialog> {
  final Set<int> _picked = {};

  List<Shot> _available(Scene scene) => [
    for (final s in widget.shotsByScene[scene.id] ?? const <Shot>[])
      if (!widget.alreadyInDocument.contains(s.id)) s,
  ];

  /// true = todos, false = ninguno, null = algunos.
  bool? _sceneState(Scene scene) {
    final available = _available(scene);
    if (available.isEmpty) return false;
    final n = available.where((s) => _picked.contains(s.id)).length;
    if (n == 0) return false;
    return n == available.length ? true : null;
  }

  void _toggleScene(Scene scene) {
    final available = _available(scene);
    final all = _sceneState(scene) == true;
    setState(() {
      for (final s in available) {
        all ? _picked.remove(s.id) : _picked.add(s.id);
      }
    });
  }

  ScriptSelection _selection() => ScriptSelection([
    for (final scene in widget.scenes)
      if (_available(scene).any((s) => _picked.contains(s.id)))
        (
          scene: scene,
          shots: [
            for (final s in _available(scene))
              if (_picked.contains(s.id)) s,
          ],
        ),
  ]);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final count = _picked.length;

    return AlertDialog(
      backgroundColor: palette.surfaceElevated,
      title: Text(
        'Escenas y planos del guion técnico',
        style: AppTypography.titleMedium(palette),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      content: SizedBox(
        width: 560,
        height: 520,
        child: widget.scenes.isEmpty
            ? Center(
                child: Text(
                  'El guion técnico no tiene escenas.',
                  style: AppTypography.bodyMedium(palette),
                ),
              )
            : ListView(
                children: [
                  for (final scene in widget.scenes) _sceneTile(scene, palette),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar', style: AppTypography.bodyMedium(palette)),
        ),
        FilledButton(
          onPressed: count == 0
              ? null
              : () => Navigator.pop(context, _selection()),
          child: Text(
            count == 0
                ? 'Añadir'
                : count == 1
                ? 'Añadir 1 plano'
                : 'Añadir $count planos',
          ),
        ),
      ],
    );
  }

  Widget _sceneTile(Scene scene, AppPalette palette) {
    final shots = widget.shotsByScene[scene.id] ?? const <Shot>[];
    final available = _available(scene);
    return ExpansionTile(
      controlAffinity: ListTileControlAffinity.trailing,
      leading: Checkbox(
        tristate: true,
        value: _sceneState(scene),
        onChanged: available.isEmpty ? null : (_) => _toggleScene(scene),
      ),
      title: Text(
        '${scene.label}. ${scene.locationCanonical}',
        style: AppTypography.bodyLarge(palette),
      ),
      subtitle: Text(
        shots.isEmpty
            ? 'Sin planos'
            : shots.length == 1
            ? '1 plano'
            : '${shots.length} planos',
        style: AppTypography.caption(palette),
      ),
      children: [
        for (final shot in shots)
          CheckboxListTile(
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: const EdgeInsets.only(left: 56, right: 16),
            value:
                widget.alreadyInDocument.contains(shot.id) ||
                _picked.contains(shot.id),
            onChanged: widget.alreadyInDocument.contains(shot.id)
                ? null
                : (v) => setState(
                    () => v == true
                        ? _picked.add(shot.id)
                        : _picked.remove(shot.id),
                  ),
            title: Text(
              [
                'Plano ${shot.number}',
                if ((scriptMarkupToPlain(shot.framing)).trim().isNotEmpty)
                  scriptMarkupToPlain(shot.framing).trim(),
              ].join(' · '),
              style: AppTypography.bodyMedium(palette),
            ),
            subtitle: widget.alreadyInDocument.contains(shot.id)
                ? Text(
                    'Ya está en el documento',
                    style: AppTypography.caption(palette),
                  )
                : null,
          ),
      ],
    );
  }
}
