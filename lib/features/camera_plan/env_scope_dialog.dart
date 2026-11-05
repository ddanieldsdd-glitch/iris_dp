import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// A quién afecta un cambio de entorno hecho desde un set (SG.3).
enum EnvScope {
  /// Solo a este set: se guarda como cambio suyo.
  thisSet,

  /// A los sets que se elijan.
  someSets,

  /// A todos los sets del grupo.
  group,

  /// A toda la localización: cambia el entorno definitivo.
  site,
}

/// La respuesta: el alcance, los sets (para [EnvScope.someSets] y
/// [EnvScope.group], sin contar este) y si se recuerda mientras se edita.
typedef EnvScopeAnswer = ({EnvScope scope, List<int> sets, bool remember});

/// «Has cambiado el entorno desde «Set 1». ¿A quién afecta?». `null` si se
/// cancela.
Future<EnvScopeAnswer?> askEnvScope(
  BuildContext context, {
  required LightSetup setup,
  required String siteName,
  required List<LightSetup> otherSets,
  SetGroup? group,
  List<LightSetup> groupSets = const [],
}) {
  return showDialog<EnvScopeAnswer>(
    context: context,
    builder: (_) => _EnvScopeDialog(
      setup: setup,
      siteName: siteName,
      otherSets: otherSets,
      group: group,
      groupSets: groupSets,
    ),
  );
}

class _EnvScopeDialog extends StatefulWidget {
  final LightSetup setup;
  final String siteName;
  final List<LightSetup> otherSets;
  final SetGroup? group;
  final List<LightSetup> groupSets;

  const _EnvScopeDialog({
    required this.setup,
    required this.siteName,
    required this.otherSets,
    required this.group,
    required this.groupSets,
  });

  @override
  State<_EnvScopeDialog> createState() => _EnvScopeDialogState();
}

class _EnvScopeDialogState extends State<_EnvScopeDialog> {
  EnvScope _scope = EnvScope.site;
  final _picked = <int>{};
  bool _remember = true;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final group = widget.group;
    final groupOthers = [
      for (final s in widget.groupSets)
        if (s.id != widget.setup.id) s,
    ];
    Widget option(EnvScope value, String title, String detail) =>
        RadioListTile<EnvScope>(
          key: ValueKey('env-scope-${value.name}'),
          value: value,
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(title, style: AppTypography.bodyMedium(palette)),
          subtitle: Text(detail, style: AppTypography.caption(palette)),
        );

    return AlertDialog(
      backgroundColor: palette.surfaceElevated,
      title: Text(
        'Has cambiado el entorno desde «${widget.setup.name}». '
        '¿A quién afecta?',
        style: AppTypography.titleMedium(palette),
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: RadioGroup<EnvScope>(
            groupValue: _scope,
            onChanged: (v) => setState(() => _scope = v ?? _scope),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                option(
                  EnvScope.site,
                  'A toda la localización',
                  'Cambia el entorno definitivo de «${widget.siteName}»: '
                      'lo ven todos sus sets.',
                ),
                if (group != null && groupOthers.isNotEmpty)
                  option(
                    EnvScope.group,
                    'Al grupo «${group.name}»',
                    'Este set y ${groupOthers.length} más con el mismo '
                        'fondo.',
                  ),
                if (widget.otherSets.isNotEmpty)
                  option(
                    EnvScope.someSets,
                    'A este set y a otros…',
                    'Elige con qué sets va el cambio.',
                  ),
                if (_scope == EnvScope.someSets)
                  Padding(
                    padding: const EdgeInsets.only(left: 32),
                    child: Column(
                      children: [
                        for (final s in widget.otherSets)
                          CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: _picked.contains(s.id),
                            onChanged: (v) => setState(
                              () => v == true
                                  ? _picked.add(s.id)
                                  : _picked.remove(s.id),
                            ),
                            title: Text(s.name),
                          ),
                      ],
                    ),
                  ),
                option(
                  EnvScope.thisSet,
                  'Solo a este set',
                  'El entorno de la localización no cambia; este set lo '
                      've con este cambio.',
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _remember,
                  onChanged: (v) => setState(() => _remember = v ?? true),
                  title: Text(
                    'No volver a preguntar mientras edito esta planta',
                    style: AppTypography.caption(palette),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Deshacer el cambio'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, (
            scope: _scope,
            sets: switch (_scope) {
              EnvScope.someSets => _picked.toList(),
              EnvScope.group => [for (final s in groupOthers) s.id],
              _ => const <int>[],
            },
            remember: _remember,
          )),
          child: const Text('Aplicar'),
        ),
      ],
    );
  }
}

/// A quién afecta cambiar una luz del grupo desde un set (SG.3).
enum GroupLightScope {
  /// La luz del grupo cambia en todos sus sets.
  group,

  /// Este set se queda con su versión (o sin la luz); el grupo no cambia.
  thisSet,
}

/// «Esta luz es del grupo…». `null` si se cancela.
Future<({GroupLightScope scope, bool remember})?> askGroupLightScope(
  BuildContext context, {
  required SetGroup group,
  required LightSetup setup,
  required int setCount,
}) {
  final palette = context.palette;
  var remember = true;
  return showDialog<({GroupLightScope scope, bool remember})>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        backgroundColor: palette.surfaceElevated,
        title: Text(
          'Es una luz del grupo «${group.name}»',
          style: AppTypography.titleMedium(palette),
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'La comparten $setCount sets. ¿Cambia en todos o solo en '
                '«${setup.name}»?',
                style: AppTypography.bodyMedium(palette),
              ),
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: remember,
                onChanged: (v) => setState(() => remember = v ?? true),
                title: Text(
                  'No volver a preguntar mientras edito esta planta',
                  style: AppTypography.caption(palette),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Deshacer el cambio'),
          ),
          TextButton(
            key: const ValueKey('group-light-this'),
            onPressed: () => Navigator.pop(ctx, (
              scope: GroupLightScope.thisSet,
              remember: remember,
            )),
            child: const Text('Solo este set'),
          ),
          FilledButton(
            key: const ValueKey('group-light-all'),
            onPressed: () => Navigator.pop(ctx, (
              scope: GroupLightScope.group,
              remember: remember,
            )),
            child: const Text('Todo el grupo'),
          ),
        ],
      ),
    ),
  );
}
