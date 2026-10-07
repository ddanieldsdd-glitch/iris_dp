import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/script/script_scene_matcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// Enseña qué va a cambiar en el guion técnico al aplicar una versión nueva
/// del guion, y deja corregir los emparejamientos. Devuelve, por cada escena
/// del guion nuevo, el id de la escena del proyecto con la que se une (nulo =
/// escena nueva), o nulo si se cancela.
Future<List<int?>?> showScriptUpdateReview(
  BuildContext context, {
  required ScriptSceneMatch match,
  required List<WorkspaceScene> incoming,
  required List<Scene> existing,
  required Map<int, int> shotCounts,
}) {
  return showDialog<List<int?>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ScriptUpdateReview(
      match: match,
      incoming: incoming,
      existing: existing,
      shotCounts: shotCounts,
    ),
  );
}

class _ScriptUpdateReview extends StatefulWidget {
  final ScriptSceneMatch match;
  final List<WorkspaceScene> incoming;
  final List<Scene> existing;
  final Map<int, int> shotCounts;

  const _ScriptUpdateReview({
    required this.match,
    required this.incoming,
    required this.existing,
    required this.shotCounts,
  });

  @override
  State<_ScriptUpdateReview> createState() => _ScriptUpdateReviewState();
}

class _ScriptUpdateReviewState extends State<_ScriptUpdateReview> {
  late final List<int?> _links = [
    for (final l in widget.match.links) l.existingId,
  ];
  late final Map<int, Scene> _byId = {for (final s in widget.existing) s.id: s};
  late final Map<int, ScriptSceneChange> _proposed = {
    for (final l in widget.match.links) l.incomingIndex: l.change,
  };

  String _newHeading(int i) {
    final s = widget.incoming[i];
    return '${i + 1}. ${s.intExt}. ${s.location} - ${s.dayNight}';
  }

  String _oldHeading(Scene s) => '${s.number}. ${s.locationCanonical}';

  int _shots(int sceneId) => widget.shotCounts[sceneId] ?? 0;

  String _shotsLabel(int n) => n == 1 ? '1 plano' : '$n planos';

  bool _headingDiffers(int i) {
    final old = _byId[_links[i]];
    if (old == null) return false;
    final s = widget.incoming[i];
    final oldKey =
        old.scriptHeadingKey ??
        scriptHeadingKey(
          intExt: old.intExt,
          location: old.locationCanonical
              .replaceFirst(RegExp(r'^[^.]*\.\s*'), '')
              .replaceFirst(RegExp(r'\s+-\s+[^-]*$'), ''),
          dayNight: old.dayNight,
        );
    return oldKey !=
        scriptHeadingKey(
          intExt: s.intExt,
          location: s.location,
          dayNight: s.dayNight,
        );
  }

  List<Scene> get _unlinked => [
    for (final s in widget.existing)
      if (!_links.contains(s.id)) s,
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final added = [
      for (var i = 0; i < _links.length; i++)
        if (_links[i] == null) i,
    ];
    final headingChanged = [
      for (var i = 0; i < _links.length; i++)
        if (_links[i] != null && _headingDiffers(i)) i,
    ];
    final textChanged = [
      for (var i = 0; i < _links.length; i++)
        if (_links[i] != null &&
            !_headingDiffers(i) &&
            _proposed[i] == ScriptSceneChange.textChanged)
          i,
    ].length;
    final unlinked = _unlinked;
    final kept = unlinked.where((s) => _shots(s.id) > 0).toList();
    final dropped = unlinked.where((s) => _shots(s.id) == 0).toList();
    final unchanged =
        _links.length - added.length - headingChanged.length - textChanged;

    Widget chip(String text, {Color? color}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (color ?? palette.textTertiary).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: AppTypography.caption(
          palette,
        ).copyWith(color: color ?? palette.textSecondary),
      ),
    );

