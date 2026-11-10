import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/sync/plan_library_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_snackbar.dart';
import 'camera_plan_constants.dart';
import 'floor_plan_json.dart';
import 'floor_plan_repository.dart';
import 'light_setup_actions.dart';

/// Pasar sets y esquemas de luz entre la base de un proyecto y la biblioteca.
class PlanLibrary {
  final AppDatabase db;

  PlanLibrary(this.db);

  /// La planta sin lo que solo tiene sentido en su proyecto: el fondo es un
  /// archivo de allí, y la sección y las luces ocultas del grupo, también.
  static String portable(String? json) {
    final doc = FloorPlanJson.decodeDocument(json);
    return FloorPlanJson.encodeDocument(
      FloorPlanDocument(
        elements: doc.elements,
        metersPerUnit: doc.metersPerUnit,
        ambient: doc.ambient,
        environment: doc.environment,
      ),
    );
  }

  static PlanLibraryScheme _scheme(LightSetup setup) => PlanLibraryScheme(
    name: setup.name,
    planJson: portable(setup.planJson),
    category: setup.category,
  );

  PlanLibraryEntry saveSetup(
    PlanLibraryStore store,
    LightSetup setup, {
    required String name,
  }) => store.add(name: name, schemes: [_scheme(setup)]);

  Future<PlanLibraryEntry> saveSet(
    PlanLibraryStore store,
    LocationBasePlan set, {
    required String name,
  }) async {
    final setups = (await db.getLightSetupsForProject(set.projectId))
        .where(
          (s) =>
              s.locationBasePlanId == set.id && s.kind == LightSetupKind.plan,
        )
        .toList();
    return store.add(
      name: name,
      setPlanJson: portable(set.floorPlanJson),
      schemes: [for (final s in setups) _scheme(s)],
    );
  }

  Future<LightSetup> _insertScheme(
    FloorPlanRepository repo,
    PlanLibraryScheme scheme, {
    required int projectId,
    int? setId,
    int? siteId,
  }) async {
    final taken = (await db.getLightSetupsForProject(projectId))
        .where(
          (s) => s.locationBasePlanId == setId && s.locationSiteId == siteId,
        )
        .map((s) => s.name)
        .toSet();
    var name = scheme.name;
    while (taken.contains(name)) {
      name = '$name (copia)';
    }
    final created = await repo.createLightSetup(
      projectId: projectId,
      setId: setId,
      siteId: siteId,
      name: name,
    );
    final filled = created.copyWith(
      planJson: Value(FloorPlanRepository.renewedPlanJson(scheme.planJson)),
      category: Value(scheme.category),
    );
    await db.updateLightSetup(filled);
    return filled;
  }

  /// Un esquema nuevo con las luces de [scheme]. Es una copia con
  /// identificadores propios: la biblioteca no cambia si se edita.
  Future<LightSetup> createSetup(
    PlanLibraryScheme scheme, {
    required int projectId,
    int? setId,
    int? siteId,
  }) => _insertScheme(
    FloorPlanRepository(db),
    scheme,
    projectId: projectId,
    setId: setId,
    siteId: siteId,
  );

  /// Un set nuevo en [siteId] con la planta y los esquemas de [entry].
  Future<LocationBasePlan> createSet(
    PlanLibraryEntry entry, {
    required int projectId,
    required int siteId,
    required String name,
  }) async {
    final repo = FloorPlanRepository(db);
    final siblings = (await db.getLocationsMapForProject(
      projectId,
    )).values.where((l) => l.siteId == siteId).length;
    final id = await db.insertLocation(
      LocationBasePlansCompanion.insert(
        projectId: projectId,
        siteId: Value(siteId),
        locationName: name,
        floorPlanJson: Value(
          FloorPlanRepository.renewedPlanJson(entry.setPlanJson),
        ),
        sortOrder: Value(siblings),
      ),
    );
    for (final scheme in entry.schemes) {
      await _insertScheme(repo, scheme, projectId: projectId, setId: id);
    }
    return (await db.getLocationById(id))!;
  }
}

String _lightsOf(String planJson) {
  final n = FloorPlanJson.decode(
    planJson,
  ).where((e) => e.type == ElementType.light).length;
  return n == 1 ? '1 luz' : '$n luces';
}

