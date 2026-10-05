import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'camera_plan_constants.dart';
import 'light_family.dart';
import 'light_symbols.dart';

/// Herramienta activa del lienzo.
enum PlanTool {
  /// Seleccionar, mover y girar.
  select,
  wall,
  street,
  relief,
  measure,
}

extension PlanToolInfo on PlanTool {
  String get label => switch (this) {
    PlanTool.select => 'Mover',
    PlanTool.wall => 'Pared',
    PlanTool.street => 'Calle',
    PlanTool.relief => 'Relieve',
    PlanTool.measure => 'Medir',
  };

  IconData get icon => switch (this) {
    PlanTool.select => Icons.near_me_outlined,
    PlanTool.wall => Icons.horizontal_rule,
    PlanTool.street => Icons.add_road,
    PlanTool.relief => Icons.terrain_outlined,
    PlanTool.measure => Icons.straighten,
  };

  /// Las herramientas que dibujan un tramo punto a punto.
  bool get drawsSegment =>
      this == PlanTool.wall ||
      this == PlanTool.street ||
      this == PlanTool.relief;
}

/// Paleta fija de la planta: lo que se puede añadir, siempre a la vista.
/// Tocar un elemento lo coloca en el centro de lo que se está viendo.
class PlanPalette extends StatelessWidget {
  final PlanTool tool;
  final ValueChanged<PlanTool> onTool;
  final VoidCallback onAddCamera;
  final VoidCallback onAddActor;
  final ValueChanged<LightType> onAddLight;
  final ValueChanged<PropType> onAddProp;
  final VoidCallback onAddMeter;

  /// Luces del proyecto, de la pantalla Equipo.
  final List<Light> projectLights;
  final ValueChanged<Light>? onAddCatalogLight;

  /// Todo el catálogo de Equipo.
  final List<Light> catalogLights;
  final ValueChanged<ArchitectureType> onAddArchitecture;

  /// Dónde van paredes y props. `null` si no hay elección.
  final bool? wallsToEnvironment;
  final ValueChanged<bool>? onWallsToEnvironment;

  const PlanPalette({
    super.key,
    required this.tool,
    required this.onTool,
    required this.onAddCamera,
    required this.onAddActor,
    required this.onAddLight,
    required this.onAddProp,
    required this.onAddMeter,
    this.projectLights = const [],
    this.onAddCatalogLight,
    this.catalogLights = const [],
    required this.onAddArchitecture,
    this.wallsToEnvironment,
    this.onWallsToEnvironment,
  });

  static const double width = 196;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(4, AppSpacing.md, 4, 6),
      child: Text(
        text,
        style: AppTypography.caption(palette).copyWith(
          color: palette.accent,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    Widget grid(List<Widget> children) => GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      childAspectRatio: 2.3,
      children: children,
    );

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(right: BorderSide(color: palette.border)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, AppSpacing.lg),
        children: [
          header('HERRAMIENTAS'),
          grid([
            for (final t in PlanTool.values)
              _PaletteButton(
                icon: Icon(t.icon, size: 16),
                label: t.label,
                selected: t == tool,
                tooltip: t.label,
                onTap: () => onTool(t),
              ),
          ]),
          header('SUJETOS'),
          grid([
            _PaletteButton(
              icon: const Icon(Icons.person_outline, size: 16),
              label: 'Actor',
              onTap: onAddActor,
            ),
            _PaletteButton(
              icon: const Icon(Icons.videocam_outlined, size: 16),
              label: 'Cámara',
              onTap: onAddCamera,
            ),
          ]),
          header('MEDICIÓN'),
          grid([
            _PaletteButton(
              icon: const Icon(Icons.speed_outlined, size: 16),
              label: 'Fotómetro',
              onTap: onAddMeter,
            ),
          ]),
          header('LUCES'),
          PlanLightBrowser(
            projectLights: projectLights,
            catalogLights: catalogLights,
            onAddLight: onAddLight,
            onAddCatalogLight: onAddCatalogLight,
          ),
          for (final (title, types) in const [
            ('GRIP · CORTA', [LightType.flag, LightType.cutter]),
            (
              'GRIP · DIFUNDE Y FILTRA',
              [LightType.diffusionFrame, LightType.net, LightType.gel],
            ),
            ('GRIP · REBOTA', [LightType.bounce]),
            ('SOPORTE Y CORRIENTE', [LightType.cStand, LightType.generator]),
          ]) ...[
            header(title),
            grid([
              for (final type in types)
                _PaletteButton(
                  icon: LightSymbolPreview(type: type, size: 20),
                  label: type.label,
                  onTap: () => onAddLight(type),
                ),
            ]),
          ],
          header('SALA'),
          if (wallsToEnvironment != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: const [
                  ButtonSegment(value: false, label: Text('Al set')),
                  ButtonSegment(value: true, label: Text('Al entorno')),
                ],
                selected: {wallsToEnvironment!},
                onSelectionChanged: (v) => onWallsToEnvironment?.call(v.first),
              ),
            ),
          grid([
            for (final type in ArchitectureType.values)
              _PaletteButton(
                icon: Icon(type.icon, size: 16),
                label: type.label,
                onTap: () => onAddArchitecture(type),
              ),
            for (final type in PropType.values)
              if (type != PropType.meter)
                _PaletteButton(
                  icon: Icon(type.icon, size: 16),
                  label: type.label,
                  onTap: () => onAddProp(type),
                ),
          ]),
        ],
      ),
    );
  }
}

