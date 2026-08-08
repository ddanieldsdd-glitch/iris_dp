import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/annotations/annotation_canvas.dart';
import '../../../../shared/annotations/annotation_document.dart';

enum _LightingEditorMode { edit, annotate }

/// Elemento simplificado de diagrama de iluminación.
class LightingDiagramElement {
  String type;
  Offset position;
  double rotation;
  String? label;

  LightingDiagramElement({
    required this.type,
    required this.position,
    this.rotation = 0,
    this.label,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'x': position.dx,
    'y': position.dy,
    'rotation': rotation,
    'label': label,
  };

  factory LightingDiagramElement.fromJson(Map<String, dynamic> json) {
    return LightingDiagramElement(
      type: json['type']?.toString() ?? 'light',
      position: Offset(
        (json['x'] as num?)?.toDouble() ?? 100,
        (json['y'] as num?)?.toDouble() ?? 100,
      ),
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
      label: json['label']?.toString(),
    );
  }
}

/// Editor de diagrama de iluminación en planta (drag & drop).
class LightingDiagramEditor extends StatefulWidget {
  final AppDatabase database;
  final int projectId;
  final int setupId;
  final String initialJson;
  final String? setName;
  final int? locationBasePlanId;
  final ValueChanged<String> onChanged;

  const LightingDiagramEditor({
    super.key,
    required this.database,
    required this.projectId,
    required this.setupId,
    required this.initialJson,
    this.setName,
    this.locationBasePlanId,
    required this.onChanged,
  });

  @override
  State<LightingDiagramEditor> createState() => _LightingDiagramEditorState();
}

class _LightingDiagramEditorState extends State<LightingDiagramEditor> {
  late List<LightingDiagramElement> _elements;
  final AnnotationCanvasController _annotationController =
      AnnotationCanvasController();
  _LightingEditorMode _mode = _LightingEditorMode.edit;
  AnnotationToolType _tool = AnnotationToolType.pen;
  Color _annotationColor = const Color(0xFFFFD54F);
  double _annotationWidth = 6;
  bool _loadingAnnotations = true;
  Future<void> _annotationSaveChain = Future.value();

  @override
  void initState() {
    super.initState();
    _elements = _decode(widget.initialJson);
    _annotationController.addListener(_refreshAnnotationToolbar);
    _loadAnnotations();
  }

  @override
  void didUpdateWidget(covariant LightingDiagramEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialJson != widget.initialJson) {
      _elements = _decode(widget.initialJson);
    }
    if (oldWidget.database != widget.database ||
        oldWidget.projectId != widget.projectId ||
        oldWidget.setupId != widget.setupId) {
      _loadingAnnotations = true;
      _loadAnnotations();
    }
  }

  @override
  void dispose() {
    _annotationController.removeListener(_refreshAnnotationToolbar);
    _annotationController.dispose();
    super.dispose();
  }

  void _refreshAnnotationToolbar() {
    if (mounted) setState(() {});
  }

  Future<void> _loadAnnotations() async {
    final projectId = widget.projectId;
    final setupId = widget.setupId;
    final row = await widget.database.getProjectAnnotationDocument(
      projectId: projectId,
      targetType: 'lighting_setup',
      targetId: setupId.toString(),
    );
    if (!mounted ||
        projectId != widget.projectId ||
        setupId != widget.setupId) {
      return;
    }
    _annotationController.replaceDocument(
      AnnotationDocument.decode(row?.documentJson),
    );
    setState(() => _loadingAnnotations = false);
  }

  void _persistAnnotations(AnnotationDocument document) {
    if (_loadingAnnotations) return;
    final database = widget.database;
    final projectId = widget.projectId;
    final targetId = widget.setupId.toString();
    _annotationSaveChain = _annotationSaveChain
        .then(
          (_) => database.saveProjectAnnotationDocument(
            projectId: projectId,
            targetType: 'lighting_setup',
            targetId: targetId,
            documentJson: document.encode(),
            documentSchemaVersion: document.schemaVersion,
          ),
        )
        .catchError((Object error, StackTrace stackTrace) {
          debugPrint('No se pudo guardar la anotación de iluminación: $error');
        });
  }

