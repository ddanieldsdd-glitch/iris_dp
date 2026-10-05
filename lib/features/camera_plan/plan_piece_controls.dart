import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'camera_plan_constants.dart';
import 'camera_plan_element_model.dart';
import 'light/light_scene.dart';
import 'light/modifiers.dart';
import 'light/plan_light.dart';
import 'light/surfaces.dart';
import 'plan_opening.dart';
import 'plan_segment.dart';

/// Propiedades de lo que no es un aparato: puertas, ventanas, paredes,
/// grip, personas y cámaras. Lo que aquí se cambia afecta a cómo se
/// comporta la luz.
class PlanPieceControls extends StatelessWidget {
  final PlanElement element;
  final double metersPerUnit;

  /// Repinta sin guardar (mientras se arrastra un control).
  final VoidCallback onPreview;

  /// Guarda el cambio.
  final VoidCallback onUpdate;

  const PlanPieceControls({
    super.key,
    required this.element,
    required this.metersPerUnit,
    required this.onPreview,
    required this.onUpdate,
  });

  static bool _isTerrain(PlanElement el) =>
      el.type == ElementType.prop &&
      (el.propType == PropType.tree ||
          el.propType == PropType.rock ||
          el.propType == PropType.hill ||
          el.propType == PropType.vehicle);

  static bool appliesTo(PlanElement el) =>
      PlanOpening.isOpening(el) ||
      PlanSegment.isSegment(el) ||
      _isTerrain(el) ||
      _isGrip(el) ||
      el.type == ElementType.actor ||
      el.type == ElementType.camera;

