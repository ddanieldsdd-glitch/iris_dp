import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/rich_text/script_markup.dart';
import 'camera_links.dart';

/// Lista con casillas de los planos a los que va una cámara del esquema de
/// luz. Devuelve los identificadores marcados, o `null` si se cancela.
class LinkShotsDialog extends StatefulWidget {
  /// Letra de la cámara (A, B…).
  final String camera;
  final List<LinkableShot> options;

  const LinkShotsDialog({
    super.key,
    required this.camera,
    required this.options,
  });

  @override
  State<LinkShotsDialog> createState() => _LinkShotsDialogState();
}

class _LinkShotsDialogState extends State<LinkShotsDialog> {
  late final Set<int> _picked = {
    for (final o in widget.options)
      if (o.linked) o.shot.id,
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AlertDialog(
      backgroundColor: palette.surfaceElevated,
      title: Text(
        'Cámara ${widget.camera}: ¿en qué planos?',
        style: AppTypography.titleMedium(palette),
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cada plano marcado lleva esta cámara (una copia que la sigue '
              'mientras no la muevas en el plano) y usa esta luz. Un plano '
              'puede llevar varias: cámara A y B.',
              style: AppTypography.caption(palette),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final o in widget.options)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: _picked.contains(o.shot.id),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _picked.add(o.shot.id);
                        } else {
                          _picked.remove(o.shot.id);
                        }
                      }),
                      title: Text(
                        [
                          o.label,
                          if (o.shot.framing?.isNotEmpty == true)
                            scriptMarkupToPlain(o.shot.framing),
                        ].join(' · '),
                        style: AppTypography.bodyLarge(palette),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: _subtitle(o, palette),
                    ),
                ],
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
          child: const Text('Vincular'),
        ),
      ],
    );
  }

  Widget? _subtitle(LinkableShot o, AppPalette palette) {
    final others = o.linked
        ? (List.of(o.cameras)..remove(widget.camera))
        : o.cameras;
    if (others.isEmpty) return null;
    return Text(
      'Ya tiene cámara ${others.join(', ')}',
      style: AppTypography.caption(palette),
    );
  }
}
