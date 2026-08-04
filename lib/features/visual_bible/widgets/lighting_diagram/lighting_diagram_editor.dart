import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

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
  final String initialJson;
  final ValueChanged<String> onChanged;

  const LightingDiagramEditor({
    super.key,
    required this.initialJson,
    required this.onChanged,
  });

  @override
  State<LightingDiagramEditor> createState() => _LightingDiagramEditorState();
}

class _LightingDiagramEditorState extends State<LightingDiagramEditor> {
  late List<LightingDiagramElement> _elements;

  @override
  void initState() {
    super.initState();
    _elements = _decode(widget.initialJson);
  }

  List<LightingDiagramElement> _decode(String json) {
    try {
      final raw = jsonDecode(json) as List<dynamic>;
      return raw
          .map((e) => LightingDiagramElement.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  void _persist() {
    widget.onChanged(jsonEncode(_elements.map((e) => e.toJson()).toList()));
  }

  void _addElement(String type) {
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

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      children: [
        Wrap(
          spacing: 6,
          children: [
            for (final t in ['camera', 'subject', 'key', 'fill', 'rim', 'practical'])
              ActionChip(
                avatar: Icon(_iconFor(t), size: 16),
                label: Text(t),
                onPressed: () => _addElement(t),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: palette.background,
              border: Border.all(color: palette.divider),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              children: [
                CustomPaint(
                  size: Size.infinite,
                  painter: _GridPainter(palette.divider),
                ),
                ..._elements.asMap().entries.map((entry) {
                  final i = entry.key;
                  final el = entry.value;
                  return Positioned(
                    left: el.position.dx - 20,
                    top: el.position.dy - 20,
                    child: GestureDetector(
                      onPanStart: (_) {},
                      onPanUpdate: (d) {
                        setState(() {
                          el.position += d.delta;
                        });
                      },
                      onPanEnd: (_) {
                        _persist();
                      },
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
                              style: AppTypography.caption(palette).copyWith(
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
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
