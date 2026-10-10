import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/visual_bible/lighting_metrics.dart';
import '../../../camera_plan/light/modifiers.dart';
import '../bible_point_panel.dart';

/// Gelatinas de corrección de color del motor de luz de la planta.
List<CorrectionGel> correctionGels() => [
  for (final m in LightModifier.ofKind(ModifierKind.correction))
    if (m.miredShift != 0)
      CorrectionGel(m.name, m.miredShift, m.transmission),
];

Color _color(int rgb) => Color(0xFF000000 | rgb);

/// La escala de temperatura va en mired: así el tramo cálido, donde un
/// salto de 200 K se nota mucho, ocupa lo que le toca.
double _kelvinToX(int kelvin) {
  const a = 1e6 / LightingMetrics.minKelvin;
  const b = 1e6 / LightingMetrics.maxKelvin;
  return ((a - 1e6 / kelvin) / (a - b)).clamp(0.0, 1.0);
}

int _xToKelvin(double x) {
  const a = 1e6 / LightingMetrics.minKelvin;
  const b = 1e6 / LightingMetrics.maxKelvin;
  final mired = a - x.clamp(0.0, 1.0) * (a - b);
  // De 50 en 50: nadie pide 5.613 K.
  return ((1e6 / mired) / 50).round() * 50;
}

/// Luz: color y contraste. Temperatura y tinte con el color que dan,
/// todas las opciones de ratio clave:relleno dibujadas, y qué hace falta
/// para llegar a ese color desde una fuente.
///
/// Todo es opcional y nace vacío. [reference] es el valor general del
/// proyecto cuando este widget es el de una localización o una idea de
/// luz: se enseña como marca, para comparar.
class LightingMetricsWidget extends StatelessWidget {
  final LightingMetrics value;
  final ValueChanged<LightingMetrics> onChanged;
  final LightingMetrics? reference;

  /// Balance de blancos de la cámara, si se conoce.
  final int? whiteBalance;

  /// En poco ancho, sin la receta de gelatinas ni la esfera grande.
  final bool compact;

