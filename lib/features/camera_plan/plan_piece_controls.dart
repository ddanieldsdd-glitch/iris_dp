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

  static bool appliesTo(PlanElement el) =>
      PlanOpening.isOpening(el) ||
      PlanSegment.isSegment(el) ||
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
      if (PlanOpening.isDoor(el)) {
        final open = PlanOpening.openDeg(el);
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
            open < 3
                ? 'Cerrada: no deja pasar la luz.'
                : 'Abierta: la luz pasa por el hueco y la hoja hace sombra.',
            style: AppTypography.caption(
              palette,
            ).copyWith(color: palette.textTertiary),
          ),
        ]);
      } else if (PlanOpening.isWindow(el)) {
        children.addAll([
          filter('Cortina o difusión', ModifierKind.diffusion),
          filter('Gelatina en el cristal', ModifierKind.correction),
        ]);
      }
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
