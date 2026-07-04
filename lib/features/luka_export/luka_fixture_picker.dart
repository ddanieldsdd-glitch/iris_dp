import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../camera_plan/camera_plan_element_model.dart';
import 'luka_light_mapping.dart';

/// Selector de fixture LUKA desde catálogo de equipo + defaults ARRI.
class LukaFixturePicker extends ConsumerWidget {
  final PlanElement element;
  final VoidCallback onChanged;

  const LukaFixturePicker({
    super.key,
    required this.element,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    return StreamBuilder<List<Light>>(
      stream: db.watchAllLights(),
      builder: (context, snap) {
        final catalog = snap.data ?? [];
        final options = LukaLightMapping.fixtureOptions(catalog);
        final currentId = element.lukaFixtureId;
        final validValue = options.any((o) => o.id == currentId)
            ? currentId
            : (options.isNotEmpty ? options.first.id : null);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Fixture ARRI LUKA',
                style: AppTypography.caption(palette),
              ),
              subtitle: element.lukaCompatible && element.lukaFixtureId != null
                  ? Text(
                      LukaLightMapping.labelForFixtureId(
                            element.lukaFixtureId,
                            catalog: catalog,
                          ) ??
                          element.lukaFixtureId!,
                      style: AppTypography.caption(palette).copyWith(
                        color: palette.accent,
                        fontSize: 10,
                      ),
                    )
                  : null,
              value: element.lukaCompatible,
              onChanged: (v) {
                element.lukaCompatible = v;
                if (v && element.lukaFixtureId == null) {
                  LukaLightMapping.applyDefaults(
                    element,
                    catalog: catalog,
                  );
                }
                if (!v) element.lukaFixtureId = null;
                onChanged();
              },
            ),
            if (element.lukaCompatible) ...[
              Text('Modelo LUKA', style: AppTypography.caption(palette)),
              const SizedBox(height: 4),
              if (options.isEmpty)
                Text(
                  'Sin luces LUKA en catálogo. Usa Equipo → Luces.',
                  style: AppTypography.caption(palette),
                )
              else
                DropdownButtonFormField<String>(
                  value: validValue,
                  decoration: const InputDecoration(isDense: true),
                  items: [
                    for (final o in options)
                      DropdownMenuItem(
                        value: o.id,
                        child: Text(o.label, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (id) {
                    element.lukaFixtureId = id;
                    onChanged();
                  },
                ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () {
                  LukaLightMapping.applyDefaults(element, catalog: catalog);
                  onChanged();
                },
                child: Text(
                  'Auto (catálogo / tipo)',
                  style: AppTypography.caption(palette).copyWith(
                    color: palette.accent,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