  const LightingMetricsWidget({
    super.key,
    required this.value,
    required this.onChanged,
    this.reference,
    this.whiteBalance,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final label = BiblePointPanel.labelStyle(palette);
    final mono = AppTypography.mono(palette);
    final caption = AppTypography.caption(palette);
    final light = _color(value.color ?? 0xFFFFFF);
    final option = value.ratioOption;

    Widget head(String text, String? current, VoidCallback? onClear) => Row(
      children: [
        Expanded(child: Text(text, style: label)),
        if (current != null)
          Text(current, style: mono.copyWith(color: palette.accent)),
        if (onClear != null)
          IconButton(
            icon: Icon(Icons.close, size: 12, color: palette.textTertiary),
            tooltip: 'Quitar',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 22, height: 22),
            onPressed: onClear,
          ),
      ],
    );

    final recipe = value.recipe(correctionGels());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Temperatura ───────────────────────────────────────────────
        head(
          'TEMPERATURA DE COLOR',
          value.kelvin == null ? null : '${value.kelvin} K',
          value.kelvin == null
              ? null
              : () => onChanged(
                  LightingMetrics(
                    tint: value.tint,
                    ratio: value.ratio,
                    sourceKelvin: value.sourceKelvin,
                  ),
                ),
        ),
        const SizedBox(height: 6),
        _ScaleBar(
          semanticLabel: 'Temperatura de color',
          position: value.kelvin == null ? null : _kelvinToX(value.kelvin!),
          referencePosition: reference?.kelvin == null
              ? null
              : _kelvinToX(reference!.kelvin!),
          colors: [
            for (var i = 0; i <= 24; i++)
              _color(LightingMetrics.colorOf(_xToKelvin(i / 24))),
          ],
          onChanged: (x) => onChanged(value.copyWith(kelvin: _xToKelvin(x))),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final mark in kKelvinLandmarks)
              _Chip(
                label: mark.name,
                detail: '${mark.kelvin}',
                dot: _color(LightingMetrics.colorOf(mark.kelvin)),
                selected: value.kelvin == mark.kelvin,
                onTap: () => onChanged(value.copyWith(kelvin: mark.kelvin)),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Tinte ─────────────────────────────────────────────────────
        head(
          'TINTE',
          value.tint == null ? null : value.tintLabel,
          value.tint == null
              ? null
              : () => onChanged(
                  LightingMetrics(
                    kelvin: value.kelvin,
                    ratio: value.ratio,
                    sourceKelvin: value.sourceKelvin,
                  ),
                ),
        ),
        const SizedBox(height: 6),
        _ScaleBar(
          semanticLabel: 'Tinte',
          position: value.tint == null
              ? null
              : (value.tint! + LightingMetrics.maxTint) /
                    (2 * LightingMetrics.maxTint),
          referencePosition: reference?.tint == null
              ? null
              : (reference!.tint! + LightingMetrics.maxTint) /
                    (2 * LightingMetrics.maxTint),
          colors: const [
            Color(0xFFD946C8),
            Color(0xFFE8E8E8),
            Color(0xFF3FCB5E),
          ],
          onChanged: (x) {
            final tint = (x * 2 - 1) * LightingMetrics.maxTint;
            // Cerca del centro se queda en neutro.
            onChanged(value.copyWith(tint: tint.abs() < 1.5 ? 0 : tint));
          },
        ),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Magenta', style: caption),
              Text('Neutro', style: caption),
              Text('Verde', style: caption),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Color resultante ──────────────────────────────────────────
        if (value.kelvin != null)
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: palette.background.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: palette.divider),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: light,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('EL COLOR DE ESTA LUZ', style: label),
                      const SizedBox(height: 2),
                      Text(
                        [
                          '${value.kelvin} K',
                          if (value.tint != null && value.tint!.abs() >= 0.5)
                            value.tintLabel.toLowerCase(),
                        ].join(' · '),
                        style: AppTypography.bodyLarge(palette),
                      ),
                      if (value.lookAgainst(whiteBalance) != null)
                        Text(value.lookAgainst(whiteBalance)!, style: caption),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (value.kelvin != null) const SizedBox(height: AppSpacing.md),

        // ── Contraste ─────────────────────────────────────────────────
        head(
          'CONTRASTE CLAVE : RELLENO',
          option == null ? null : '${option.label} · ${option.stopsLabel}',
          value.ratio == null
              ? null
              : () => onChanged(
                  LightingMetrics(
                    kelvin: value.kelvin,
                    tint: value.tint,
                    sourceKelvin: value.sourceKelvin,
                  ),
                ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!compact && option != null) ...[
              Column(
                children: [
                  SizedBox(
                    width: 132,
                    height: 132,
                    child: CustomPaint(
                      painter: _SpherePainter(ratio: option.ratio, light: light),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(option.use.toUpperCase(), style: label),
                ],
              ),
              const SizedBox(width: AppSpacing.lg),
            ],
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final o in kContrastRatios)
                    _RatioTile(
                      option: o,
                      light: light,
                      selected: option?.ratio == o.ratio,
                      isReference: reference?.ratioOption?.ratio == o.ratio,
                      onTap: () => onChanged(value.copyWith(ratio: o.ratio)),
                    ),
                ],
              ),
            ),
          ],
        ),

        // ── Qué hace falta ────────────────────────────────────────────
        if (!compact && value.kelvin != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Text('QUÉ HACE FALTA PARA LLEGAR A ESE COLOR', style: label),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final source in kLightSources)
                _Chip(
                  label: source.name,
                  detail: '${source.kelvin}',
                  dot: _color(LightingMetrics.colorOf(source.kelvin)),
                  selected: value.sourceKelvin == source.kelvin,
                  onTap: () =>
                      onChanged(value.copyWith(sourceKelvin: source.kelvin)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (recipe == null)
            Text(
              'Elige de qué fuente partes y te digo qué corrección lleva.',
              style: caption,
            )
          else
            _RecipeView(recipe: recipe),
        ],
      ],
    );
  }
}

/// Barra de escala que se toca o se arrastra. Sin valor, no lleva marca.
class _ScaleBar extends StatelessWidget {
  final String semanticLabel;
  final double? position;
  final double? referencePosition;
  final List<Color> colors;
  final ValueChanged<double> onChanged;

  const _ScaleBar({
    required this.semanticLabel,
    required this.position,
    required this.colors,
    required this.onChanged,
    this.referencePosition,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return LayoutBuilder(
      builder: (context, c) {
        final width = c.maxWidth;
        void at(Offset local) => onChanged((local.dx / width).clamp(0.0, 1.0));
        return Semantics(
          label: semanticLabel,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => at(d.localPosition),
            onHorizontalDragUpdate: (d) => at(d.localPosition),
            child: SizedBox(
              height: 26,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    top: 5,
                    bottom: 5,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: LinearGradient(colors: colors),
                      ),
                    ),
                  ),
                  if (referencePosition != null)
                    Positioned(
                      left: referencePosition! * width - 1,
                      top: 2,
                      bottom: 2,
                      child: Tooltip(
                        message: 'Valor general del proyecto',
                        child: Container(
                          width: 2,
                          color: palette.textTertiary,
                        ),
                      ),
                    ),
                  if (position != null)
                    Positioned(
                      left: position! * width - 5,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 10,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String detail;
  final Color dot;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.detail,
    required this.dot,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: selected
              ? palette.accent.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? palette.accent : palette.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: AppTypography.caption(
                palette,
              ).copyWith(color: palette.textPrimary),
            ),
            const SizedBox(width: 4),
            Text(detail, style: AppTypography.caption(palette)),
          ],
        ),
      ),
    );
  }
}

