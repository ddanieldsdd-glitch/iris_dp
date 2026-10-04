import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'camera_plan_constants.dart';
import 'light_beam.dart';
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
    required this.onAddArchitecture,
    this.wallsToEnvironment,
    this.onWallsToEnvironment,
  });

  static const double width = 196;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final lights = kShotDesignerLightGrid.where(LightBeam.emits).toList();
    if (!lights.contains(LightType.hmi)) lights.add(LightType.hmi);
    final grip = kShotDesignerLightGrid
        .where((t) => !LightBeam.emits(t))
        .toList();

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
          header('LUCES'),
          grid([
            for (final type in lights)
              _PaletteButton(
                icon: LightSymbolPreview(type: type, size: 20),
                label: type.label,
                onTap: () => onAddLight(type),
              ),
          ]),
          header('GRIP'),
          grid([
            for (final type in grip)
              _PaletteButton(
                icon: LightSymbolPreview(type: type, size: 20),
                label: type.label,
                onTap: () => onAddLight(type),
              ),
          ]),
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
