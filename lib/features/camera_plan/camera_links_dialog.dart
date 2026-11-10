import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/rich_text/script_markup.dart';
import 'camera_links.dart';
import 'camera_shot_sync.dart';
import 'shot_cover.dart';

/// Los planos a los que va una cámara del set, en una rejilla con su
/// storyboard o su referencia (SG.4). Devuelve los identificadores
/// marcados, o `null` si se cancela.
class LinkShotsDialog extends StatefulWidget {
  /// Letra de la cámara (A, B…).
  final String camera;
  final List<LinkableShot> options;

  /// La escena que se está mirando: sus planos salen primero.
  final int? sceneId;

  /// Lleva a la fila de un plano en el guion técnico.
  final void Function(int shotId)? onShowInScript;

  const LinkShotsDialog({
    super.key,
    required this.camera,
    required this.options,
    this.sceneId,
    this.onShowInScript,
  });

  @override
  State<LinkShotsDialog> createState() => _LinkShotsDialogState();
}

class _LinkShotsDialogState extends State<LinkShotsDialog> {
  late final Set<int> _picked = {
    for (final o in widget.options)
      if (o.linked) o.shot.id,
  };

  /// Escena que se enseña; `null` = todas.
  late int? _scene = _initialScene();

  int? _initialScene() {
    final scenes = {for (final o in widget.options) o.shot.sceneId};
    if (scenes.length < 2) return null;
    if (widget.sceneId != null && scenes.contains(widget.sceneId)) {
      return widget.sceneId;
    }
    return widget.options.where((o) => o.linked).firstOrNull?.shot.sceneId;
  }

  List<LinkableShot> get _shown => _scene == null
      ? widget.options
      : widget.options.where((o) => o.shot.sceneId == _scene).toList();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final scenes = <int, String>{
      for (final o in widget.options)
        o.shot.sceneId: o.scene == null
            ? 'Sin escena'
            : 'Esc ${o.scene!.label}',
    };
    return AlertDialog(
      backgroundColor: palette.surfaceElevated,
      title: Text(
        'Cámara ${widget.camera}: ¿qué planos?',
        style: AppTypography.titleMedium(palette),
      ),
      content: SizedBox(
        width: 620,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cada plano marcado lleva esta cámara y usa la luz de este set. '
              'La cámara toma la focal y el movimiento del guion técnico; si '
              'el plano no los tiene, se los pone la cámara.',
              style: AppTypography.caption(palette),
            ),
            if (scenes.length > 1) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final e in scenes.entries)
                    ChoiceChip(
                      label: Text(e.value),
                      selected: _scene == e.key,
                      onSelected: (_) => setState(() => _scene = e.key),
                    ),
                  ChoiceChip(
                    label: const Text('Todos'),
                    selected: _scene == null,
                    onSelected: (_) => setState(() => _scene = null),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Flexible(
              child: GridView.extent(
                shrinkWrap: true,
                maxCrossAxisExtent: 150,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.82,
                children: [for (final o in _shown) _card(o, palette)],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _picked),
          child: Text(
            _picked.isEmpty
                ? 'Sin planos'
                : 'Vincular ${_picked.length} '
                      'plano${_picked.length == 1 ? '' : 's'}',
          ),
        ),
      ],
    );
  }

  Widget _card(LinkableShot o, AppPalette palette) {
    final on = _picked.contains(o.shot.id);
    final cover = shotCoverThumbnail(o.shot, cacheWidth: 300);
    final others = o.linked
        ? (List.of(o.cameras)..remove(widget.camera))
        : o.cameras;
    final tech = [
      if (o.shot.framing?.isNotEmpty == true)
        scriptMarkupToPlain(o.shot.framing),
      CameraShotSync.lensLabel(o.shot.lens) ?? 'sin focal',
      if (o.shot.movement?.isNotEmpty == true) o.shot.movement!,
    ].join(' · ');
    return Semantics(
      selected: on,
      button: true,
      label: '${o.label}, $tech',
      child: InkWell(
        key: ValueKey('link-shot-${o.shot.id}'),
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() {
          if (!_picked.remove(o.shot.id)) _picked.add(o.shot.id);
        }),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: on ? palette.accent : palette.border,
              width: on ? 2 : 0.5,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    cover ??
                        ColoredBox(
                          color: palette.surface,
                          child: Icon(
                            Icons.image_outlined,
                            color: palette.textTertiary,
                          ),
                        ),
                    if (widget.onShowInScript case final show?)
                      Positioned(
                        top: 0,
                        left: 0,
                        child: IconButton(
                          key: ValueKey('link-script-${o.shot.id}'),
                          tooltip: 'Ver en el guion',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.table_rows_outlined, size: 18),
                          onPressed: () => show(o.shot.id),
                        ),
                      ),
                    if (on)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Icon(Icons.check_circle, color: palette.accent),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      o.label,
                      style: AppTypography.bodyMedium(
                        palette,
                      ).copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      tech,
                      style: AppTypography.caption(palette),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (others.isNotEmpty)
                      Text(
                        'Ya tiene cámara ${others.join(', ')}',
                        style: AppTypography.caption(
                          palette,
                        ).copyWith(color: palette.warning),
                        maxLines: 1,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pregunta una vez qué manda cuando la cámara y algún plano no dicen lo
/// mismo (focal o movimiento). `null` si se cancela.
Future<CameraShotSource?> askCameraShotSource(
  BuildContext context, {
  required String camera,
  required List<String> shots,
}) {
  final palette = context.palette;
  return showDialog<CameraShotSource>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: palette.surfaceElevated,
      title: Text(
        'La cámara $camera y el guion no coinciden',
        style: AppTypography.titleMedium(palette),
      ),
      content: Text(
        '${shots.join(', ')} ${shots.length == 1 ? 'tiene' : 'tienen'} otra '
        'focal o movimiento en el guion técnico. ¿Cuál se queda?',
        style: AppTypography.bodyMedium(palette),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, CameraShotSource.plan),
          child: const Text('La de la planta'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, CameraShotSource.script),
          child: const Text('La del guion'),
        ),
      ],
    ),
  );
}
