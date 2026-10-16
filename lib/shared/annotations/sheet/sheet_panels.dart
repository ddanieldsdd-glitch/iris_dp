import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../annotation_brush_catalog.dart';
import '../annotation_brushes.dart';
import '../annotation_canvas.dart';
import '../annotation_document.dart';

/// Panel flotante del folio (pinceles, capas, color), al estilo Procreate.
class SheetPanel extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget> actions;
  final double width;

  const SheetPanel({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.width = 330,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.surfaceElevated,
      elevation: 12,
      shadowColor: Colors.black54,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 6, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: AppTypography.titleMedium(palette),
                    ),
                  ),
                  ...actions,
                ],
              ),
            ),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}

// ─── Pinceles ────────────────────────────────────────────────────────────────

/// Trazo de muestra de un pincel, pintado con el propio motor.
class BrushPreviewPainter extends CustomPainter {
  final BrushSpec brush;
  final Color color;
  final AnnotationPaper paper;

  const BrushPreviewPainter({
    required this.brush,
    required this.color,
    required this.paper,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final dark =
        brush.mode != BrushMode.paint || color.computeLuminance() > 0.8;
    canvas.drawRect(
      rect,
      Paint()
        ..color = dark
            ? const Color(0xFF7F878D)
            : BrushCatalog.paperColor(paper),
    );
    if (brush.mode == BrushMode.smudge) {
      _paintSmudgeHint(canvas, size);
      return;
    }
    // Se pinta como en un folio de 900 px, a tamaño real: así el grano y
    // el grosor se ven como al dibujar. La tira es una ventana de ese folio.
    const virtual = Size(900, 900);
    final w = size.width;
    final h = size.height;
    final maxWidth = h * 0.62 / (0.9 * brush.sizeScale);
    final points = brush.isArea
        ? [
            for (var i = 0; i < 24; i++)
              AnnotationPoint(
                x: (w * 0.5 + math.cos(i / 24 * 2 * math.pi) * w * 0.3) / 900,
                y: (h * 0.5 + math.sin(i / 24 * 2 * math.pi) * h * 0.34) / 900,
              ),
          ]
        : [
            for (var i = 0; i <= 40; i++)
              AnnotationPoint(
                x: (w * 0.06 + i / 40 * w * 0.88) / 900,
                y: (h * 0.5 + math.sin(i / 40 * math.pi * 2) * h * 0.22) / 900,
                pressure: 0.2 + 0.8 * math.sin(i / 40 * math.pi),
              ),
          ];
    canvas.save();
    canvas.clipRect(rect);
    canvas.saveLayer(rect, Paint());
    AnnotationBrushes.paintStroke(
      canvas,
      virtual,
      AnnotationStroke(
        id: 'preview-${brush.id}',
        tool: brush.mode == BrushMode.erase
            ? AnnotationToolType.eraseArea
            : brush.family,
        brushId: brush.id,
        colorArgb: brush.mode == BrushMode.erase
            ? 0xFF000000
            : color.toARGB32(),
        width: math.min(brush.defaultWidth, maxWidth),
        opacity: brush.defaultOpacity,
        points: points,
      ),
    );
    canvas.restore();
    canvas.restore();
  }

  void _paintSmudgeHint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF2B2B2B), Color(0x002B2B2B)],
      ).createShader(Offset.zero & size);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.08,
          size.height * 0.3,
          size.width * 0.84,
          size.height * 0.4,
        ),
        Radius.circular(size.height * 0.2),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant BrushPreviewPainter old) =>
      old.brush != brush || old.color != color || old.paper != paper;
}

/// Biblioteca de pinceles: estante del estilo y categorías.
class BrushLibraryPanel extends StatefulWidget {
  final String selectedId;
  final List<String> shelf;
  final String shelfName;
  final Color color;
  final AnnotationPaper paper;
  final bool Function(BrushSpec brush) filter;
  final ValueChanged<BrushSpec> onSelect;
  final String title;

  /// Importar pinceles de Procreate (en «Míos»).
  final VoidCallback? onImport;

  /// Abrir el estudio con un pincel para guardar una variante.
  final ValueChanged<BrushSpec>? onTune;

  final ValueChanged<BrushSpec>? onDelete;