  static bool _isGrip(PlanElement el) => switch (el.lightType) {
    LightType.flag ||
    LightType.cutter ||
    LightType.bounce ||
    LightType.diffusionFrame ||
    LightType.net ||
    LightType.gel => el.type == ElementType.light,
    _ => false,
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final el = element;

    Widget slider(
      String label,
      String value, {
      required double current,
      required double min,
      required double max,
      required ValueChanged<double> onChanged,
    }) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: AppTypography.caption(palette))),
            Text(value, style: AppTypography.caption(palette)),
          ],
        ),
        Slider(
          value: current.clamp(min, max),
          min: min,
          max: max,
          onChanged: (v) {
            onChanged(v);
            onPreview();
          },
          onChangeEnd: (_) => onUpdate(),
        ),
      ],
    );

    Widget toggle(String label, bool value, ValueChanged<bool> onChanged) =>
        Row(
          children: [
            Expanded(child: Text(label, style: AppTypography.caption(palette))),
            Switch(
              value: value,
              onChanged: (v) {
                onChanged(v);
                onUpdate();
              },
            ),
          ],
        );

    Widget choice<T>(
      String label,
      T? value,
      List<(T?, String)> options,
      ValueChanged<T?> onChanged,
    ) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.caption(palette)),
          DropdownButtonFormField<T?>(
            isExpanded: true,
            initialValue: value,
            decoration: const InputDecoration(isDense: true),
            items: [
              for (final (v, name) in options)
                DropdownMenuItem<T?>(
                  value: v,
                  child: Text(name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) {
              onChanged(v);
              onUpdate();
            },
          ),
        ],
      ),
    );

    /// Una sola tela, red o gelatina en la pieza.
    Widget filter(String label, ModifierKind kind, {bool allowNone = true}) {
      final ids = [
        for (final id in (el.props[PlanLight.modifiersKey] as List? ?? []))
          id.toString(),
      ];
      final current = ids
          .map(LightModifier.byId)
          .where((m) => m?.kind == kind)
          .firstOrNull;
      return choice<String>(
        label,
        current?.id,
        [
          if (allowNone) (null, 'Ninguna'),
          for (final m in LightModifier.ofKind(kind))
            (m.id, '${m.name} · ${m.stopsLost.toStringAsFixed(1)} stops'),
        ],
        (id) {
          final rest = ids
              .where((i) => LightModifier.byId(i)?.kind != kind)
              .toList();
          final next = [...rest, ?id];
          if (next.isEmpty) {
            el.props.remove(PlanLight.modifiersKey);
          } else {
            el.props[PlanLight.modifiersKey] = next;
          }
        },
      );
    }

    String meters(double units) =>
        '${(units * metersPerUnit).toStringAsFixed(2)} m';

    final children = <Widget>[];

    if (PlanOpening.isOpening(el)) {
      final width = PlanOpening.width(el);
      children.add(
        slider(
          'Ancho',
          meters(width),
          current: width,
          min: 0.5 / metersPerUnit,
          max: 4 / metersPerUnit,
          onChanged: (v) => el.props[PlanOpening.widthKey] = v,
        ),
      );
      if (PlanOpening.hasLeaves(el)) {
        final open = PlanOpening.openDeg(el);
        final window = PlanOpening.isWindow(el);
        children.addAll([
          slider(
            'Apertura',
            open < 3 ? 'cerrada' : '${open.round()}°',
            current: open,
            min: 0,
            max: PlanOpening.maxOpen,
            onChanged: (v) => el.props[PlanOpening.openKey] = v.roundToDouble(),
          ),
          toggle(
            'Dos hojas',
            PlanOpening.isDouble(el),
            (v) => el.props[PlanOpening.doubleKey] = v,
          ),
          if (!PlanOpening.isDouble(el))
            toggle(
              'Bisagra al otro lado',
              PlanOpening.hingeFar(el),
              (v) => el.props[PlanOpening.hingeFarKey] = v,
            ),
          toggle(
            'Abre hacia el otro lado',
            PlanOpening.swingIn(el),
            (v) => el.props[PlanOpening.swingInKey] = v,
          ),
          Text(
            window
                ? open < 3
                      ? 'Cerrada: la luz pasa por el cristal y pierde un poco.'
                      : 'Abierta: la luz pasa sin cristal y las hojas hacen '
                            'sombra.'
                : open < 3
                ? 'Cerrada: no deja pasar la luz.'
                : 'Abierta: la luz pasa por el hueco y la hoja hace sombra.',
            style: AppTypography.caption(
              palette,
            ).copyWith(color: palette.textTertiary),
          ),
          const SizedBox(height: AppSpacing.sm),
        ]);
      }
      if (PlanOpening.isWindow(el)) {
        final covered = PlanOpening.curtain(el);
        children.addAll([
          slider(
            'Cortina',
            covered < 0.01
                ? 'sin cortina'
                : covered > 0.99
                ? 'echada'
                : '${(covered * 100).round()} % del ancho',
            current: covered,
            min: 0,
            max: 1,
            onChanged: (v) {
              // Cerca de los extremos, se queda en ellos.
              final snapped = v < 0.04
                  ? 0.0
                  : v > 0.96
                  ? 1.0
                  : v;
              if (snapped == 0) {
                el.props.remove(PlanOpening.curtainKey);
              } else {
                el.props[PlanOpening.curtainKey] = snapped;
              }
            },
          ),
          if (covered > 0.01)
            choice<String>(
              'Tela de la cortina',
              PlanOpening.curtainMaterial(el).id,
              [
                for (final c in kCurtains)
                  (
                    c.id,
                    c.transmission <= 0
                        ? '${c.name} · no pasa luz'
                        : '${c.name} · pasa el '
                              '${(c.transmission * 100).round()} %',
                  ),
              ],
              (id) => el.props[PlanOpening.curtainMaterialKey] = id,
            ),
          filter('Difusión pegada al cristal', ModifierKind.diffusion),
          filter('Gelatina en el cristal', ModifierKind.correction),
          Text(
            'Con difusión o cortina, el sol deja de entrar en mancha y la '
            'ventana pasa a ser una fuente blanda.',
            style: AppTypography.caption(
              palette,
            ).copyWith(color: palette.textTertiary),
          ),
          const SizedBox(height: AppSpacing.sm),
        ]);
      }
      // Entre qué alturas está el hueco: decide hasta dónde entra el sol.
      final sill = PlanOpening.sill(el);
      final head = PlanOpening.head(el);
      children.addAll([
        if (!PlanOpening.isDoor(el))
          slider(
            'Alféizar (altura a la que empieza)',
            '${sill.toStringAsFixed(2)} m',
            current: sill,
            min: 0,
            max: 2,
            onChanged: (v) =>
                el.props[PlanOpening.sillKey] = (v * 20).round() / 20,
          ),
        slider(
          'Dintel (altura a la que acaba)',
          '${head.toStringAsFixed(2)} m',
          current: head,
          min: 1,
          max: 6,
          onChanged: (v) =>
              el.props[PlanOpening.headKey] = (v * 20).round() / 20,
        ),
      ]);
    } else if (PlanSegment.isSegment(el) &&
        PlanSegment.kind(el) == PlanSegment.kindWall) {
      final material = SurfaceMaterial.byId(
        el.props[LightScene.materialKey] as String?,
        kWallMaterials,
      );
      children.addAll([
        choice<String>(
          'Material de la pared',
          material.id,
          [for (final m in kWallMaterials) (m.id, m.name)],
          (id) => el.props[LightScene.materialKey] = id,
        ),
        Text(
          'Devuelve el ${(material.reflectance * 100).round()} % de la luz'
          '${material.miredShift > 15
              ? ', más cálida'
              : material.miredShift < -3
              ? ', algo más fría'
              : ''}.',
          style: AppTypography.caption(
            palette,
          ).copyWith(color: palette.textTertiary),
        ),
      ]);
    } else if (PlanSegment.isSegment(el) &&
        PlanSegment.kind(el) == PlanSegment.kindRelief) {
      final height = LightScene.propHeightM(el);
      children.addAll([
        slider(
          'Altura del talud',
          '${height.toStringAsFixed(1)} m',
          current: height,
          min: 0.5,
          max: 30,
          onChanged: (v) =>
              el.props[LightScene.heightKey] = (v * 2).round() / 2,
        ),
        toggle(
          'Baja hacia el otro lado',
          el.props['flip'] == true,
          (v) => el.props['flip'] = v,
        ),
        Text(
          height < 1.2
              ? 'Tan bajo no tapa la luz de los aparatos; al sol le da '
                    'sombra corta.'
              : 'Tapa la luz y da sombra de sol según su altura.',
          style: AppTypography.caption(
            palette,
          ).copyWith(color: palette.textTertiary),
        ),
      ]);
    } else if (_isTerrain(el)) {
      final size = LightScene.propSizeM(el);
      final height = LightScene.propHeightM(el);
      final type = el.propType;
      children.addAll([
        if (type != PropType.vehicle)
          slider(
            type == PropType.tree ? 'Radio de la copa' : 'Radio',
            '${size.toStringAsFixed(1)} m',
            current: size,
            min: 0.2,
            max: type == PropType.hill ? 40 : 8,
            onChanged: (v) =>
                el.props[LightScene.sizeKey] = (v * 10).round() / 10,
          ),
        slider(
          'Altura',
          '${height.toStringAsFixed(1)} m',
          current: height,
          min: 0.2,
          max: type == PropType.hill ? 60 : 25,
          onChanged: (v) =>
              el.props[LightScene.heightKey] = (v * 10).round() / 10,
        ),
        Text(
          type == PropType.tree
              ? 'La copa deja pasar una cuarta parte de la luz y da sombra '
                    'de sol según su altura.'
              : height < 1.2
              ? 'Tan bajo no tapa la luz de los aparatos.'
              : 'Tapa la luz y da sombra de sol según su altura.',
          style: AppTypography.caption(
            palette,
          ).copyWith(color: palette.textTertiary),
        ),
      ]);
    } else if (_isGrip(el)) {
      final length = LightScene.lengthOf(el);
      children.add(
        slider(
          'Largo',
          meters(length),
          current: length,
          min: 0.3 / metersPerUnit,
          max: 6 / metersPerUnit,
          onChanged: (v) => el.props[LightScene.lenKey] = v,
        ),
      );
      switch (el.lightType) {
        case LightType.bounce:
          final material = SurfaceMaterial.byId(
            el.props[LightScene.materialKey] as String?,
            kBounceMaterials,
          );
          children.add(
            choice<String>('Material', material.id, [
              for (final m in kBounceMaterials) (m.id, m.name),
            ], (id) => el.props[LightScene.materialKey] = id),
          );
        case LightType.diffusionFrame:
          children.add(
            filter('Tela', ModifierKind.diffusion, allowNone: false),
          );
        case LightType.net:
          children.add(filter('Red', ModifierKind.scrim, allowNone: false));
        case LightType.gel:
          children.add(
            filter('Gelatina', ModifierKind.correction, allowNone: false),
          );
        default:
          children.add(
            Text(
              'Corta la luz que tiene detrás.',
              style: AppTypography.caption(
                palette,
              ).copyWith(color: palette.textTertiary),
            ),
          );
      }
    } else if (el.type == ElementType.actor || el.type == ElementType.camera) {
      children.add(
        toggle('Hace sombra', el.props[LightScene.noShadowKey] != true, (v) {
          if (v) {
            el.props.remove(LightScene.noShadowKey);
          } else {
            el.props[LightScene.noShadowKey] = true;
          }
        }),
      );
    }

    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
