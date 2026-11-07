import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/scene_text_parts.dart';

/// Elige frases del guion literario para la acción de un plano. Devuelve el
/// texto elegido; se copia, así que luego se edita libremente.
Future<String?> showSceneActionPicker(
  BuildContext context, {
  required int projectId,
  required int sceneId,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: context.palette.surfaceElevated,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 680),
        child: SceneActionPanel(projectId: projectId, sceneId: sceneId),
      ),
    ),
  );
}

class SceneActionPanel extends ConsumerStatefulWidget {
  final int projectId;
  final int sceneId;

  const SceneActionPanel({
    super.key,
    required this.projectId,
    required this.sceneId,
  });

  @override
  ConsumerState<SceneActionPanel> createState() => _SceneActionPanelState();
}

class _SceneActionPanelState extends ConsumerState<SceneActionPanel> {
  List<Scene> _scenes = const [];
  late int _sceneId = widget.sceneId;
  final _picked = <int>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final scenes = await ref
        .read(databaseProvider)
        .watchScenesForProject(widget.projectId)
        .first;
    if (mounted) setState(() => _scenes = scenes);
  }

  Scene? get _scene =>
      _scenes.where((s) => s.id == _sceneId).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final sentences = sceneTextSentences(_scene?.actionText);
    final allPicked =
        sentences.isNotEmpty && _picked.length == sentences.length;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Acción desde el guion', style: AppTypography.titleMedium(palette)),
          const SizedBox(height: AppSpacing.sm),
          if (_scenes.isNotEmpty)
            DropdownButton<int>(
              value: _sceneId,
              isExpanded: true,
              items: [
                for (final s in _scenes)
                  DropdownMenuItem(
                    value: s.id,
                    child: Text(
                      '${s.label}. ${s.locationCanonical}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (id) => setState(() {
                _sceneId = id ?? _sceneId;
                _picked.clear();
              }),
            ),
          Flexible(
            child: sentences.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      'Esta escena no tiene texto del guion literario.',
                      style: AppTypography.bodyMedium(palette),
                    ),
                  )
                : ListView(
                    shrinkWrap: true,
                    children: [
                      for (var i = 0; i < sentences.length; i++)
                        CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: _picked.contains(i),
                          title: Text(
                            sentences[i],
                            style: AppTypography.bodyMedium(palette),
                          ),
                          onChanged: (v) => setState(() {
                            v == true ? _picked.add(i) : _picked.remove(i);
                          }),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              TextButton(
                onPressed: sentences.isEmpty
                    ? null
                    : () => setState(() {
                        _picked.clear();
                        if (!allPicked) {
                          _picked.addAll(
                            List.generate(sentences.length, (i) => i),
                          );
                        }
                      }),
                child: Text(allPicked ? 'Quitar todo' : 'Elegir todo'),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton(
                onPressed: _picked.isEmpty
                    ? null
                    : () => Navigator.of(context).pop(
                        [
                          for (var i = 0; i < sentences.length; i++)
                            if (_picked.contains(i)) sentences[i],
                        ].join(' '),
                      ),
                child: const Text('Añadir a la acción'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
