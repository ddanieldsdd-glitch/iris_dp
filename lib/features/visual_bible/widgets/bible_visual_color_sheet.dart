import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Resultado del selector visual de color.
class BibleColorPickResult {
  final String name;
  final String hex;
  final String? meaning;
  final bool delete;

  const BibleColorPickResult({
    required this.name,
    required this.hex,
    this.meaning,
    this.delete = false,
  });
}

/// Presets con nombres humanos (look DP / cine).
class BibleNamedSwatch {
  final String name;
  final String hint;
  final Color color;

  const BibleNamedSwatch({
    required this.name,
    required this.hint,
    required this.color,
  });

  String get hex =>
      '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
}

const kBibleLookSwatches = <BibleNamedSwatch>[
  BibleNamedSwatch(
    name: 'Negro cine',
    hint: 'Sombras densas',
    color: Color(0xFF0A0E14),
  ),
  BibleNamedSwatch(
    name: 'Teal noche',
    hint: 'Sombras frías',
    color: Color(0xFF1A3C40),
  ),
  BibleNamedSwatch(
    name: 'Ámbar práctico',
    hint: 'Tungsteno / practical',
    color: Color(0xFFE8A838),
  ),
  BibleNamedSwatch(
    name: 'Piel cálida',
    hint: 'Key en sujeto',
    color: Color(0xFFC6866A),
  ),
  BibleNamedSwatch(
    name: 'Cyan frío',
    hint: 'Fill / luna',
    color: Color(0xFF4A90D9),
  ),
  BibleNamedSwatch(
    name: 'Humo gris',
    hint: 'Atmósfera',
    color: Color(0xFF7F8C8D),
  ),
  BibleNamedSwatch(
    name: 'Rojo señal',
    hint: 'Acento peligro',
    color: Color(0xFFE74C3C),
  ),
  BibleNamedSwatch(
    name: 'Verde hospital',
    hint: 'Fluorescente',
    color: Color(0xFF3D8B6E),
  ),
  BibleNamedSwatch(
    name: 'Magenta neón',
    hint: 'Acento nocturno',
    color: Color(0xFFFF2D95),
  ),
  BibleNamedSwatch(
    name: 'Hueso',
    hint: 'Highlights suaves',
    color: Color(0xFFE8E0D5),
  ),
  BibleNamedSwatch(
    name: 'Azul acero',
    hint: 'Día nublado',
    color: Color(0xFF5B7C99),
  ),
  BibleNamedSwatch(
    name: 'Tierra',
    hint: 'Desierto / polvo',
    color: Color(0xFFA58D70),
  ),
];

/// Sheet visual para elegir color: presets nombrados + rueda, sin teclear hex.
class BibleVisualColorSheet extends StatefulWidget {
  final String title;
  final String initialName;
  final Color initialColor;
  final bool canDelete;
  final String? nameHint;
  final bool includeMeaning;
  final String initialMeaning;

  const BibleVisualColorSheet({
    super.key,
    required this.title,
    required this.initialName,
    required this.initialColor,
    this.canDelete = false,
    this.nameHint,
    this.includeMeaning = false,
    this.initialMeaning = '',
  });

  static Future<BibleColorPickResult?> show(
    BuildContext context, {
    required String title,
    String initialName = '',
    Color initialColor = const Color(0xFF1A3C40),
    bool canDelete = false,
    String? nameHint,
    bool includeMeaning = false,
    String initialMeaning = '',
  }) {
    return showModalBottomSheet<BibleColorPickResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.palette.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => BibleVisualColorSheet(
        title: title,
        initialName: initialName,
        initialColor: initialColor,
        canDelete: canDelete,
        nameHint: nameHint,
        includeMeaning: includeMeaning,
        initialMeaning: initialMeaning,
      ),
    );
  }

  @override
  State<BibleVisualColorSheet> createState() => _BibleVisualColorSheetState();
}

class _BibleVisualColorSheetState extends State<BibleVisualColorSheet> {
  late Color _color;
  late TextEditingController _nameCtrl;
  late TextEditingController _meaningCtrl;
  bool _fineTune = false;

  @override
  void initState() {
    super.initState();
    _color = widget.initialColor;
    _nameCtrl = TextEditingController(
      text: widget.initialName.trim().isEmpty
          ? _suggestName(widget.initialColor)
          : widget.initialName,
    );
    _meaningCtrl = TextEditingController(text: widget.initialMeaning);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _meaningCtrl.dispose();
    super.dispose();
  }

  String get _hex =>
      '#${_color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

