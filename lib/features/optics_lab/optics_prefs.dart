import 'dart:ui';

import '../../core/settings/app_prefs.dart';
import 'frame_line_models.dart';

/// Ajustes del laboratorio óptico: cómo se dibujan las líneas de encuadre
/// al abrirlo. El formato de la línea A sigue saliendo del proyecto.
abstract final class OpticsPrefs {
  static const lineWidth = PrefKey<double>('optics.lineWidth', 4);
  static const lineColorA = PrefKey<int>('optics.lineColorA', 0xFFFFD600);
  static const style = PrefKey<String>('optics.style', 'fullBox');
  static const shading = PrefKey<String>('optics.shading', 'none');
  static const centerMark = PrefKey<String>('optics.centerMark', 'none');

  static const all = <PrefKey>[
    lineWidth,
    lineColorA,
    style,
    shading,
    centerMark,
  ];

  static T _enum<T extends Enum>(List<T> values, String name, T fallback) =>
      values.firstWhere((v) => v.name == name, orElse: () => fallback);

  static OpticsPrefValues read(int projectId) {
    final p = AppPrefs.instance;
    return (
      lineWidth: p.get(lineWidth, projectId: projectId),
      lineColorA: p.get(lineColorA, projectId: projectId),
      style: _enum(
        FrameLineStyle.values,
        p.get(style, projectId: projectId),
        FrameLineStyle.fullBox,
      ),
      shading: _enum(
        FrameLineShading.values,
        p.get(shading, projectId: projectId),
        FrameLineShading.none,
      ),
      centerMark: _enum(
        FrameLineCenterMark.values,
        p.get(centerMark, projectId: projectId),
        FrameLineCenterMark.none,
      ),
    );
  }

  /// Aplica a [lines] lo que cambió entre [prev] y [next] (todo si [prev]
  /// es nulo), sin tocar el resto de lo que se haya ajustado a mano.
  static List<FrameLineConfig> apply(
    List<FrameLineConfig> lines,
    OpticsPrefValues next, [
    OpticsPrefValues? prev,
  ]) => [
    for (final line in lines)
      line.copyWith(
        lineWidth: prev?.lineWidth == next.lineWidth ? null : next.lineWidth,
        lineColor: line.id == 'A' && prev?.lineColorA != next.lineColorA
            ? Color(next.lineColorA)
            : null,
        style: prev?.style == next.style ? null : next.style,
        shading: prev?.shading == next.shading ? null : next.shading,
        centerMark: prev?.centerMark == next.centerMark
            ? null
            : next.centerMark,
      ),
  ];
}

typedef OpticsPrefValues = ({
  double lineWidth,
  int lineColorA,
  FrameLineStyle style,
  FrameLineShading shading,
  FrameLineCenterMark centerMark,
});
