import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../annotation_brush_catalog.dart';
import '../annotation_document.dart';
import 'sheet_panels.dart';

/// Lo que se guarda desde el estudio: nombre y ajustes de la variante.
class BrushStudioResult {
  final String name;
  final Map<String, double> params;

  const BrushStudioResult(this.name, this.params);
}

/// Estudio de pincel sencillo: se tocan los ajustes de un pincel viendo la
/// muestra y se guarda como pincel propio.
Future<BrushStudioResult?> showBrushStudio(
  BuildContext context, {
  required BrushSpec base,
  required Color color,
  required AnnotationPaper paper,
}) {
  return showDialog<BrushStudioResult>(
    context: context,
    builder: (_) => _BrushStudio(base: base, color: color, paper: paper),
  );
}

class _BrushStudio extends StatefulWidget {
  final BrushSpec base;
  final Color color;
  final AnnotationPaper paper;

  const _BrushStudio({
    required this.base,
    required this.color,
    required this.paper,
  });

  @override
  State<_BrushStudio> createState() => _BrushStudioState();
}

class _BrushStudioState extends State<_BrushStudio> {
  static const _previewId = 'studio.preview';
  late final Map<String, double> _params = Map.of(widget.base.params);
  late final TextEditingController _name = TextEditingController(
    text: '${widget.base.name} (mío)',
  );

  @override
  void dispose() {
    BrushCatalog.unregister(_previewId);
    _name.dispose();
    super.dispose();
  }

  BrushSpec get _preview {
    final spec = widget.base.derive(id: _previewId, params: _params);
    // La muestra pinta por id: se registra la variante en vivo.
    BrushCatalog.register(spec);
    return spec;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final base = widget.base;
    Widget slider(
      String label,
      String key,
      double min,
      double max, {
      bool log = false,
    }) {
      final v = (_params[key] ?? 0).clamp(min, max);
      final t = log
          ? math.log(v / min) / math.log(max / min)
          : (v - min) / (max - min);
      return Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: AppTypography.bodyMedium(palette)),
          ),
          Expanded(
            child: Slider(
              value: t.clamp(0.0, 1.0),
              onChanged: (x) => setState(
                () => _params[key] = log
                    ? min * math.pow(max / min, x).toDouble()
                    : min + (max - min) * x,
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              v >= 10 ? v.toStringAsFixed(0) : v.toStringAsFixed(2),
              textAlign: TextAlign.end,
              style: AppTypography.caption(palette),
            ),
          ),
        ],
      );
    }

    final preview = _preview;
    return AlertDialog(
      title: const Text('Estudio de pincel'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 90,
                  child: CustomPaint(
                    painter: BrushPreviewPainter(
                      brush: preview,
                      color: widget.color,
                      paper: widget.paper,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 8),
              slider('Grosor', 'defaultWidth', 0.5, 150, log: true),
              slider('Espaciado', 'spacing', 0.02, 1.5, log: true),
              if (!base.wet) slider('Flujo', 'flow', 0.03, 1),
              slider('Presión → tamaño', 'pressureSize', 0, 1),
              if (!base.wet)
                slider('Presión → opacidad', 'pressureOpacity', 0, 1),
              slider('Afilado al empezar', 'taperStart', 0, 6),
              slider('Afilado al acabar', 'taperEnd', 0, 6),
              slider('Dispersión', 'scatter', 0, 1),
              slider('Giro al azar', 'rotationJitter', 0, 1),
              if (base.grain != null || base.grainImage != null) ...[
                slider('Profundidad del grano', 'grainDepth', 0, 1),
                slider('Tamaño del grano', 'grainScale', 0.3, 4),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final name = _name.text.trim();
            Navigator.pop(
              context,
              BrushStudioResult(name.isEmpty ? base.name : name, _params),
            );
          },
          child: const Text('Guardar en «Míos»'),
        ),
      ],
    );
  }
}