class _PaletteButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final String? tooltip;

  const _PaletteButton({
    this.selected = false,
    this.tooltip,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Tooltip(
      message: tooltip ?? 'Añadir $label',
      waitDuration: const Duration(milliseconds: 600),
      child: Material(
        color: selected
            ? palette.accent.withValues(alpha: 0.28)
            : palette.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                IconTheme(
                  data: IconThemeData(color: palette.textSecondary),
                  child: icon,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: AppTypography.caption(
                      palette,
                    ).copyWith(color: palette.textPrimary, fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Las luces de la paleta, por familias: LED, HMI, tungsteno… Dentro de
/// cada una, sus tipos; y en cada tipo, primero las del proyecto, luego
/// la genérica y, al desplegar, las del catálogo de Equipo.
class PlanLightBrowser extends StatefulWidget {
  final List<Light> projectLights;
  final List<Light> catalogLights;
  final ValueChanged<LightType> onAddLight;
  final ValueChanged<Light>? onAddCatalogLight;

  const PlanLightBrowser({
    super.key,
    required this.projectLights,
    required this.catalogLights,
    required this.onAddLight,
    this.onAddCatalogLight,
  });

  @override
  State<PlanLightBrowser> createState() => _PlanLightBrowserState();
}

class _PlanLightBrowserState extends State<PlanLightBrowser> {
  final _openFamilies = <LightFamily>{};
  final _openGroups = <String>{};
  String _query = '';

  static String _nameOf(Light l) => '${l.brand} ${l.model}';

  /// El catálogo trae aparatos repetidos: uno por nombre.
  List<Light> _unique(Iterable<Light> lights) {
    final seen = <String>{};
    return [
      for (final l in lights)
        if (seen.add(_nameOf(l).toLowerCase())) l,
    ]..sort((a, b) => _nameOf(a).compareTo(_nameOf(b)));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final projectIds = {for (final l in widget.projectLights) l.id};
    final project = _unique(widget.projectLights);
    final catalog = _unique(
      widget.catalogLights.where((l) => !projectIds.contains(l.id)),
    );
    final q = _query.trim().toLowerCase();

    Widget fixture(Light light, {required bool inProject}) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: SizedBox(
        height: 34,
        child: _PaletteButton(
          icon: Icon(
            inProject ? Icons.star_rounded : Icons.wb_incandescent_outlined,
            size: 15,
            color: inProject ? palette.accent : null,
          ),
          label: _nameOf(light),
          tooltip:
              '${_nameOf(light)} · ${light.powerW} W'
              '${inProject ? ' · en el proyecto' : ''}',
          onTap: () => widget.onAddCatalogLight?.call(light),
        ),
      ),
    );

    Widget generic(LightType type, String name) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: SizedBox(
        height: 34,
        child: _PaletteButton(
          icon: LightSymbolPreview(type: type, size: 18),
          label: name,
          tooltip: 'Añadir $name (genérica)',
          onTap: () => widget.onAddLight(type),
        ),
      ),
    );

    final search = Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: TextField(
        style: AppTypography.caption(
          palette,
        ).copyWith(color: palette.textPrimary),
        decoration: const InputDecoration(
          isDense: true,
          prefixIcon: Icon(Icons.search, size: 16),
          prefixIconConstraints: BoxConstraints(minWidth: 28),
          hintText: 'Buscar luz…',
        ),
        onChanged: (v) => setState(() => _query = v),
      ),
    );

    if (q.isNotEmpty) {
      final found = [
        ...project.where((l) => _nameOf(l).toLowerCase().contains(q)),
        ...catalog.where((l) => _nameOf(l).toLowerCase().contains(q)),
      ];
      final generics = [
        for (final group in kLightGroups)
          for (final (type, name) in group.generics)
            if (name.toLowerCase().contains(q)) (type, name),
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          search,
          for (final (type, name) in generics) generic(type, name),
          for (final light in found.take(40))
            fixture(light, inProject: projectIds.contains(light.id)),
          if (found.isEmpty && generics.isEmpty)
            Text(
              'Nada con ese nombre.',
              style: AppTypography.caption(
                palette,
              ).copyWith(color: palette.textTertiary),
            ),
        ],
      );
    }

    Widget row({
      required String label,
      required int count,
      required bool open,
      required VoidCallback onTap,
      bool sub = false,
    }) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: EdgeInsets.fromLTRB(sub ? 10 : 2, 6, 2, 6),
        child: Row(
          children: [
            Icon(
              open ? Icons.expand_more : Icons.chevron_right,
              size: 16,
              color: palette.textSecondary,
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Text(
                label,
                style: AppTypography.caption(palette).copyWith(
                  color: sub ? palette.textSecondary : palette.textPrimary,
                  fontWeight: sub ? FontWeight.w500 : FontWeight.w700,
                  fontSize: sub ? 11 : 12,
                ),
              ),
            ),
            if (count > 0)
              Text(
                '$count',
                style: AppTypography.caption(
                  palette,
                ).copyWith(color: palette.textTertiary, fontSize: 10),
              ),
          ],
        ),
      ),
    );

    final children = <Widget>[search];
    for (final family in LightFamily.values) {
      final groups = kLightGroups.where((g) => g.family == family).toList();
      bool inFamily(Light l) =>
          lightGroupForCatalogType(l.lightType).family == family;
      final familyOpen = _openFamilies.contains(family);
      children.add(
        row(
          label: family.label,
          count:
              project.where(inFamily).length + catalog.where(inFamily).length,
          open: familyOpen,
          onTap: () => setState(() {
            if (!_openFamilies.remove(family)) _openFamilies.add(family);
          }),
        ),
      );
      if (!familyOpen) continue;
      for (final group in groups) {
        bool inGroup(Light l) =>
            lightGroupForCatalogType(l.lightType).id == group.id;
        final mine = project.where(inGroup).toList();
        final others = catalog.where(inGroup).toList();
        final groupOpen = _openGroups.contains(group.id);
        // Con un solo tipo en la familia, sobra el segundo nivel.
        if (groups.length > 1) {
          children.add(
            row(
              label: group.name,
              count: mine.length + others.length,
              open: groupOpen,
              sub: true,
              onTap: () => setState(() {
                if (!_openGroups.remove(group.id)) _openGroups.add(group.id);
              }),
            ),
          );
        }
        if (groups.length > 1 && !groupOpen) continue;
        children.add(
          Padding(
            padding: EdgeInsets.only(left: groups.length > 1 ? 12 : 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final light in mine) fixture(light, inProject: true),
                for (final (type, name) in group.generics) generic(type, name),
                for (final light in others) fixture(light, inProject: false),
              ],
            ),
          ),
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}