  static String _suggestName(Color c) {
    var best = kBibleLookSwatches.first;
    var bestDist = double.infinity;
    for (final s in kBibleLookSwatches) {
      final d = _colorDistance(c, s.color);
      if (d < bestDist) {
        bestDist = d;
        best = s;
      }
    }
    if (bestDist < 80) return best.name;
    final hsl = HSLColor.fromColor(c);
    if (hsl.lightness < 0.12) return 'Negro profundo';
    if (hsl.lightness > 0.88) return 'Blanco suave';
    if (hsl.saturation < 0.12) return 'Gris neutro';
    if (hsl.hue < 30 || hsl.hue >= 330) return 'Rojo / cálido';
    if (hsl.hue < 60) return 'Ámbar / naranja';
    if (hsl.hue < 90) return 'Amarillo';
    if (hsl.hue < 160) return 'Verde';
    if (hsl.hue < 200) return 'Cyan / teal';
    if (hsl.hue < 260) return 'Azul';
    return 'Violeta / magenta';
  }

  static double _colorDistance(Color a, Color b) {
    final dr = (a.r - b.r) * 255;
    final dg = (a.g - b.g) * 255;
    final db = (a.b - b.b) * 255;
    return dr * dr + dg * dg + db * db;
  }

  void _pickPreset(BibleNamedSwatch s) {
    setState(() {
      _color = s.color;
      if (_nameCtrl.text.trim().isEmpty ||
          kBibleLookSwatches.any((p) => p.name == _nameCtrl.text.trim()) ||
          _nameCtrl.text == _suggestName(_color)) {
        _nameCtrl.text = s.name;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final bottom = MediaQuery.paddingOf(context).bottom;

    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        bottom + keyboard + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(widget.title, style: AppTypography.titleMedium(palette)),
            const SizedBox(height: 4),
            Text(
              'Elige un color por aspecto o afina a ojo. El código hex es opcional.',
              style: AppTypography.caption(palette).copyWith(
                    color: palette.textSecondary,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _color,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _color.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Nombre del color',
                      hintText: widget.nameHint ?? 'Ej. Teal noche, piel cálida…',
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            if (widget.includeMeaning) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _meaningCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Significado',
                  hintText: 'Qué comunica este color en la historia…',
                  isDense: true,
                ),
              ),
            ],
            const SizedBox(height: 18),
            Text(
              'LOOKS RÁPIDOS',
              style: AppTypography.mono(palette).copyWith(
                    fontSize: 10,
                    letterSpacing: 1.1,
                    color: palette.textTertiary,
                  ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in kBibleLookSwatches)
                  _PresetChip(
                    swatch: s,
                    selected: _colorDistance(_color, s.color) < 40,
                    onTap: () => _pickPreset(s),
                    palette: palette,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () => setState(() => _fineTune = !_fineTune),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      _fineTune
                          ? Icons.expand_less
                          : Icons.tune,
                      size: 18,
                      color: palette.accent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _fineTune ? 'Ocultar ajuste fino' : 'Ajustar a ojo',
                      style: TextStyle(
                        color: palette.accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _hex,
                      style: AppTypography.mono(palette).copyWith(
                            fontSize: 11,
                            color: palette.textTertiary,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            if (_fineTune) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 220,
                child: ColorPicker(
                  pickerColor: _color,
                  onColorChanged: (c) => setState(() {
                    _color = c;
                    final auto = _suggestName(c);
                    if (kBibleLookSwatches
                            .any((p) => p.name == _nameCtrl.text.trim()) ||
                        _nameCtrl.text.trim().isEmpty) {
                      _nameCtrl.text = auto;
                    }
                  }),
                  enableAlpha: false,
                  hexInputBar: false,
                  labelTypes: const [],
                  portraitOnly: true,
                  pickerAreaHeightPercent: 0.7,
                  displayThumbColor: true,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                if (widget.canDelete)
                  TextButton(
                    onPressed: () => Navigator.pop(
                      context,
                      const BibleColorPickResult(
                        name: '',
                        hex: '',
                        delete: true,
                      ),
                    ),
                    child: Text(
                      'Eliminar',
                      style: TextStyle(color: palette.error),
                    ),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    final name = _nameCtrl.text.trim().isEmpty
                        ? _suggestName(_color)
                        : _nameCtrl.text.trim();
                    Navigator.pop(
                      context,
                      BibleColorPickResult(
                        name: name,
                        hex: _hex,
                        meaning: widget.includeMeaning
                            ? _meaningCtrl.text.trim()
                            : null,
                      ),
                    );
                  },
                  child: const Text('Usar color'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final BibleNamedSwatch swatch;
  final bool selected;
  final VoidCallback onTap;
  final AppPalette palette;

  const _PresetChip({
    required this.swatch,
    required this.selected,
    required this.onTap,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? swatch.color.withValues(alpha: 0.22)
          : palette.surfaceOverlay,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 108,
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? swatch.color.withValues(alpha: 0.7)
                  : palette.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 28,
                decoration: BoxDecoration(
                  color: swatch.color,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                swatch.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
              Text(
                swatch.hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: palette.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color? bibleParseHex(String? hex) {
  if (hex == null) return null;
  var h = hex.trim();
  if (h.startsWith('#')) h = h.substring(1);
  if (h.length == 3) {
    h = '${h[0]}${h[0]}${h[1]}${h[1]}${h[2]}${h[2]}';
  }
  if (h.length != 6) return null;
  final v = int.tryParse(h, radix: 16);
  if (v == null) return null;
  return Color(0xFF000000 | v);
}

String bibleNormalizeHex(String hex) {
  var h = hex.trim();
  if (!h.startsWith('#')) h = '#$h';
  return h.toUpperCase();
}

/// Editor visual de una paleta (lista de hex) sin teclear códigos.
class BiblePaletteEditorSheet extends StatefulWidget {
  final String title;
  final List<String> initialColors;

  const BiblePaletteEditorSheet({
    super.key,
    required this.title,
    required this.initialColors,
  });

  static Future<List<String>?> show(
    BuildContext context, {
    required String title,
    required List<String> initialColors,
  }) {
    return showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.palette.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => BiblePaletteEditorSheet(
        title: title,
        initialColors: initialColors,
      ),
    );
  }

  @override
  State<BiblePaletteEditorSheet> createState() =>
      _BiblePaletteEditorSheetState();
}

class _BiblePaletteEditorSheetState extends State<BiblePaletteEditorSheet> {
  late List<String> _colors;

  @override
  void initState() {
    super.initState();
    _colors = widget.initialColors
        .map(bibleNormalizeHex)
        .where((h) => bibleParseHex(h) != null)
        .toList();
  }

  String _labelFor(String hex) {
    final c = bibleParseHex(hex);
    if (c == null) return hex;
    var best = kBibleLookSwatches.first;
    var bestDist = double.infinity;
    for (final s in kBibleLookSwatches) {
      final dr = (c.r - s.color.r) * 255;
      final dg = (c.g - s.color.g) * 255;
      final db = (c.b - s.color.b) * 255;
      final d = dr * dr + dg * dg + db * db;
      if (d < bestDist) {
        bestDist = d;
        best = s;
      }
    }
    return bestDist < 80 ? best.name : 'Color';
  }

  Future<void> _addOrEdit({int? index}) async {
    final existing = index != null ? _colors[index] : null;
    final picked = await BibleVisualColorSheet.show(
      context,
      title: index == null ? 'Añadir color' : 'Editar color',
      initialName: existing != null ? _labelFor(existing) : '',
      initialColor:
          bibleParseHex(existing) ?? const Color(0xFF1A3C40),
      canDelete: index != null,
    );
    if (picked == null) return;
    setState(() {
      if (picked.delete && index != null) {
        _colors.removeAt(index);
      } else if (!picked.delete) {
        final h = bibleNormalizeHex(picked.hex);
        if (index == null) {
          _colors.add(h);
        } else {
          _colors[index] = h;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: palette.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(widget.title, style: AppTypography.titleMedium(palette)),
          const SizedBox(height: 4),
          Text(
            'Toca un color para editarlo o añade uno nuevo a ojo.',
            style: AppTypography.caption(palette).copyWith(
                  color: palette.textSecondary,
                ),
          ),
          const SizedBox(height: 16),
          if (_colors.isEmpty)
            Container(
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.surfaceOverlay,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: palette.border),
              ),
              child: Text(
                'Aún no hay colores base',
                style: AppTypography.caption(palette),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _colors.length; i++)
                  Material(
                    color: bibleParseHex(_colors[i]) ?? palette.surfaceOverlay,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () => _addOrEdit(index: i),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 100,
                        padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Text(
                          _labelFor(_colors[i]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            shadows: [
                              Shadow(blurRadius: 4, color: Colors.black54),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _addOrEdit(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Añadir color'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => Navigator.pop(context, _colors),
                child: const Text('Guardar paleta'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
