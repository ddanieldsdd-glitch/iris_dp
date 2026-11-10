import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'camera_plan_constants.dart';
import 'floor_plan_json.dart';
import 'floor_plan_repository.dart';

/// Crea un esquema de luz para un set. Si su localización tiene luz general
/// (luces colocadas en la planta de la localización), pregunta si se empieza
/// vacío o con esas luces ya colocadas (una copia). Devuelve `null` si se
/// cancela.
Future<LightSetup?> createSetupForSet(
  BuildContext context,
  AppDatabase db, {
  required int projectId,
  required int setId,
}) => createSetupAsked(context, db, projectId: projectId, setId: setId);

/// Crea un set donde toque ([setId], o la luz general de [siteId], o libre)
/// y pregunta con qué empieza si hay de dónde partir: como [previous] (el
/// set que se estaba editando) o con la luz de su localización. Devuelve
/// `null` si se cancela.
Future<LightSetup?> createSetupAsked(
  BuildContext context,
  AppDatabase db, {
  required int projectId,
  int? setId,
  int? siteId,
  LightSetup? previous,
}) async {
  final repo = FloorPlanRepository(db);
  Future<LightSetup> empty() =>
      repo.createLightSetup(projectId: projectId, setId: setId, siteId: siteId);
  final sourceSite = setId == null
      ? null
      : (await db.getLocationById(setId))?.siteId;
  final sources = sourceSite == null
      ? const <LightSetup>[]
      : (await repo.siteLightSetups(
          projectId,
          sourceSite,
        )).where((s) => FloorPlanJson.decode(s.planJson).isNotEmpty).toList();
  final like =
      previous != null &&
          FloorPlanJson.decode(previous.planJson).isNotEmpty &&
          !sources.any((s) => s.id == previous.id)
      ? previous
      : null;
  if (sources.isEmpty && like == null) return empty();
  final site = sourceSite == null ? null : await db.getSiteById(sourceSite);
  if (!context.mounted) return null;
  final choice = await pickLightSetupStart(
    context,
    sources: sources,
    siteName: site?.name ?? 'la localización',
    previous: like,
  );
  if (choice == null) return null;
  final source = choice.source;
  if (source == null) return empty();
  return repo.createLightSetupFrom(source, setId: setId, siteId: siteId);
}

/// Con qué empieza un esquema nuevo: vacío (`source == null`) o con las
/// luces de [source].
typedef LightSetupStart = ({LightSetup? source});

/// Hoja «Nuevo esquema de luz»: vacío o desde un esquema de la luz general.
Future<LightSetupStart?> pickLightSetupStart(
  BuildContext context, {
  required List<LightSetup> sources,
  required String siteName,
  LightSetup? previous,
}) {
  final palette = context.palette;
  return showModalBottomSheet<LightSetupStart>(
    context: context,
    backgroundColor: palette.surfaceElevated,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Nuevo esquema de luz',
              style: AppTypography.titleMedium(palette),
            ),
          ),
          if (previous != null)
            ListTile(
              key: const ValueKey('setup-start-previous'),
              leading: Icon(Icons.content_copy, color: palette.accent),
              title: Text(
                'Como el set anterior · ${previous.name}',
                style: AppTypography.bodyLarge(palette),
              ),
              subtitle: Text(
                '${_lightCount(previous)} · una copia: lo que cambies en '
                'uno no pasa al otro',
                style: AppTypography.caption(palette),
              ),
              onTap: () => Navigator.pop(ctx, (source: previous)),
            ),
          ListTile(
            leading: Icon(Icons.crop_square, color: palette.textSecondary),
            title: Text('Vacío', style: AppTypography.bodyLarge(palette)),
            onTap: () => Navigator.pop(ctx, (source: null)),
          ),
          for (final setup in sources)
            ListTile(
              leading: Icon(Icons.lightbulb_outline, color: palette.accent),
              title: Text(
                'Con la luz de $siteName · ${setup.name}',
                style: AppTypography.bodyLarge(palette),
              ),
              subtitle: Text(
                '${_lightCount(setup)} · una copia: si cambias la '
                'localización, este esquema no cambia',
                style: AppTypography.caption(palette),
              ),
              onTap: () => Navigator.pop(ctx, (source: setup)),
            ),
        ],
      ),
    ),
  );
}

String _lightCount(LightSetup setup) {
  final n = FloorPlanJson.decode(
    setup.planJson,
  ).where((e) => e.type == ElementType.light).length;
  return n == 1 ? '1 luz' : '$n luces';
}

/// Lo que se pide al crear un set.
class NewSetRequest {
  final String name;

  /// Set del que se parte (su planta), o `null`.
  final LocationBasePlan? fromSet;

  /// Se parte de la localización (su entorno y su luz general).
  final bool fromSite;

  /// Copiar también las luces del origen.
  final bool includeLights;

  const NewSetRequest({
    required this.name,
    this.fromSet,
    this.fromSite = false,
    this.includeLights = false,
  });
}

/// Diálogo «Nuevo set»: nombre, desde dónde empieza (vacío, la localización
/// u otro set) y si se incluyen sus luces.
Future<NewSetRequest?> askNewSet(
  BuildContext context, {
  required String siteName,
  required List<LocationBasePlan> sets,
  required bool siteHasLights,
  required Set<int> setsWithLights,
}) {
  final palette = context.palette;
  final controller = TextEditingController();
  // -1 = vacío, 0 = localización, id = set.
  var from = -1;
  var includeLights = true;
  return showDialog<NewSetRequest>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, refresh) {
        final lightsAvailable =
            (from == 0 && siteHasLights) || setsWithLights.contains(from);
        void submit() {
          final name = controller.text.trim();
          if (name.isEmpty) return;
          Navigator.pop(
            ctx,
            NewSetRequest(
              name: name,
              fromSite: from == 0,
              fromSet: from > 0
                  ? sets.where((s) => s.id == from).firstOrNull
                  : null,
              includeLights: lightsAvailable && includeLights,
            ),
          );
        }

        return AlertDialog(
          backgroundColor: palette.surfaceElevated,
          title: Text(
            'Nuevo set en $siteName',
            style: AppTypography.titleMedium(palette),
          ),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Cocina, río, pasillo…',
                  ),
                  onSubmitted: (_) => submit(),
                ),
                const SizedBox(height: 16),
                Text('Empezar desde', style: AppTypography.caption(palette)),
                DropdownButton<int>(
                  isExpanded: true,
                  value: from,
                  dropdownColor: palette.surfaceElevated,
                  items: [
                    const DropdownMenuItem(value: -1, child: Text('Vacío')),
                    DropdownMenuItem(
                      value: 0,
                      child: Text('La localización ($siteName)'),
                    ),
                    for (final set in sets)
                      DropdownMenuItem(
                        value: set.id,
                        child: Text('El set ${set.locationName}'),
                      ),
                  ],
                  onChanged: (v) => refresh(() => from = v ?? -1),
                ),
                if (lightsAvailable)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: includeLights,
                    onChanged: (v) => refresh(() => includeLights = v ?? false),
                    title: Text(
                      'Incluir luces',
                      style: AppTypography.bodyLarge(palette),
                    ),
                    subtitle: Text(
                      'Copia sus esquemas de luz con las luces colocadas',
                      style: AppTypography.caption(palette),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            TextButton(onPressed: submit, child: const Text('Crear')),
          ],
        );
      },
    ),
  );
}