class _RatioTile extends StatelessWidget {
  final ContrastRatioOption option;
  final Color light;
  final bool selected;
  final bool isReference;
  final VoidCallback onTap;

  const _RatioTile({
    required this.option,
    required this.light,
    required this.selected,
    required this.isReference,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Tooltip(
      message:
          '${option.use} · ${option.stopsLabel}'
          '${isReference ? ' · el general del proyecto' : ''}',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: 78,
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
          decoration: BoxDecoration(
            color: selected
                ? palette.accent.withValues(alpha: 0.14)
                : palette.background.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? palette.accent
                  : isReference
                  ? palette.textTertiary
                  : palette.divider,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              SizedBox(
                width: 46,
                height: 46,
                child: CustomPaint(
                  painter: _SpherePainter(ratio: option.ratio, light: light),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                option.label,
                style: AppTypography.mono(palette).copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? palette.accent : palette.textPrimary,
                ),
              ),
              Text(
                option.use,
                style: AppTypography.caption(palette).copyWith(fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Una esfera iluminada desde la izquierda con la clave y, por la derecha,
/// con el relleno que le corresponde a ese ratio.
class _SpherePainter extends CustomPainter {
  final double ratio;
  final Color light;

  const _SpherePainter({required this.ratio, required this.light});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.save();
    canvas.clipPath(Path()..addOval(rect));

    // Lo que el ojo ve no es lineal: 1/8 de luz no es 1/8 de brillo.
    double seen(double linear) =>
        math.pow(linear.clamp(0.0, 1.0), 1 / 2.2).toDouble();
    Color lit(double linear) {
      final v = seen(linear);
      return Color.fromARGB(
        255,
        (light.r * 255 * v).round(),
        (light.g * 255 * v).round(),
        (light.b * 255 * v).round(),
      );
    }

    final fill = 1 / ratio;
    // De la clave al relleno, de izquierda a derecha.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [lit(1), lit(1), lit(fill), lit(fill)],
          stops: const [0, 0.38, 0.62, 1],
        ).createShader(rect),
    );
    // Volumen: el borde se apaga como en una esfera.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
          stops: const [0.55, 1],
        ).createShader(rect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SpherePainter old) =>
      old.ratio != ratio || old.light != light;
}

class _RecipeView extends StatelessWidget {
  final ColorRecipe recipe;
  const _RecipeView({required this.recipe});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final body = AppTypography.bodyMedium(palette);
    final caption = AppTypography.caption(palette);
    final stops = recipe.stopsLost;
    final gels = recipe.gels.map((g) => g.name).join(' + ');
    final lines = <String>[
      if (recipe.gels.isEmpty && recipe.tintGel == null)
        'No hace falta corrección: la fuente ya da ese color.'
      else ...[
        if (recipe.gels.isNotEmpty)
          '$gels → ${recipe.resultKelvin} K'
        else
          'Sin gelatina de temperatura.',
        if (recipe.tintGel != null) recipe.tintGel!,
      ],
    ];
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.background.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _swatch(recipe.sourceKelvin),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.arrow_forward,
                  size: 14,
                  color: palette.textTertiary,
                ),
              ),
              _swatch(recipe.resultKelvin),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [for (final line in lines) Text(line, style: body)],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            [
              'De ${recipe.sourceKelvin} K a ${recipe.targetKelvin} K: '
                  '${recipe.miredShift >= 0 ? '+' : '−'}'
                  '${recipe.miredShift.abs().round()} mired',
              if (stops > 0.05)
                'se pierde ${stops.toStringAsFixed(1).replaceAll('.', ',')} '
                    '${stops.toStringAsFixed(1) == '1.0' ? 'stop' : 'stops'}',
              'valores orientativos de muestrario',
            ].join(' · '),
            style: caption,
          ),
        ],
      ),
    );
  }

  Widget _swatch(int kelvin) => Container(
    width: 30,
    height: 30,
    decoration: BoxDecoration(
      color: _color(LightingMetrics.colorOf(kelvin)),
      borderRadius: BorderRadius.circular(6),
    ),
  );
}
