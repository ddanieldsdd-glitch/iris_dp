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
    if (m.miredShift != 0) CorrectionGel(m.name, m.miredShift, m.transmission),
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
class LightingMetricsWidget extends StatefulWidget {
  final LightingMetrics value;
  final ValueChanged<LightingMetrics> onChanged;
  final LightingMetrics? reference;

  /// Balance de blancos de la cámara, si se conoce.
  final int? whiteBalance;

  /// En poco ancho, sin la receta de gelatinas ni la esfera grande.
  final bool compact;

  /// Una vez configurado, se enseña plegado en una tira y se despliega
  /// para editar.
  final bool collapsible;

  const LightingMetricsWidget({
    super.key,
    required this.value,
    required this.onChanged,
    this.reference,
    this.whiteBalance,
    this.compact = false,
    this.collapsible = true,
  });

  @override
  State<LightingMetricsWidget> createState() => _LightingMetricsWidgetState();
}

class _LightingMetricsWidgetState extends State<LightingMetricsWidget> {
  /// Vacío se abre para configurarlo; configurado, plegado.
  late bool _expanded = !widget.collapsible || widget.value.isEmpty;

  LightingMetrics get value => widget.value;
  ValueChanged<LightingMetrics> get onChanged => widget.onChanged;
  LightingMetrics? get reference => widget.reference;
  int? get whiteBalance => widget.whiteBalance;
  bool get compact => widget.compact;

