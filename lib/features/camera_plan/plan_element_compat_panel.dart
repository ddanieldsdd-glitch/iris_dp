import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../camera_plan/camera_plan_constants.dart';
import '../camera_plan/camera_plan_element_model.dart';
import '../camera_plan/plan_element_compat.dart';
import '../luka_export/luka_fixture_picker.dart';
import '../luka_export/luka_light_mapping.dart';

/// Panel de propiedades con vínculos LUKA / Unreal / Cine Tracer.
class PlanElementCompatPanel extends ConsumerWidget {
  final PlanElement element;
  final VoidCallback onChanged;

  const PlanElementCompatPanel({
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
      builder: (context, lightSnap) {
        return StreamBuilder<List<Camera>>(
          stream: db.watchAllCameras(),
          builder: (context, camSnap) {
            return StreamBuilder<List<Lense>>(
              stream: db.watchAllLenses(),
              builder: (context, lensSnap) {
                final catalog = lightSnap.data ?? [];
                final cameras = camSnap.data ?? [];
                final lenses = lensSnap.data ?? [];

                final profile = PlanElementCompat.resolve(
                  element,
                  catalog: catalog,
                  catalogCamera: _findCamera(
                    cameras,
                    element.externalMapping.catalogCameraId,
                  ),
                  catalogLens: _findLens(
                    lenses,
                    element.externalMapping.catalogLensId,
                  ),
                  catalogLight: _findLight(
                    catalog,
                    element.externalMapping.catalogLightId,
                  ),
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CompatBadges(palette: palette, profile: profile),
                    const SizedBox(height: 12),
                    switch (element.type) {
                      ElementType.camera => _CameraSection(
                          palette: palette,
                          element: element,
                          cameras: cameras,
                          lenses: lenses,
                          catalog: catalog,
                          onChanged: onChanged,
                        ),
                      ElementType.light => _LightSection(
                          palette: palette,
                          element: element,
                          catalog: catalog,
                          cameras: cameras,
                          lenses: lenses,
                          onChanged: onChanged,
                        ),
                      ElementType.prop || ElementType.wall => _PropSection(
                          palette: palette,
                          element: element,
                          profile: profile,
                          onChanged: onChanged,
                        ),
                      ElementType.actor => _ActorSection(palette: palette),
                    },
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Camera? _findCamera(List<Camera> list, int? id) {
    if (id == null) return null;
    for (final c in list) {
      if (c.id == id) return c;
    }
    return null;
  }

  Lense? _findLens(List<Lense> list, int? id) {
    if (id == null) return null;
    for (final l in list) {
      if (l.id == id) return l;
    }
    return null;
  }

  Light? _findLight(List<Light> list, int? id) {
    if (id == null) return null;
    for (final l in list) {
      if (l.id == id) return l;
    }
    return null;
  }
}

class _CompatBadges extends StatelessWidget {
  final AppPalette palette;
  final PlanElementCompatProfile profile;

  const _CompatBadges({required this.palette, required this.profile});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _badge('LUKA', profile.luka, const Color(0xFFE8B923)),
        _badge('Unreal', profile.unreal, const Color(0xFF5BC0DE)),
        _badge('Cine Tracer', profile.cinetracer, const Color(0xFFBF5AF2)),
      ],
    );
  }

  Widget _badge(String label, bool active, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.18) : palette.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: active ? color : palette.divider,
        ),
      ),
      child: Text(
        label,
        style: AppTypography.caption(palette).copyWith(
          color: active ? color : palette.textTertiary,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CameraSection extends StatelessWidget {
  final AppPalette palette;
  final PlanElement element;
  final List<Camera> cameras;
  final List<Lense> lenses;
  final List<Light> catalog;
  final VoidCallback onChanged;

  const _CameraSection({
    required this.palette,
    required this.element,
    required this.cameras,
    required this.lenses,
    required this.catalog,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Cámara (catálogo)', style: AppTypography.caption(palette)),
        const SizedBox(height: 4),
        DropdownButtonFormField<int?>(
          value: element.externalMapping.catalogCameraId,
          decoration: const InputDecoration(isDense: true, hintText: 'Opcional'),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('—')),
            for (final c in cameras)
              DropdownMenuItem(
                value: c.id,
                child: Text('${c.brand} ${c.model}', overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (id) {
            element.externalMapping.catalogCameraId = id;
            onChanged();
          },
        ),
        const SizedBox(height: 8),
        Text('Óptica (catálogo)', style: AppTypography.caption(palette)),
        const SizedBox(height: 4),
        DropdownButtonFormField<int?>(
          value: element.externalMapping.catalogLensId,
          decoration: const InputDecoration(isDense: true, hintText: 'Opcional'),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('—')),
            for (final l in lenses)
              DropdownMenuItem(
                value: l.id,
                child: Text(
                  '${l.brand} ${l.model}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (id) {
            element.externalMapping.catalogLensId = id;
            final lens = lenses.where((l) => l.id == id).firstOrNull;
            if (lens != null && lens.focalLength > 0) {
              element.lens = '${lens.focalLength.round()}mm';
            }
            onChanged();
          },
        ),
        const SizedBox(height: 8),
        Text('Movimiento', style: AppTypography.caption(palette)),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: kStabilizationPresets.contains(element.stabilization?.toUpperCase())
              ? element.stabilization!.toUpperCase()
              : 'STEADY',
          decoration: const InputDecoration(isDense: true),
          items: [
            for (final p in kStabilizationPresets)
              DropdownMenuItem(value: p, child: Text(p)),
          ],
          onChanged: (v) {
            element.stabilization = v;
            onChanged();
          },
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () {
            LukaLightMapping.applyDefaults(
              element,
              catalog: catalog,
              cameras: cameras,
              lenses: lenses,
            );
            onChanged();
          },
          child: Text(
            'Auto-vincular catálogo',
            style: AppTypography.caption(palette).copyWith(color: palette.accent),
          ),
        ),
      ],
    );
  }
}

class _LightSection extends StatelessWidget {
  final AppPalette palette;
  final PlanElement element;
  final List<Light> catalog;
  final List<Camera> cameras;
  final List<Lense> lenses;
  final VoidCallback onChanged;

  const _LightSection({
    required this.palette,
    required this.element,
    required this.catalog,
    required this.cameras,
    required this.lenses,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Tipo simbólico', style: AppTypography.caption(palette)),
        const SizedBox(height: 4),
        DropdownButtonFormField<LightType?>(
          value: element.lightType,
          decoration: const InputDecoration(isDense: true),
          items: [
            for (final t in LightType.values)
              DropdownMenuItem(
                value: t,
                child: Text(t.label, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (t) {
            element.lightType = t;
            LukaLightMapping.applyDefaults(
              element,
              catalog: catalog,
              cameras: cameras,
              lenses: lenses,
            );
            onChanged();
          },
        ),
        const SizedBox(height: 8),
        Text('Equipo (catálogo)', style: AppTypography.caption(palette)),
        const SizedBox(height: 4),
        DropdownButtonFormField<int?>(
          value: element.externalMapping.catalogLightId,
          decoration: const InputDecoration(isDense: true, hintText: 'Opcional'),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('—')),
            for (final l in catalog)
              DropdownMenuItem(
                value: l.id,
                child: Text(
                  '${l.brand} ${l.model}${l.isLukaCompatible ? ' · LUKA' : ''}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (id) {
            element.externalMapping.catalogLightId = id;
            final light = catalog.where((l) => l.id == id).firstOrNull;
            if (light != null && light.isLukaCompatible) {
              element.lukaCompatible = true;
              element.lukaFixtureId = light.lukaFixtureId;
            }
            onChanged();
          },
        ),
        const SizedBox(height: 8),
        LukaFixturePicker(element: element, onChanged: onChanged),
      ],
    );
  }
}

class _PropSection extends StatelessWidget {
  final AppPalette palette;
  final PlanElement element;
  final PlanElementCompatProfile profile;
  final VoidCallback onChanged;

  const _PropSection({
    required this.palette,
    required this.element,
    required this.profile,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (element.type == ElementType.prop) ...[
          Text('Tipo de prop', style: AppTypography.caption(palette)),
          const SizedBox(height: 4),
          DropdownButtonFormField<PropType?>(
            value: element.propType,
            decoration: const InputDecoration(isDense: true),
            items: [
              for (final p in PropType.values)
                DropdownMenuItem(value: p, child: Text(p.label)),
            ],
            onChanged: (p) {
              element.label = p?.dbValue;
              PlanElementCompat.applyAutoMapping(element);
              onChanged();
            },
          ),
          const SizedBox(height: 8),
        ],
        if (element.type == ElementType.wall) ...[
          Text('Arquitectura', style: AppTypography.caption(palette)),
          const SizedBox(height: 4),
          DropdownButtonFormField<ArchitectureType?>(
            value: element.architectureType,
            decoration: const InputDecoration(isDense: true),
            items: [
              for (final a in ArchitectureType.values)
                DropdownMenuItem(value: a, child: Text(a.label)),
            ],
            onChanged: (a) {
              element.label = a?.dbValue;
              PlanElementCompat.applyAutoMapping(element);
              onChanged();
            },
          ),
          const SizedBox(height: 8),
        ],
        Text('Mesh Unreal', style: AppTypography.caption(palette)),
        Text(
          profile.unrealMeshPath ?? PlanElementCompat.defaultUnrealMesh,
          style: AppTypography.caption(palette).copyWith(
            color: palette.textSecondary,
            fontSize: 10,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text('Tipo Cine Tracer', style: AppTypography.caption(palette)),
        Text(
          profile.cinetracerType,
          style: AppTypography.caption(palette).copyWith(
            color: palette.accent,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _ActorSection extends StatelessWidget {
  final AppPalette palette;

  const _ActorSection({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Marcador compatible con MetaHuman / placeholder en Unreal y actor en Cine Tracer.',
      style: AppTypography.caption(palette).copyWith(
        color: palette.textSecondary,
        fontSize: 10,
      ),
    );
  }
}