    Widget section(String title, List<Widget> rows) => rows.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: AppTypography.label(palette)),
                const SizedBox(height: 6),
                ...rows,
              ],
            ),
          );

    Widget row({
      required IconData icon,
      required Color color,
      required Widget body,
      Widget? action,
    }) => Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(child: body),
          if (action != null) action,
        ],
      ),
    );

    final body = AppTypography.bodyMedium(
      palette,
    ).copyWith(color: palette.textPrimary);
    final dim = AppTypography.caption(palette);

    return Dialog(
      backgroundColor: palette.surfaceElevated,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Actualizar el guion técnico',
                style: AppTypography.titleLarge(palette),
              ),
              const SizedBox(height: 6),
              Text(
                'Esto es lo que cambia con esta versión del guion. No se '
                'borra ningún plano.',
                style: AppTypography.bodyMedium(palette),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  chip(
                    unchanged == 1 ? '1 sin cambios' : '$unchanged sin cambios',
                  ),
                  if (textChanged > 0) chip('$textChanged con texto nuevo'),
                  if (headingChanged.isNotEmpty)
                    chip(
                      '${headingChanged.length} con otra cabecera',
                      color: palette.highlightYellow.withValues(alpha: 1),
                    ),
                  if (added.isNotEmpty)
                    chip(
                      added.length == 1 ? '1 nueva' : '${added.length} nuevas',
                      color: palette.accent,
                    ),
                  if (unlinked.isNotEmpty)
                    chip(
                      unlinked.length == 1
                          ? '1 ya no está'
                          : '${unlinked.length} ya no están',
                      color: palette.error,
                    ),
                ],
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      section('Cambia la cabecera', [
                        for (final i in headingChanged)
                          row(
                            icon: Icons.swap_horiz,
                            color: palette.textSecondary,
                            body: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_newHeading(i), style: body),
                                Text(
                                  'antes: ${_oldHeading(_byId[_links[i]]!)} · '
                                  '${_shotsLabel(_shots(_links[i]!))}',
                                  style: dim,
                                ),
                              ],
                            ),
                            action: TextButton(
                              onPressed: () => setState(() => _links[i] = null),
                              child: const Text('No es la misma'),
                            ),
                          ),
                      ]),
                      section('Escenas nuevas', [
                        for (final i in added)
                          row(
                            icon: Icons.add_circle_outline,
                            color: palette.accent,
                            body: Text(_newHeading(i), style: body),
                            action: unlinked.isEmpty
                                ? null
                                : PopupMenuButton<int>(
                                    tooltip:
                                        'Unirla a una escena que ya tienes',
                                    color: palette.surfaceElevated,
                                    onSelected: (id) =>
                                        setState(() => _links[i] = id),
                                    itemBuilder: (_) => [
                                      for (final s in unlinked)
                                        PopupMenuItem(
                                          value: s.id,
                                          child: Text(
                                            '${_oldHeading(s)} · '
                                            '${_shotsLabel(_shots(s.id))}',
                                          ),
                                        ),
                                    ],
                                    child: Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Text(
                                        'Es en realidad…',
                                        style: AppTypography.bodyMedium(
                                          palette,
                                        ).copyWith(color: palette.accent),
                                      ),
                                    ),
                                  ),
                          ),
                      ]),
                      section('Ya no están en el guion', [
                        for (final s in kept)
                          row(
                            icon: Icons.inventory_2_outlined,
                            color: palette.textSecondary,
                            body: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_oldHeading(s), style: body),
                                Text(
                                  'Tiene ${_shotsLabel(_shots(s.id))}: se '
                                  'conserva aparte, fuera del guion.',
                                  style: dim,
                                ),
                              ],
                            ),
                          ),
                        for (final s in dropped)
                          row(
                            icon: Icons.delete_outline,
                            color: palette.textTertiary,
                            body: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_oldHeading(s), style: body),
                                Text(
                                  'No tiene planos: se elimina.',
                                  style: dim,
                                ),
                              ],
                            ),
                          ),
                      ]),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancelar',
                      style: AppTypography.bodyMedium(palette),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, _links),
                    child: const Text('Aplicar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
