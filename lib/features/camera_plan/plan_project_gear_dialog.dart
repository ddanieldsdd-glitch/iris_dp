import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../equipment/lens_set_utils.dart';
import 'plan_equipment.dart';

/// Cámaras y juegos de lentes que van al rodaje. Es el mismo equipo del
/// proyecto que se ve en Equipo: lo que se cambia aquí, cambia allí.
class PlanProjectGearDialog extends ConsumerStatefulWidget {
  final int projectId;

  const PlanProjectGearDialog({super.key, required this.projectId});

  static Future<void> show(BuildContext context, int projectId) =>
      showDialog<void>(
        context: context,
        builder: (_) => PlanProjectGearDialog(projectId: projectId),
      );

  @override
  ConsumerState<PlanProjectGearDialog> createState() =>
      _PlanProjectGearDialogState();
}

class _PlanProjectGearDialogState extends ConsumerState<PlanProjectGearDialog> {
  List<Camera> _allCameras = const [];
  List<Lense> _allLenses = const [];
  ProjectGear _gear = const ProjectGear();
  bool _loading = true;
  String _query = '';
  final _openSets = <String>{};

  @override
  void initState() {
    super.initState();
    _load(catalog: true);
  }

  Future<void> _load({bool catalog = false}) async {
    final db = ref.read(databaseProvider);
    if (catalog) {
      _allCameras = await db.getAllCameras();
      _allLenses = await db.getAllLenses();
    }
    final gear = await ProjectGear.load(db, widget.projectId);
    if (!mounted) return;
    setState(() {
      _gear = gear;
      _loading = false;
    });
  }

  Future<void> _change(Future<void> Function(AppDatabase db) action) async {
    await action(ref.read(databaseProvider));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Dialog(
      backgroundColor: palette.surfaceElevated,
      child: SizedBox(
        width: 620,
        height: 640,
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.sm,
                  0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Cámaras y lentes del proyecto',
                        style: AppTypography.titleMedium(palette),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              TabBar(
                tabs: [
                  Tab(text: 'Cámaras (${_gear.cameras.length})'),
                  Tab(text: 'Lentes (${_gear.lenses.length})'),
                ],
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                        children: [_cameras(palette), _lenses(palette)],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cameras(AppPalette palette) {
    final inProject = {for (final c in _gear.cameras) c.id};
    final q = _query.trim().toLowerCase();
    final others = [
      for (final c in _allCameras)
        if (!inProject.contains(c.id) &&
            (q.isEmpty || '${c.brand} ${c.model}'.toLowerCase().contains(q)))
          c,
    ];
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          'La primera es la cámara A; las demás, B, C… Una cámara de la '
          'planta con esa letra coge su sensor y su ISO.',
          style: AppTypography.caption(palette),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_gear.cameras.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Text(
              'Todavía no hay cámaras en el proyecto.',
              style: AppTypography.bodyMedium(palette),
            ),
          ),
        for (final (i, camera) in _gear.cameras.indexed)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: palette.accent.withValues(alpha: 0.2),
              child: Text(
                ProjectGear.letterAt(i),
                style: AppTypography.label(palette),
              ),
            ),
            title: Text('${camera.brand} ${camera.model}'),
            subtitle: Text(
              'Sensor de ${camera.sensorWidthMm.toStringAsFixed(1)} mm'
              '${camera.nativeIso != null ? ' · ISO ${camera.nativeIso}' : ''}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (i > 0)
                  TextButton(
                    onPressed: () => _change(
                      (db) => ProjectGearEdits.makePrimaryCamera(
                        db,
                        widget.projectId,
                        camera,
                      ),
                    ),
                    child: const Text('Hacer A'),
                  ),
                IconButton(
                  tooltip: 'Quitar del proyecto',
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  onPressed: () => _change(
                    (db) => ProjectGearEdits.set(
                      db,
                      widget.projectId,
                      'camera',
                      [camera.id],
                      inProject: false,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const Divider(),
        TextField(
          decoration: const InputDecoration(
            isDense: true,
            prefixIcon: Icon(Icons.search, size: 18),
            hintText: 'Añadir una cámara del catálogo…',
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        for (final camera in others.take(q.isEmpty ? 8 : 40))
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text('${camera.brand} ${camera.model}'),
            trailing: IconButton(
              tooltip: 'Añadir al proyecto',
              icon: const Icon(Icons.add_circle_outline, size: 20),
              onPressed: () => _change(
                (db) => ProjectGearEdits.set(db, widget.projectId, 'camera', [
                  camera.id,
                ], inProject: true),
              ),
            ),
          ),
      ],
    );
  }

  Widget _lenses(AppPalette palette) {
    final inProject = {for (final l in _gear.lenses) l.id};
    final q = _query.trim().toLowerCase();
    final sets = LensSetUtils.groupBySet(_allLenses).entries.where((e) {
      if (q.isEmpty) return true;
      final first = e.value.first;
      return '${first.brand} ${LensSetUtils.setName(first)}'
          .toLowerCase()
          .contains(q);
    }).toList();
    int taken(List<Lense> lenses) =>
        lenses.where((l) => inProject.contains(l.id)).length;
    // Primero los juegos que ya van al rodaje.
    sets.sort((a, b) {
      final byUse = (taken(b.value) > 0 ? 1 : 0) - (taken(a.value) > 0 ? 1 : 0);
      return byUse != 0 ? byUse : a.key.compareTo(b.key);
    });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            0,
          ),
          child: TextField(
            decoration: const InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.search, size: 18),
              hintText: 'Buscar un juego de lentes…',
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            0,
          ),
          child: Text(
            'Marca un juego para llevarlo entero; ábrelo para dejar fuera '
            'las focales que no van.',
            style: AppTypography.caption(palette),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: sets.length,
            itemBuilder: (context, index) {
              final entry = sets[index];
              final lenses = entry.value;
              final count = taken(lenses);
              final open =
                  _openSets.contains(entry.key) ||
                  (count > 0 && count < lenses.length);
              final first = lenses.first;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Checkbox(
                        tristate: true,
                        value: count == 0
                            ? false
                            : count == lenses.length
                            ? true
                            : null,
                        onChanged: (_) => _change(
                          (db) => ProjectGearEdits.set(
                            db,
                            widget.projectId,
                            'lens',
                            [for (final l in lenses) l.id],
                            // Con alguna fuera, se completa; con todas,
                            // se quita el juego.
                            inProject: count < lenses.length,
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() {
                            if (!_openSets.remove(entry.key)) {
                              _openSets.add(entry.key);
                            }
                          }),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${first.brand} '
                                  '${LensSetUtils.setName(first)}',
                                  style: AppTypography.bodyMedium(
                                    palette,
                                  ).copyWith(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  count == 0
                                      ? LensSetUtils.setSummary(lenses)
                                      : '$count de ${lenses.length} en el '
                                            'proyecto',
                                  style: AppTypography.caption(palette),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Icon(
                        open ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                        color: palette.textSecondary,
                      ),
                    ],
                  ),
                  if (open)
                    Padding(
                      padding: const EdgeInsets.only(left: 48, bottom: 8),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final lens in lenses)
                            FilterChip(
                              visualDensity: VisualDensity.compact,
                              label: Text(LensSetUtils.focalLabel(lens)),
                              selected: inProject.contains(lens.id),
                              onSelected: (on) => _change(
                                (db) => ProjectGearEdits.set(
                                  db,
                                  widget.projectId,
                                  'lens',
                                  [lens.id],
                                  inProject: on,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