  const BrushLibraryPanel({
    super.key,
    required this.selectedId,
    required this.shelf,
    required this.shelfName,
    required this.color,
    required this.paper,
    required this.filter,
    required this.onSelect,
    this.title = 'Pinceles',
    this.onImport,
    this.onTune,
    this.onDelete,
  });

  @override
  State<BrushLibraryPanel> createState() => _BrushLibraryPanelState();
}

class _BrushLibraryPanelState extends State<BrushLibraryPanel> {
  /// `null` = estante del estilo.
  BrushCategory? _category;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final brushes =
        (_category == null
                ? widget.shelf.map(BrushCatalog.byId).whereType<BrushSpec>()
                : BrushCatalog.inCategory(_category!))
            .where(widget.filter)
            .toList();
    Widget tab(String label, BrushCategory? category) {
      final selected = _category == category;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => setState(() => _category = category),
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    return SheetPanel(
      title: widget.title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Row(
              children: [
                tab(widget.shelfName, null),
                for (final category in BrushCategory.values)
                  tab(BrushCatalog.categoryLabel(category), category),
              ],
            ),
          ),
          if (_category == BrushCategory.custom) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: OutlinedButton.icon(
                onPressed: widget.onImport,
                icon: const Icon(Icons.file_download_outlined, size: 18),
                label: const Text('Importar de Procreate (.brushset)'),
              ),
            ),
            if (brushes.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Text(
                  'Aquí aparecen los pinceles que importes y las variantes '
                  'que guardes desde el estudio de pincel. Se guardan en '
                  'este dispositivo.',
                  style: AppTypography.caption(palette),
                ),
              ),
          ],
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
              itemCount: brushes.length,
              itemBuilder: (context, i) {
                final brush = brushes[i];
                final selected = brush.id == widget.selectedId;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    color: selected
                        ? palette.accent.withValues(alpha: 0.18)
                        : palette.surface,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      key: ValueKey('brush-${brush.id}'),
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => widget.onSelect(brush),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 104,
                              child: Text(
                                brush.name,
                                style: AppTypography.bodyMedium(palette)
                                    .copyWith(
                                      fontWeight: selected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                              ),
                            ),
                            if (selected && widget.onTune != null)
                              IconButton(
                                tooltip: 'Estudio de pincel',
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.tune, size: 18),
                                onPressed: () => widget.onTune!(brush),
                              ),
                            if (brush.category == BrushCategory.custom &&
                                widget.onDelete != null)
                              IconButton(
                                tooltip: 'Quitar pincel',
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                ),
                                onPressed: () => widget.onDelete!(brush),
                              ),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: SizedBox(
                                  height: 44,
                                  child: RepaintBoundary(
                                    child: CustomPaint(
                                      painter: BrushPreviewPainter(
                                        brush: brush,
                                        color: brush.mode == BrushMode.paint
                                            ? widget.color
                                            : Colors.black,
                                        paper: widget.paper,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Capas ───────────────────────────────────────────────────────────────────

/// Panel de capas: miniatura, ojo y opciones de la capa activa.
class LayersPanel extends StatelessWidget {
  final AnnotationCanvasController controller;
  final String activeLayerId;
  final ValueChanged<String> onActivate;

  const LayersPanel({
    super.key,
    required this.controller,
    required this.activeLayerId,
    required this.onActivate,
  });

  static String blendLabel(AnnotationLayerBlend blend) => switch (blend) {
    AnnotationLayerBlend.normal => 'Normal',
    AnnotationLayerBlend.multiply => 'Multiplicar',
    AnnotationLayerBlend.screen => 'Trama',
    AnnotationLayerBlend.add => 'Añadir',
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final layers = controller.layers;
        // Arriba la capa de encima, como en Procreate.
        final shown = layers.reversed.toList();
        return SheetPanel(
          title: 'Capas',
          actions: [
            IconButton(
              tooltip: 'Nueva capa',
              icon: const Icon(Icons.add),
              onPressed: () =>
                  onActivate(controller.addLayer(aboveId: activeLayerId)),
            ),
          ],
          child: ReorderableListView.builder(
            shrinkWrap: true,
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
            itemCount: shown.length,
            onReorderItem: (from, to) {
              final layer = shown[from];
              // La lista va al revés: el índice 0 de la vista es la de arriba.
              controller.moveLayer(layer.id, shown.length - 1 - to);
            },
            itemBuilder: (context, i) {
              final layer = shown[i];
              final active = layer.id == activeLayerId;
              return Padding(
                key: ValueKey('layer-${layer.id}'),
                padding: const EdgeInsets.only(bottom: 6),
                child: Material(
                  color: active
                      ? palette.accent.withValues(alpha: 0.2)
                      : palette.surface,
                  borderRadius: BorderRadius.circular(10),
                  child: Column(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => onActivate(layer.id),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(6, 6, 0, 6),
                          child: Row(
                            children: [
                              ReorderableDragStartListener(
                                index: i,
                                child: Icon(
                                  Icons.drag_indicator,
                                  size: 18,
                                  color: palette.textTertiary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              _LayerThumb(
                                controller: controller,
                                layerId: layer.id,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      layer.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.bodyMedium(palette),
                                    ),
                                    Text(
                                      [
                                        if (layer.blend !=
                                            AnnotationLayerBlend.normal)
                                          blendLabel(layer.blend),
                                        if (layer.opacity < 1)
                                          '${(layer.opacity * 100).round()} %',
                                        if (layer.alphaLock) 'Alfa bloqueado',
                                        if (layer.clip) 'Recorte',
                                        if (layer.locked) 'Bloqueada',
                                      ].join(' · '),
                                      style: AppTypography.caption(palette),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: layer.visible
                                    ? 'Ocultar capa'
                                    : 'Mostrar capa',
                                icon: Icon(
                                  layer.visible
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 20,
                                ),
                                onPressed: () => controller.updateLayer(
                                  layer.id,
                                  visible: !layer.visible,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (active)
                        _LayerOptions(
                          controller: controller,
                          layer: layer,
                          canMerge: layers.first.id != layer.id,
                          canRemove: layers.length > 1,
                          onActivate: onActivate,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _LayerOptions extends StatelessWidget {
  final AnnotationCanvasController controller;
  final AnnotationLayer layer;
  final bool canMerge;
  final bool canRemove;
  final ValueChanged<String> onActivate;

  const _LayerOptions({
    required this.controller,
    required this.layer,
    required this.canMerge,
    required this.canRemove,
    required this.onActivate,
  });

  Future<void> _rename(BuildContext context) async {
    final text = TextEditingController(text: layer.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nombre de la capa'),
        content: TextField(
          controller: text,
          autofocus: true,
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, text.text),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
    text.dispose();
    if (name != null && name.trim().isNotEmpty) {
      controller.updateLayer(layer.id, name: name.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    Widget toggle(String label, bool value, ValueChanged<bool> onChanged) =>
        FilterChip(
          label: Text(label),
          selected: value,
          onSelected: onChanged,
          visualDensity: VisualDensity.compact,
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Opacidad', style: AppTypography.caption(palette)),
              Expanded(
                child: Slider(
                  value: layer.opacity,
                  onChangeStart: (_) => controller.beginGesture(),
                  onChanged: (v) => controller.updateLayer(
                    layer.id,
                    opacity: v,
                    commit: false,
                  ),
                  onChangeEnd: (_) => controller.endGesture(),
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final blend in AnnotationLayerBlend.values)
                ChoiceChip(
                  label: Text(LayersPanel.blendLabel(blend)),
                  selected: layer.blend == blend,
                  onSelected: (_) =>
                      controller.updateLayer(layer.id, blend: blend),
                  visualDensity: VisualDensity.compact,
                ),
              toggle(
                'Bloquear alfa',
                layer.alphaLock,
                (v) => controller.updateLayer(layer.id, alphaLock: v),
              ),
              toggle(
                'Máscara de recorte',
                layer.clip,
                (v) => controller.updateLayer(layer.id, clip: v),
              ),
              toggle(
                'Bloquear capa',
                layer.locked,
                (v) => controller.updateLayer(layer.id, locked: v),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 2,
            children: [
              TextButton.icon(
                onPressed: () => _rename(context),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Nombre'),
              ),
              TextButton.icon(
                onPressed: () {
                  final id = controller.duplicateLayer(layer.id);
                  if (id != null) onActivate(id);
                },
                icon: const Icon(Icons.copy_outlined, size: 16),
                label: const Text('Duplicar'),
              ),
              if (canMerge)
                TextButton.icon(
                  onPressed: () {
                    final layers = controller.layers;
                    final below =
                        layers[layers.indexWhere((l) => l.id == layer.id) - 1];
                    controller.mergeDown(layer.id);
                    onActivate(below.id);
                  },
                  icon: const Icon(Icons.vertical_align_bottom, size: 16),
                  label: const Text('Fusionar abajo'),
                ),
              if (canRemove)
                TextButton.icon(
                  onPressed: () {
                    final layers = controller.layers;
                    final index = layers.indexWhere((l) => l.id == layer.id);
                    controller.removeLayer(layer.id);
                    final next = controller.layers;
                    onActivate(next[math.max(0, index - 1)].id);
                  },
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Borrar'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Miniatura de una capa, sacada de la imagen ya rasterizada del lienzo.
class _LayerThumb extends StatelessWidget {
  final AnnotationCanvasController controller;
  final String layerId;

  const _LayerThumb({required this.controller, required this.layerId});

  @override
  Widget build(BuildContext context) {
    final size = controller.lastSize;
    final aspect = size.isEmpty ? 1.5 : size.width / size.height;
    return Container(
      width: 54,
      height: 54 / aspect.clamp(0.6, 2.4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.black26),
      ),
      child: size.isEmpty
          ? null
          : CustomPaint(
              painter: _LayerThumbPainter(
                controller: controller,
                layerId: layerId,
                document: controller.document,
              ),
            ),
    );
  }
}

class _LayerThumbPainter extends CustomPainter {
  final AnnotationCanvasController controller;
  final String layerId;
  final AnnotationDocument document;

  const _LayerThumbPainter({
    required this.controller,
    required this.layerId,
    required this.document,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final docSize = controller.lastSize;
    final image = controller.compositor.layerImage(document, layerId, docSize);
    final scale = size.width / docSize.width;
    canvas.save();
    canvas.scale(scale);
    if (image != null) {
      canvas.drawImageRect(
        image,
        Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
        Offset.zero & docSize,
        Paint()..filterQuality = FilterQuality.medium,
      );
    }
    for (final stamp in document.stamps) {
      if (document.stampLayerId(stamp) == layerId) {
        AnnotationBrushes.paintStamp(canvas, docSize, stamp);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LayerThumbPainter old) =>
      old.document != document || old.layerId != layerId;
}

// ─── Color ───────────────────────────────────────────────────────────────────

/// Color: disco de tono/saturación, colores del estilo y recientes.
class ColorPanel extends StatelessWidget {
  final Color color;
  final List<int> styleColors;
  final List<int> recent;
  final ValueChanged<Color> onChanged;

  /// Paletas importadas (nombre y colores).
  final List<(String, List<int>)> palettes;
  final VoidCallback? onImportPalette;

  const ColorPanel({
    super.key,
    required this.color,
    required this.styleColors,
    required this.recent,
    required this.onChanged,
    this.palettes = const [],
    this.onImportPalette,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    Widget swatches(String title, List<int> colors) => Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.label(palette)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in colors)
                SheetSwatch(
                  color: Color(c),
                  selected: c == color.toARGB32(),
                  onTap: () => onChanged(Color(c)),
                ),
            ],
          ),
        ],
      ),
    );
    return SheetPanel(
      title: 'Color',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ColorPicker(
                pickerColor: color,
                onColorChanged: onChanged,
                enableAlpha: false,
                labelTypes: const [],
                portraitOnly: true,
                colorPickerWidth: 300,
                pickerAreaHeightPercent: 0.62,
                pickerAreaBorderRadius: BorderRadius.circular(10),
                paletteType: PaletteType.hsvWithHue,
              ),
            ),
            swatches('Del estilo', styleColors),
            if (recent.isNotEmpty) swatches('Recientes', recent),
            for (final (name, colors) in palettes) swatches(name, colors),
            if (onImportPalette != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: OutlinedButton.icon(
                  onPressed: onImportPalette,
                  icon: const Icon(Icons.palette_outlined, size: 18),
                  label: const Text('Importar paleta (.swatches)'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SheetSwatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final double size;

  const SheetSwatch({
    super.key,
    required this.color,
    required this.selected,
    required this.onTap,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? palette.accent : palette.border,
            width: selected ? 2.5 : 1,
          ),
        ),
      ),
    );
  }
}