  List<LightingDiagramElement> _decode(String json) {
    try {
      final raw = jsonDecode(json) as List<dynamic>;
      return raw
          .map(
            (e) => LightingDiagramElement.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  void _persist() {
    widget.onChanged(jsonEncode(_elements.map((e) => e.toJson()).toList()));
  }

  void _addElement(String type) {
    if (_mode != _LightingEditorMode.edit) return;
    setState(() {
      _elements.add(
        LightingDiagramElement(
          type: type,
          position: const Offset(150, 150),
          label: type,
        ),
      );
    });
    _persist();
  }

  IconData _iconFor(String type) => switch (type) {
    'camera' => Icons.videocam,
    'subject' => Icons.person,
    'key' => Icons.wb_incandescent,
    'fill' => Icons.lightbulb_outline,
    'rim' => Icons.highlight,
    'practical' => Icons.light,
    _ => Icons.wb_sunny_outlined,
  };

  Color _colorFor(String type, AppPalette palette) => switch (type) {
    'camera' => palette.accent,
    'subject' => palette.textPrimary,
    'key' => const Color(0xFFFFD54F),
    'fill' => const Color(0xFF81D4FA),
    'rim' => const Color(0xFFFF8A65),
    'practical' => const Color(0xFFA1887F),
    _ => palette.textSecondary,
  };

  Widget _buildModeToolbar() {
    final colors = <Color>[
      const Color(0xFFFFD54F),
      const Color(0xFFFF5252),
      const Color(0xFF40C4FF),
      const Color(0xFF69F0AE),
      Colors.white,
    ];
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          SegmentedButton<_LightingEditorMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: _LightingEditorMode.edit,
                icon: Icon(Icons.open_with, size: 16),
                label: Text('Editar'),
              ),
              ButtonSegment(
                value: _LightingEditorMode.annotate,
                icon: Icon(Icons.draw_outlined, size: 16),
                label: Text('Anotar'),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (value) {
              setState(() => _mode = value.first);
            },
          ),
          if (_mode == _LightingEditorMode.annotate) ...[
            const SizedBox(width: 8),
            for (final tool in AnnotationToolType.values.where(
              (t) =>
                  t != AnnotationToolType.select,
            ))
              IconButton(
                tooltip: switch (tool) {
                  AnnotationToolType.pen => 'Lápiz',
                  AnnotationToolType.highlighter => 'Subrayador',
                  AnnotationToolType.arrow => 'Flecha',
                  AnnotationToolType.eraser => 'Goma',
                  AnnotationToolType.select => 'Seleccionar',
                },
                isSelected: _tool == tool,
                onPressed: () => setState(() => _tool = tool),
                icon: Icon(switch (tool) {
                  AnnotationToolType.pen => Icons.edit,
                  AnnotationToolType.highlighter => Icons.brush,
                  AnnotationToolType.arrow => Icons.arrow_outward,
                  AnnotationToolType.eraser => Icons.auto_fix_off,
                  AnnotationToolType.select => Icons.pan_tool_alt_outlined,
                }, size: 18),
              ),
            PopupMenuButton<Color>(
              tooltip: 'Color',
              initialValue: _annotationColor,
              onSelected: (color) => setState(() => _annotationColor = color),
              itemBuilder: (_) => colors
                  .map(
                    (color) => PopupMenuItem(
                      value: color,
                      child: Row(
                        children: [
                          Icon(Icons.circle, color: color, size: 18),
                          if (color == _annotationColor) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.check, size: 16),
                          ],
                        ],
                      ),
                    ),
                  )
                  .toList(),
              icon: Icon(Icons.circle, color: _annotationColor, size: 18),
            ),
            Tooltip(
              message: 'Grosor',
              child: DropdownButtonHideUnderline(
                child: DropdownButton<double>(
                  value: _annotationWidth,
                  items: const [3.0, 6.0, 10.0, 16.0]
                      .map(
                        (width) => DropdownMenuItem(
                          value: width,
                          child: Text('${width.round()} px'),
                        ),
                      )
                      .toList(),
                  onChanged: (width) {
                    if (width != null) {
                      setState(() => _annotationWidth = width);
                    }
                  },
                ),
              ),
            ),
            IconButton(
              tooltip: 'Deshacer anotación',
              onPressed: _annotationController.canUndo
                  ? _annotationController.undo
                  : null,
              icon: const Icon(Icons.undo, size: 18),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      children: [
        if (widget.setName != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                Icon(Icons.location_on_outlined,
                    size: 14, color: palette.textTertiary),
                const SizedBox(width: 6),
                Text(
                  widget.setName!,
                  style: AppTypography.label(palette).copyWith(
                    fontSize: 11,
                    letterSpacing: 0.8,
                    color: palette.textSecondary,
                  ),
                ),
                if (widget.locationBasePlanId != null) ...[
                  const Spacer(),
                  Text(
                    'Set #${widget.locationBasePlanId}',
                    style: AppTypography.mono(palette).copyWith(
                      fontSize: 10,
                      color: palette.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        _buildModeToolbar(),
        if (_mode == _LightingEditorMode.edit)
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final t in [
                  'camera',
                  'subject',
                  'key',
                  'fill',
                  'rim',
                  'practical',
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      avatar: Icon(_iconFor(t), size: 16),
                      label: Text(t),
                      onPressed: () => _addElement(t),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              decoration: BoxDecoration(
                color: palette.background,
                border: Border.all(color: palette.divider),
                borderRadius: BorderRadius.circular(8),
              ),
              child: AnnotationCanvas(
                controller: _annotationController,
                enabled:
                    _mode == _LightingEditorMode.annotate &&
                    !_loadingAnnotations,
                tool: _tool,
                color: _annotationColor,
                width: _annotationWidth,
                acceptTouch: true,
                onChanged: _persistAnnotations,
                child: Stack(
                  children: [
                    CustomPaint(
                      size: Size.infinite,
                      painter: _GridPainter(palette.divider),
                    ),
                    ..._elements.map((el) {
                      return Positioned(
                        left: el.position.dx - 20,
                        top: el.position.dy - 20,
                        child: IgnorePointer(
                          ignoring: _mode != _LightingEditorMode.edit,
                          child: GestureDetector(
                            onPanUpdate: (d) {
                              setState(() {
                                el.position += d.delta;
                              });
                            },
                            onPanEnd: (_) => _persist(),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _iconFor(el.type),
                                  color: _colorFor(el.type, palette),
                                  size: 28,
                                ),
                                if (el.label != null)
                                  Text(
                                    el.label!,
                                    style: AppTypography.caption(
                                      palette,
                                    ).copyWith(fontSize: 10),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    if (_loadingAnnotations)
                      const Positioned(
                        right: 8,
                        bottom: 8,
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  final Color color;

  _GridPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = 0.5;
    const step = 40.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