/// «Con su planta · 2 esquemas» o «12 luces».
String planLibrarySummary(PlanLibraryEntry entry) {
  if (!entry.isSet) {
    return entry.schemes.isEmpty
        ? 'Vacío'
        : _lightsOf(entry.schemes.first.planJson);
  }
  final n = entry.schemes.length;
  return 'Set con su planta · $n esquema${n == 1 ? '' : 's'} de luz';
}

/// Las entradas que aportan algún esquema de luz.
List<PlanLibraryEntry> planLibraryEntriesWithSchemes(
  List<PlanLibraryEntry> entries,
) => entries.where((e) => e.schemes.isNotEmpty).toList();

/// Lo que se puede empezar desde la biblioteca: cada esquema, suelto o de un
/// set, con su nombre.
List<({String title, String subtitle, PlanLibraryScheme scheme})>
planLibrarySchemes(List<PlanLibraryEntry> entries) => [
  for (final entry in entries)
    for (final scheme in entry.schemes)
      (
        title: entry.isSet ? '${entry.name} · ${scheme.name}' : entry.name,
        subtitle: _lightsOf(scheme.planJson),
        scheme: scheme,
      ),
];

/// Pide el nombre y guarda en la biblioteca lo que haga [save].
Future<void> saveToPlanLibrary(
  BuildContext context, {
  required String initialName,
  required FutureOr<void> Function(PlanLibraryStore store, String name) save,
}) async {
  final store = await PlanLibraryStore.open();
  if (store == null || !context.mounted) return;
  final name = await askPlanName(
    context,
    title: 'Guardar en la biblioteca',
    initial: initialName,
  );
  if (name == null || name.trim().isEmpty) return;
  await save(store, name.trim());
  unawaited(store.sync());
  if (context.mounted) {
    AppSnackBar.show(
      context,
      '«${name.trim()}» está en la biblioteca: ya se puede usar en cualquier '
      'proyecto.',
    );
  }
}

/// Ver, renombrar y borrar lo guardado.
Future<void> showPlanLibrary(BuildContext context) async {
  final store = await PlanLibraryStore.open();
  if (store == null || !context.mounted) return;
  unawaited(store.sync());
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.palette.surfaceElevated,
    isScrollControlled: true,
    builder: (_) => PlanLibrarySheet(store: store),
  );
}

class PlanLibrarySheet extends StatefulWidget {
  final PlanLibraryStore store;

  const PlanLibrarySheet({super.key, required this.store});

  @override
  State<PlanLibrarySheet> createState() => _PlanLibrarySheetState();
}

class _PlanLibrarySheetState extends State<PlanLibrarySheet> {
  Future<void> _rename(PlanLibraryEntry entry) async {
    final name = await askPlanName(
      context,
      title: 'Nombre en la biblioteca',
      initial: entry.name,
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    widget.store.rename(entry, name.trim());
    unawaited(widget.store.sync());
    setState(() {});
  }

  Future<void> _remove(PlanLibraryEntry entry) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Quitar «${entry.name}» de la biblioteca?'),
        content: const Text(
          'Los sets y esquemas que ya creaste a partir de él no cambian.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            key: const ValueKey('library-remove-yes'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    widget.store.remove(entry);
    unawaited(widget.store.sync());
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final entries = widget.store.list();
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Biblioteca de sets',
                style: AppTypography.titleMedium(palette),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
              child: Text(
                entries.isEmpty
                    ? 'Aún está vacía. Guarda un set o un esquema desde su '
                          'menú y podrás usarlo en cualquier proyecto.'
                    : 'Se usan al crear un set o un esquema de luz nuevo.',
                style: AppTypography.caption(palette),
              ),
            ),
            for (final entry in entries)
              ListTile(
                leading: Icon(
                  entry.isSet
                      ? Icons.meeting_room_outlined
                      : Icons.lightbulb_outline,
                  color: palette.accent,
                ),
                title: Text(
                  entry.name,
                  style: AppTypography.bodyLarge(palette),
                ),
                subtitle: Text(
                  planLibrarySummary(entry),
                  style: AppTypography.caption(palette),
                ),
                trailing: PopupMenuButton<String>(
                  tooltip: 'Opciones',
                  onSelected: (action) =>
                      action == 'rename' ? _rename(entry) : _remove(entry),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'rename', child: Text('Renombrar')),
                    PopupMenuItem(value: 'remove', child: Text('Quitar…')),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
