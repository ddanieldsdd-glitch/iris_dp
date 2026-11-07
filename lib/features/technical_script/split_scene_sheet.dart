import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/scene_text_parts.dart';
import '../../core/utils/user_error.dart';
import '../../core/widgets/app_snackbar.dart';

/// Parte una escena en dos eligiendo por dónde se corta su texto y qué planos
/// van a la segunda.
Future<void> showSplitSceneSheet(BuildContext context, Scene scene) {
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: context.palette.surfaceElevated,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
        child: SplitScenePanel(scene: scene),
      ),
    ),
  );
}

class SplitScenePanel extends ConsumerStatefulWidget {
  final Scene scene;

  const SplitScenePanel({super.key, required this.scene});

  @override
  ConsumerState<SplitScenePanel> createState() => _SplitScenePanelState();
}

class _SplitScenePanelState extends ConsumerState<SplitScenePanel> {
  late final List<String> _sentences = sceneTextSentences(
    widget.scene.actionText,
  );

  /// Primera frase de la segunda parte.
  late int _cut = _sentences.length ~/ 2;
  final _second = <int>{};
  List<Shot> _shots = const [];
  ({String first, String second})? _letters;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final shots = await db.watchShotsForScene(widget.scene.id).first;
    final scenes = await db.watchScenesForProject(widget.scene.projectId).first;
    if (!mounted) return;
    setState(() {
      _shots = shots;
      _letters = splitSceneSuffixes(widget.scene.numberSuffix, [
        for (final s in scenes)
          if (s.number == widget.scene.number) s.numberSuffix,
      ]);
    });
  }

  String _label(String letter) => '${widget.scene.number}$letter';

  Future<void> _split() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(databaseProvider)
          .splitScene(
            sceneId: widget.scene.id,
            firstText: _sentences.take(_cut).join(' '),
            secondText: _sentences.skip(_cut).join(' '),
            shotIdsForSecond: _second,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        AppSnackBar.showError(context, userFriendlyError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final letters = _letters;
    if (letters == null) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final a = _label(letters.first), b = _label(letters.second);
    Widget title(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(0, AppSpacing.md, 0, 4),
      child: Text(text, style: AppTypography.label(palette)),
    );
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Dividir la escena ${widget.scene.label} en $a y $b',
            style: AppTypography.titleMedium(palette),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                if (_sentences.length > 1) ...[
                  title('Toca la frase con la que empieza $b'),
                  for (var i = 0; i < _sentences.length; i++)
                    InkWell(
                      onTap: i == 0 ? null : () => setState(() => _cut = i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: i == _cut
                                  ? palette.accent
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 44,
                              child: Text(
                                i < _cut ? a : b,
                                style: AppTypography.caption(palette),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                _sentences[i],
                                style: AppTypography.bodyMedium(palette),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
                if (_shots.isNotEmpty) ...[
                  title('Planos que pasan a $b'),
                  for (final shot in _shots)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _second.contains(shot.id),
                      title: Text(
                        'Plano ${shot.number}',
                        style: AppTypography.bodyMedium(palette),
                      ),
                      subtitle: (shot.action ?? '').trim().isEmpty
                          ? null
                          : Text(
                              shot.action!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                      onChanged: (v) => setState(() {
                        v == true
                            ? _second.add(shot.id)
                            : _second.remove(shot.id);
                      }),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton(
                onPressed: _busy ? null : _split,
                child: Text('Dividir en $a y $b'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