  @override
  Widget build(BuildContext context) {
    if (!_expanded && !value.isEmpty) {
      return _LightingSummary(
        value: value,
        onEdit: () => setState(() => _expanded = true),
      );
    }
    final full = _full(context);
    if (!widget.collapsible || value.isEmpty) return full;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        full,
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonalIcon(
            onPressed: () => setState(() => _expanded = false),
            icon: const Icon(Icons.unfold_less, size: 18),
            label: const Text('Listo'),
          ),
        ),
      ],
    );
  }

  Widget _full(BuildContext context) {
    final palette = context.palette;
    final label = BiblePointPanel.labelStyle(palette);
    final mono = AppTypography.mono(palette);
    final caption = AppTypography.caption(palette);
    final usesColors = value.usesColors;
    // En modo color, la clave es la primera luz con ese papel.
    final keyColor = usesColors
        ? value.colors
              .where((c) => c.role == LightColorRole.key)
              .followedBy(value.colors)
              .first
        : null;
    final light = _color(keyColor?.rgb ?? value.color ?? 0xFFFFFF);
    final option = value.ratioOption;
    // En HSI, sus colores; en CCT con fuentes, cada fuente con su
    // temperatura desde su lado.
    final sceneColors = usesColors
        ? value.colors
        : (!value.colorMode && value.sources.length > 1)
        ? value.sceneLights
        : const <LightColor>[];

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Luz blanca o color ────────────────────────────────────────
        Row(
          children: [
            _ModeTab(
              label: 'CCT',
              icon: Icons.wb_sunny_outlined,
              selected: !value.colorMode,
              onTap: () => onChanged(value.copyWith(colorMode: false)),
            ),
            const SizedBox(width: 6),
            _ModeTab(
              label: 'HSI',
              icon: Icons.color_lens_outlined,
              selected: value.colorMode,
              onTap: () => onChanged(value.copyWith(colorMode: true)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (value.colorMode) ...[
          _ColorLights(
            colors: value.colors,
            onChanged: (colors) => onChanged(value.copyWith(colors: colors)),
          ),
          const SizedBox(height: AppSpacing.md),
        ] else ...[
          _CctSources(
            sources: value.cctSources,
            whiteBalance: whiteBalance,
            referenceKelvin: reference?.kelvin,
            onChanged: (next) => onChanged(value.withSources(next)),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        // ── Mezcla de la escena ───────────────────────────────────────
        if (value.mix.length > 1) ...[
          Text('MEZCLA DE LA ESCENA', style: label),
          const SizedBox(height: 6),
          _MixBar(mix: value.mix),
          const SizedBox(height: AppSpacing.md),
        ],
        // ── Escenas de partida ────────────────────────────────────────
        Text('EMPEZAR DESDE', style: label),
        const SizedBox(height: 6),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final preset in kLightingPresets)
              ActionChip(
                visualDensity: VisualDensity.compact,
                avatar: Icon(
                  preset.hsi
                      ? Icons.color_lens_outlined
                      : Icons.wb_sunny_outlined,
                  size: 14,
                ),
                label: Text(preset.name),
                onPressed: () => onChanged(preset.applyTo(value)),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Contraste ─────────────────────────────────────────────────
        head(
          'CONTRASTE CLAVE : RELLENO',
          option == null ? null : '${option.label} · ${option.stopsLabel}',
          value.ratio == null
              ? null
              : () => onChanged(value.without(ratio: true)),
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
                      painter: _SpherePainter(
                        ratio: option.ratio,
                        light: light,
                        colors: sceneColors,
                      ),
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
                      colors: sceneColors,
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
        if (!compact && usesColors) ...[
          const SizedBox(height: AppSpacing.lg),
          Text('PARA PROGRAMAR LOS APARATOS', style: label),
          const SizedBox(height: 6),
          for (final c in value.colors)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _color(c.rgb),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${c.role.label}'
                      '${c.name.trim().isEmpty ? '' : ' · ${c.name.trim()}'}',
                      style: AppTypography.bodyMedium(palette),
                    ),
                  ),
                  Text('${c.hsiLabel}   ${c.rgbLabel}', style: mono),
                ],
              ),
            ),
          Text(
            'Con LED RGB se programan estos valores. Con gelatina de color '
            'sobre una fuente blanca se pierde mucha luz: conviene probarlo.',
            style: caption,
          ),
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
                        child: Container(width: 2, color: palette.textTertiary),
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
  final List<LightColor> colors;
  final bool selected;
  final bool isReference;
  final VoidCallback onTap;

  const _RatioTile({
    required this.option,
    required this.light,
    this.colors = const [],
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
                  painter: _SpherePainter(
                    ratio: option.ratio,
                    light: light,
                    colors: colors,
                  ),
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

  /// Luces de color de la escena. Vacío: una sola luz, [light].
  final List<LightColor> colors;

  const _SpherePainter({
    required this.ratio,
    required this.light,
    this.colors = const [],
  });

  // Lo que el ojo ve no es lineal: 1/8 de luz no es 1/8 de brillo.
  static double _seen(double linear) =>
      math.pow(linear.clamp(0.0, 1.0), 1 / 2.2).toDouble();

  static Color _lit(Color color, double linear) {
    final v = _seen(linear);
    return Color.fromARGB(
      255,
      (color.r * 255 * v).round(),
      (color.g * 255 * v).round(),
      (color.b * 255 * v).round(),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.save();
    canvas.clipPath(Path()..addOval(rect));
    final fill = 1 / ratio;

    if (colors.isEmpty) {
      // De la clave al relleno, de izquierda a derecha.
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            colors: [
              _lit(light, 1),
              _lit(light, 1),
              _lit(light, fill),
              _lit(light, fill),
            ],
            stops: const [0, 0.38, 0.62, 1],
          ).createShader(rect),
      );
    } else {
      // Cada luz ilumina desde su lado y los colores se suman, como la
      // luz de verdad. El relleno baja lo que diga el ratio.
      canvas.drawRect(rect, Paint()..color = Colors.black);
      for (final c in colors) {
        final color = _color(c.rgb);
        final level = c.intensity;
        final paint = Paint()..blendMode = BlendMode.plus;
        switch (c.role) {
          case LightColorRole.key:
            paint.shader = LinearGradient(
              colors: [_lit(color, level), Colors.black],
              stops: const [0.25, 0.75],
            ).createShader(rect);
          case LightColorRole.fill:
            paint.shader = LinearGradient(
              colors: [Colors.black, _lit(color, level * fill)],
              stops: const [0.25, 0.8],
            ).createShader(rect);
          case LightColorRole.back:
            paint.shader = RadialGradient(
              colors: [Colors.black, Colors.black, _lit(color, level)],
              stops: const [0, 0.72, 1],
            ).createShader(rect);
          case LightColorRole.ambient:
            paint.color = _lit(color, level * 0.18);
          case LightColorRole.practical:
            paint.shader = RadialGradient(
              center: const Alignment(0.45, -0.5),
              radius: 0.45,
              colors: [_lit(color, level), Colors.black],
            ).createShader(rect);
        }
        canvas.drawRect(rect, paint);
      }
    }
    // Volumen: el borde se apaga como en una esfera. El contraluz se
    // queda fuera de este apagado para que se vea el filo.
    if (!colors.any((c) => c.role == LightColorRole.back)) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
            stops: const [0.55, 1],
          ).createShader(rect),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SpherePainter old) =>
      old.ratio != ratio || old.light != light || old.colors != colors;
}

class _ModeTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ModeTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: selected ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? palette.accent.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? palette.accent : palette.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? palette.accent : palette.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.bodyMedium(palette).copyWith(
                color: selected ? palette.textPrimary : palette.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Las luces de color de la escena: se añaden desde los colores de
/// partida y cada una se afina con tono, saturación, intensidad y papel.
class _ColorLights extends StatelessWidget {
  final List<LightColor> colors;
  final ValueChanged<List<LightColor>> onChanged;

  const _ColorLights({required this.colors, required this.onChanged});

  void _set(int index, LightColor next) =>
      onChanged([...colors]..[index] = next);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final label = BiblePointPanel.labelStyle(palette);
    final mono = AppTypography.mono(palette).copyWith(fontSize: 11);
    // El primero es la clave; los siguientes, relleno y contra.
    LightColorRole nextRole() => switch (colors.length) {
      0 => LightColorRole.key,
      1 => LightColorRole.fill,
      2 => LightColorRole.back,
      _ => LightColorRole.ambient,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('COLORES DE LA ESCENA', style: label),
        const SizedBox(height: 6),
        if (colors.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 18,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final c in colors)
                    Expanded(
                      flex: (c.intensity * 100).round().clamp(5, 100),
                      child: ColoredBox(color: _color(c.rgb)),
                    ),
                ],
              ),
            ),
          ),
        for (var i = 0; i < colors.length; i++)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: palette.background.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: palette.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _color(colors[i].rgb),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          for (final role in LightColorRole.values)
                            _RoleChip(
                              label: role.label,
                              selected: colors[i].role == role,
                              onTap: () =>
                                  _set(i, colors[i].copyWith(role: role)),
                            ),
                        ],
                      ),
                    ),
                    // Se puede escribir el color: #RRGGBB.
                    SizedBox(
                      width: 78,
                      child: TextFormField(
                        key: ValueKey('hex_${i}_${colors[i].rgb}'),
                        initialValue: colors[i].hex,
                        style: mono,
                        textAlign: TextAlign.end,
                        decoration: const InputDecoration(
                          isDense: true,
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                        onChanged: (text) {
                          final rgb = LightColor.parseHex(text);
                          if (rgb != null && rgb != colors[i].rgb) {
                            _set(i, colors[i].copyWith(rgb: rgb, name: ''));
                          }
                        },
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 12,
                        color: palette.textTertiary,
                      ),
                      tooltip: 'Quitar color',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => onChanged([...colors]..removeAt(i)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _ScaleBar(
                  semanticLabel: 'Tono ${i + 1}',
                  position: colors[i].hueSaturation.$1 / 360,
                  colors: [
                    for (var h = 0; h <= 12; h++)
                      _color(LightColor.fromHueSaturation(h * 30.0, 1)),
                  ],
                  onChanged: (x) => _set(
                    i,
                    colors[i].copyWith(
                      name: '',
                      rgb: LightColor.fromHueSaturation(
                        x * 360,
                        // Un color sin saturación no tiene tono que mover.
                        math.max(colors[i].hueSaturation.$2, 0.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _ScaleBar(
                        semanticLabel: 'Saturación ${i + 1}',
                        position: colors[i].hueSaturation.$2,
                        colors: [
                          Colors.white,
                          _color(
                            LightColor.fromHueSaturation(
                              colors[i].hueSaturation.$1,
                              1,
                            ),
                          ),
                        ],
                        onChanged: (x) => _set(
                          i,
                          colors[i].copyWith(
                            name: '',
                            rgb: LightColor.fromHueSaturation(
                              colors[i].hueSaturation.$1,
                              x,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ScaleBar(
                        semanticLabel: 'Intensidad ${i + 1}',
                        position: colors[i].intensity,
                        colors: [Colors.black, _color(colors[i].rgb)],
                        onChanged: (x) => _set(
                          i,
                          colors[i].copyWith(intensity: (x * 20).round() / 20),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Tono · saturación · intensidad   ${colors[i].hsiLabel}',
                  style: AppTypography.caption(palette),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final (name, rgb) in kPartyColors)
              _Chip(
                label: name,
                detail: '+',
                dot: _color(rgb),
                selected: false,
                onTap: () => onChanged([
                  ...colors,
                  LightColor(rgb: rgb, name: name, role: nextRole()),
                ]),
              ),
          ],
        ),
        if (colors.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Añade los colores que quieres en la escena: el primero es la '
              'clave, el segundo el relleno, el tercero el contra.',
              style: AppTypography.caption(palette),
            ),
          ),
      ],
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RoleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: selected ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: selected
              ? palette.accent.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? palette.accent : palette.divider,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.caption(palette).copyWith(
            color: selected ? palette.textPrimary : palette.textSecondary,
          ),
        ),
      ),
    );
  }
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

/// El widget plegado: la esfera pequeña, una pastilla por fuente y el
/// contraste. «Editar» lo despliega.
class _LightingSummary extends StatelessWidget {
  final LightingMetrics value;
  final VoidCallback onEdit;

  const _LightingSummary({required this.value, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final mono = AppTypography.mono(palette).copyWith(fontSize: 11);
    final option = value.ratioOption;
    final hsi = value.usesColors;
    final key = hsi
        ? value.colors
              .where((c) => c.role == LightColorRole.key)
              .followedBy(value.colors)
              .firstOrNull
              ?.rgb
        : value.keySource?.rgb;
    final lights = hsi ? value.colors : value.sceneLights;

    Widget pill(Color dot, String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
        color: palette.background.withValues(alpha: 0.35),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(text, style: mono),
        ],
      ),
    );

    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: CustomPaint(
                painter: _SpherePainter(
                  ratio: option?.ratio ?? 2,
                  light: _color(key ?? 0xFFFFFF),
                  colors: lights.length > 1 ? lights : const [],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  pill(palette.accent, hsi ? 'HSI' : 'CCT'),
                  if (hsi)
                    for (final c in value.colors)
                      pill(
                        _color(c.rgb),
                        '${c.role.label} · '
                        'HSI ${c.hueSaturation.$1.round()}·'
                        '${(c.hueSaturation.$2 * 100).round()}·'
                        '${(c.intensity * 100).round()}',
                      )
                  else
                    for (final s in value.cctSources)
                      pill(
                        _color(s.rgb),
                        '${s.role.label} · ${s.kelvin} K'
                        '${s.stops == 0 ? '' : ' · ${_stopsLabel(s.stops)}'}',
                      ),
                  if (option != null)
                    pill(
                      Colors.white70,
                      '${option.label} · ${option.stopsLabel}',
                    ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.tune, size: 16),
              label: const Text('Editar'),
            ),
          ],
        ),
      ),
    );
  }
}

String _stopsLabel(double stops) {
  final v = stops % 1 == 0 ? stops.toInt().toString() : stops.toString();
  return '${stops > 0 ? '+' : ''}$v st'.replaceAll('.', ',');
}

/// Barra con la parte de luz que pone cada fuente.
class _MixBar extends StatelessWidget {
  final List<(int rgb, double share)> mix;

  const _MixBar({required this.mix});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 18,
            child: Row(
              children: [
                for (final (rgb, share) in mix)
                  Expanded(
                    flex: (share * 1000).round().clamp(1, 1000),
                    child: ColoredBox(color: _color(rgb)),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            for (final (_, share) in mix)
              Expanded(
                flex: (share * 1000).round().clamp(1, 1000),
                child: Text(
                  '${(share * 100).round()} %',
                  style: AppTypography.caption(palette).copyWith(fontSize: 10),
                  overflow: TextOverflow.clip,
                  maxLines: 1,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Fuentes de luz blanca (CCT): clave, relleno, contra, prácticos…, cada
/// una con su temperatura, su tinte, cuánto da y cómo es.
class _CctSources extends StatelessWidget {
  final List<CctSource> sources;
  final int? whiteBalance;

  /// Temperatura general del proyecto, marcada en la clave para comparar.
  final int? referenceKelvin;
  final ValueChanged<List<CctSource>> onChanged;

  const _CctSources({
    required this.sources,
    required this.whiteBalance,
    required this.onChanged,
    this.referenceKelvin,
  });

  LightColorRole _nextRole() {
    for (final role in [
      LightColorRole.key,
      LightColorRole.fill,
      LightColorRole.back,
      LightColorRole.practical,
    ]) {
      if (!sources.any((s) => s.role == role)) return role;
    }
    return LightColorRole.ambient;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final label = BiblePointPanel.labelStyle(palette);
    final key = sources.where((s) => s.role == LightColorRole.key).firstOrNull;

    void replace(int i, CctSource next) =>
        onChanged([for (final (j, s) in sources.indexed) j == i ? next : s]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('FUENTES DE LUZ', style: label),
        const SizedBox(height: 6),
        if (sources.isEmpty)
          Text(
            'Añade la clave y, si quieres, relleno, contra y prácticos: el '
            'contraste sale de cuánto da cada una.',
            style: AppTypography.caption(palette),
          ),
        for (final (i, source) in sources.indexed)
          _CctSourceTile(
            key: ValueKey('cct_$i'),
            source: source,
            whiteBalance: whiteBalance,
            keyKelvin: key?.kelvin,
            referenceKelvin: source.role == LightColorRole.key
                ? referenceKelvin
                : null,
            onChanged: (next) => replace(i, next),
            onRemove: () => onChanged([
              for (final (j, s) in sources.indexed)
                if (j != i) s,
            ]),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              final role = _nextRole();
              onChanged([
                ...sources,
                CctSource(
                  role: role,
                  kelvin: key?.kelvin ?? 3200,
                  stops: switch (role) {
                    LightColorRole.key => 0,
                    LightColorRole.fill => -2,
                    LightColorRole.back => -1,
                    _ => -2,
                  },
                  soft: role == LightColorRole.fill,
                ),
              ]);
            },
            icon: const Icon(Icons.add, size: 16),
            label: Text('Fuente (${_nextRole().label.toLowerCase()})'),
          ),
        ),
      ],
    );
  }
}

class _CctSourceTile extends StatefulWidget {
  final CctSource source;
  final int? whiteBalance;
  final int? keyKelvin;
  final int? referenceKelvin;
  final ValueChanged<CctSource> onChanged;
  final VoidCallback onRemove;

  const _CctSourceTile({
    super.key,
    required this.source,
    required this.whiteBalance,
    required this.keyKelvin,
    this.referenceKelvin,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_CctSourceTile> createState() => _CctSourceTileState();
}

class _CctSourceTileState extends State<_CctSourceTile> {
  bool _open = false;
  late final _name = TextEditingController(text: widget.source.name);

  @override
  void didUpdateWidget(_CctSourceTile old) {
    super.didUpdateWidget(old);
    if (old.source.name != widget.source.name &&
        _name.text != widget.source.name) {
      _name.text = widget.source.name;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _set(CctSource next) => widget.onChanged(next);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final s = widget.source;
    final mono = AppTypography.mono(palette).copyWith(fontSize: 12);
    final caption = AppTypography.caption(palette);
    final look = LightingMetrics(
      kelvin: s.kelvin,
    ).lookAgainst(widget.whiteBalance);
    final recipe = s.recipe(correctionGels());

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
      decoration: BoxDecoration(
        color: palette.background.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: _color(s.rgb),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              PopupMenuButton<LightColorRole>(
                tooltip: 'Papel de la fuente',
                onSelected: (role) => _set(s.copyWith(role: role)),
                itemBuilder: (_) => [
                  for (final role in LightColorRole.values)
                    PopupMenuItem(value: role, child: Text(role.label)),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    s.role.label,
                    style: AppTypography.bodyMedium(
                      palette,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: _name,
                  style: AppTypography.bodyMedium(palette),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Qué es: farola, Skypanel…',
                    hintStyle: caption,
                  ),
                  onSubmitted: (v) => _set(s.copyWith(name: v.trim())),
                  onTapOutside: (_) {
                    if (_name.text.trim() != s.name) {
                      _set(s.copyWith(name: _name.text.trim()));
                    }
                  },
                ),
              ),
              Text('${s.kelvin} K', style: mono),
              // Cuánto da respecto a la clave.
              IconButton(
                tooltip: 'Medio stop menos',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.remove, size: 14),
                onPressed: () => _set(s.copyWith(stops: s.stops - 0.5)),
              ),
              SizedBox(
                width: 48,
                child: Text(
                  s.role == LightColorRole.key && s.stops == 0
                      ? 'clave'
                      : _stopsLabel(s.stops),
                  style: mono,
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                tooltip: 'Medio stop más',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add, size: 14),
                onPressed: () => _set(s.copyWith(stops: s.stops + 0.5)),
              ),
              Tooltip(
                message: s.soft ? 'Suave (difusa)' : 'Dura',
                child: InkWell(
                  onTap: () => _set(s.copyWith(soft: !s.soft)),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      s.soft ? Icons.blur_on : Icons.flare,
                      size: 16,
                      color: palette.textSecondary,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: _open ? 'Plegar' : 'Temperatura, tinte y gelatina',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  _open ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                ),
                onPressed: () => setState(() => _open = !_open),
              ),
              IconButton(
                tooltip: 'Quitar fuente',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close, size: 14, color: palette.textTertiary),
                onPressed: widget.onRemove,
              ),
            ],
          ),
          if (look != null)
            Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 4),
              child: Text(look, style: caption),
            ),
          if (_open) ...[
            const SizedBox(height: 6),
            _ScaleBar(
              semanticLabel: 'Temperatura de ${s.role.label.toLowerCase()}',
              position: _kelvinToX(s.kelvin),
              referencePosition: widget.referenceKelvin == null
                  ? null
                  : _kelvinToX(widget.referenceKelvin!),
              colors: [
                for (var i = 0; i <= 24; i++)
                  _color(LightingMetrics.colorOf(_xToKelvin(i / 24))),
              ],
              onChanged: (x) => _set(s.copyWith(kelvin: _xToKelvin(x))),
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
                    selected: s.kelvin == mark.kelvin,
                    onTap: () => _set(s.copyWith(kelvin: mark.kelvin)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'TINTE · ${LightingMetrics(tint: s.tint).tintLabel}',
              style: BiblePointPanel.labelStyle(palette),
            ),
            const SizedBox(height: 4),
            _ScaleBar(
              semanticLabel: 'Tinte',
              position:
                  (s.tint + LightingMetrics.maxTint) /
                  (2 * LightingMetrics.maxTint),
              colors: const [
                Color(0xFFD946C8),
                Color(0xFFE8E8E8),
                Color(0xFF3FCB5E),
              ],
              onChanged: (x) {
                final tint = (x * 2 - 1) * LightingMetrics.maxTint;
                _set(s.copyWith(tint: tint.abs() < 1.5 ? 0 : tint));
              },
            ),
            const SizedBox(height: 8),
            Text(
              'EL APARATO PARTE DE',
              style: BiblePointPanel.labelStyle(palette),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final native in kLightSources)
                  _Chip(
                    label: native.name,
                    detail: '${native.kelvin}',
                    dot: _color(LightingMetrics.colorOf(native.kelvin)),
                    selected: s.nativeKelvin == native.kelvin,
                    onTap: () => _set(s.copyWith(nativeKelvin: native.kelvin)),
                  ),
              ],
            ),
            if (recipe != null) ...[
              const SizedBox(height: 6),
              _RecipeView(recipe: recipe),
            ],
          ],
        ],
      ),
    );
  }
}
