// lib/features/visual_bible/widgets/bible_section_shared_widgets.dart
//
// Biblioteca de widgets reutilizables para el rediseño de la Biblia de Fotografía.
// Todos usan el design system (context.palette, AppSpacing, AppTypography) —
// nunca hardcode de colores ni tamaños fuera de estos tokens.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BibleSectionHeader
// Número grande gris + título en blanco. Aparece al inicio de cada sección.
// ─────────────────────────────────────────────────────────────────────────────

class BibleSectionHeader extends StatelessWidget {
  final String number;
  final String title;
  final Widget? trailing;

  const BibleSectionHeader({
    super.key,
    required this.number,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            number,
            style: GoogleFonts.inter(
              fontSize: 72,
              fontWeight: FontWeight.w900,
              color: palette.textTertiary.withValues(alpha: 0.35),
              height: 0.85,
              letterSpacing: -4,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: palette.textPrimary,
                    letterSpacing: 2.0,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BibleTechCard
// Label pequeño en gris + valor en JetBrains Mono. Para specs técnicos.
// ─────────────────────────────────────────────────────────────────────────────

class BibleTechCard extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;
  final Color? accentColor;
  final Widget? icon;

  const BibleTechCard({
    super.key,
    required this.label,
    required this.value,
    this.mono = true,
    this.accentColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: palette.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[icon!, const SizedBox(width: 4)],
              Text(
                label.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: palette.textTertiary,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          mono
              ? Text(
                  value,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: accentColor ?? palette.textPrimary,
                  ),
                )
              : Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: accentColor ?? palette.textPrimary,
                  ),
                ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BibleHeroValue
// Valor numérico grande como recurso tipográfico (ISO, K, ratio).
// ─────────────────────────────────────────────────────────────────────────────

class BibleHeroValue extends StatelessWidget {
  final String value;
  final String unit;
  final String? label;
  final Color? color;

  const BibleHeroValue({
    super.key,
    required this.value,
    required this.unit,
    this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textColor = color ?? palette.textPrimary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              label!.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: palette.textTertiary,
                letterSpacing: 1.1,
              ),
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 48,
                fontWeight: FontWeight.w700,
                color: textColor,
                height: 0.9,
                letterSpacing: -2,
              ),
            ),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                unit,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: textColor.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BibleChipRow
// Fila de chips de datos (chips de emoción, chips de filosofía, etc.)
// ─────────────────────────────────────────────────────────────────────────────

class BibleChipRow extends StatelessWidget {
  final List<String> chips;
  final Color? chipColor;
  final bool wrap;

  const BibleChipRow({
    super.key,
    required this.chips,
    this.chipColor,
    this.wrap = true,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = chipColor ?? palette.accent;

    final chipWidgets = chips
        .map(
          (c) => Container(
            margin: const EdgeInsets.only(right: 6, bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
            ),
            child: Text(
              c,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
        )
        .toList();

    if (wrap) {
      return Wrap(children: chipWidgets);
    }
    return Row(children: chipWidgets);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BibleSelectableChipRow
// Chips seleccionables con toggle (para emotion chips, filtros, etc.)
// ─────────────────────────────────────────────────────────────────────────────

class BibleSelectableChipRow extends StatelessWidget {
  final List<String> options;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final Color? activeColor;

  const BibleSelectableChipRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = activeColor ?? palette.accent;
    return Wrap(
      children: options.map((opt) {
        final isSelected = selected.contains(opt);
        return GestureDetector(
          onTap: () {
            final next = List<String>.from(selected);
            if (isSelected) {
              next.remove(opt);
            } else {
              next.add(opt);
            }
            onChanged(next);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(right: 6, bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withValues(alpha: 0.2)
                  : palette.surfaceElevated,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? color.withValues(alpha: 0.6)
                    : palette.border,
                width: isSelected ? 1.0 : 0.5,
              ),
            ),
            child: Text(
              opt,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? color : palette.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BibleEditableList
// Lista editable con botón "Añadir punto". Para tono, atmósfera, etc.
// ─────────────────────────────────────────────────────────────────────────────

class BibleEditableList extends StatelessWidget {
  final String title;
  final List<String> items;
  final ValueChanged<List<String>> onChanged;
  final String addLabel;
  final String itemHint;

  const BibleEditableList({
    super.key,
    required this.title,
    required this.items,
    required this.onChanged,
    this.addLabel = 'Añadir punto',
    this.itemHint = 'Escribe aquí…',
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title, style: AppTypography.titleMedium(palette)),
            ),
            TextButton.icon(
              onPressed: () => onChanged([...items, '']),
              icon: Icon(Icons.add, size: 16, color: palette.accent),
              label: Text(
                addLabel,
                style: TextStyle(fontSize: 13, color: palette.accent),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ...items.asMap().entries.map((e) {
          final i = e.key;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: palette.accent,
                  ),
                ),
                Expanded(
                  child: _EditableListItem(
                    value: e.value,
                    hint: itemHint,
                    onChanged: (v) {
                      final next = List<String>.from(items);
                      next[i] = v;
                      onChanged(next);
                    },
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.remove_circle_outline,
                      size: 16, color: palette.textTertiary),
                  onPressed: () {
                    final next = List<String>.from(items);
                    next.removeAt(i);
                    onChanged(next);
                  },
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _EditableListItem extends StatefulWidget {
  final String value;
  final String hint;
  final ValueChanged<String> onChanged;

  const _EditableListItem({
    required this.value,
    required this.hint,
    required this.onChanged,
  });

  @override
  State<_EditableListItem> createState() => _EditableListItemState();
}

class _EditableListItemState extends State<_EditableListItem> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_EditableListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value &&
        _ctrl.text != widget.value) {
      _ctrl.text = widget.value;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return TextField(
      controller: _ctrl,
      onChanged: widget.onChanged,
      style: GoogleFonts.inter(fontSize: 14, color: palette.textPrimary),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: GoogleFonts.inter(
            fontSize: 14, color: palette.textTertiary),
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BibleThreePillarRow
// Tres columnas: Acto I / II / III o Cámara / Blocking / POV
// ─────────────────────────────────────────────────────────────────────────────

class BiblePillarData {
  final String label;
  final String title;
  final String description;

  const BiblePillarData({
    required this.label,
    required this.title,
    required this.description,
  });
}

class BibleThreePillarRow extends StatelessWidget {
  final List<BiblePillarData> pillars;
  final void Function(int index, String field, String value)? onChanged;
  final Color? accentColor;

  const BibleThreePillarRow({
    super.key,
    required this.pillars,
    this.onChanged,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = accentColor ?? palette.accent;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: pillars.asMap().entries.map((e) {
        final i = e.key;
        final p = e.value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: i < pillars.length - 1 ? AppSpacing.sm : 0,
            ),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: palette.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.border, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      p.label.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: color,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    p.title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    p.description,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: palette.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BibleGafferDirectiveBox
// Caja con icono de advertencia y borde amarillo (warning).
// ─────────────────────────────────────────────────────────────────────────────

class BibleGafferDirectiveBox extends StatelessWidget {
  final String text;
  final String title;

  const BibleGafferDirectiveBox({
    super.key,
    required this.text,
    this.title = 'Gaffer Directives',
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: palette.warning.withValues(alpha: 0.08),
          border: Border.all(
            color: palette.warning.withValues(alpha: 0.25),
            width: 0.5,
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ColoredBox(color: palette.warning, child: const SizedBox(width: 3)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              size: 16, color: palette.warning),
                          const SizedBox(width: 6),
                          Text(
                            title.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: palette.warning,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        text,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: palette.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BibleTechNoteBox
// Caja con borde azul para notas técnicas críticas.
// ─────────────────────────────────────────────────────────────────────────────

class BibleTechNoteBox extends StatelessWidget {
  final String text;
  final String title;

  const BibleTechNoteBox({
    super.key,
    required this.text,
    this.title = 'Technical Note',
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: palette.accent.withValues(alpha: 0.06),
          border: Border.all(
            color: palette.accent.withValues(alpha: 0.25),
            width: 0.5,
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ColoredBox(color: palette.accent, child: const SizedBox(width: 3)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: palette.accent),
                          const SizedBox(width: 6),
                          Text(
                            title.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: palette.accent,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        text,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: palette.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BibleSectionModeDropdown
// Selector de modo visual (Cinematic / Technical / Minimalist).
// ─────────────────────────────────────────────────────────────────────────────

enum BibleVisualMode { cinematic, technical, minimalist }

extension BibleVisualModeExt on BibleVisualMode {
  String get label => switch (this) {
        BibleVisualMode.cinematic => 'Cinematic',
        BibleVisualMode.technical => 'Technical',
        BibleVisualMode.minimalist => 'Minimalist',
      };

  IconData get icon => switch (this) {
        BibleVisualMode.cinematic => Icons.movie_filter_outlined,
        BibleVisualMode.technical => Icons.settings_outlined,
        BibleVisualMode.minimalist => Icons.crop_square_outlined,
      };
}

class BibleSectionModeDropdown extends StatelessWidget {
  final BibleVisualMode value;
  final ValueChanged<BibleVisualMode> onChanged;

  const BibleSectionModeDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: palette.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border, width: 0.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<BibleVisualMode>(
          value: value,
          isDense: true,
          icon: Icon(Icons.expand_more, size: 14, color: palette.textTertiary),
          dropdownColor: palette.surfaceElevated,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: palette.textSecondary,
          ),
          items: BibleVisualMode.values
              .map(
                (m) => DropdownMenuItem(
                  value: m,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(m.icon, size: 14, color: palette.textTertiary),
                      const SizedBox(width: 5),
                      Text(m.label),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (v) => v != null ? onChanged(v) : null,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BibleColorSwatch
// Swatch de color grande con nombre descriptivo + hex code.
// ─────────────────────────────────────────────────────────────────────────────

class BibleColorSwatch extends StatelessWidget {
  final Color color;
  final String name;
  final String hex;
  final bool large;

  const BibleColorSwatch({
    super.key,
    required this.color,
    required this.name,
    required this.hex,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final size = large ? 72.0 : 48.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: palette.border,
              width: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          name,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: palette.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          hex.toUpperCase(),
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            color: palette.textTertiary,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BibleStatusDot
// Punto de color para estados en tablas (OK / Pending / Error).
// ─────────────────────────────────────────────────────────────────────────────

enum BibleStatus { ok, pending, error, warning }

class BibleStatusDot extends StatelessWidget {
  final BibleStatus status;
  final String? label;

  const BibleStatusDot({super.key, required this.status, this.label});

  Color _color(AppPalette p) => switch (status) {
        BibleStatus.ok => p.success,
        BibleStatus.pending => p.warning,
        BibleStatus.error => p.error,
        BibleStatus.warning => p.warning,
      };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final c = _color(palette);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c,
            boxShadow: [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 4)],
          ),
        ),
        if (label != null) ...[
          const SizedBox(width: 5),
          Text(
            label!,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: palette.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BibleHorizontalBar
// Barra de progreso horizontal con label y valor.
// ─────────────────────────────────────────────────────────────────────────────

class BibleHorizontalBar extends StatelessWidget {
  final String label;
  final double fraction; // 0.0 – 1.0
  final String valueLabel;
  final Color? barColor;

  const BibleHorizontalBar({
    super.key,
    required this.label,
    required this.fraction,
    required this.valueLabel,
    this.barColor,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = barColor ?? palette.accent;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: palette.textSecondary,
                  ),
                ),
              ),
              Text(
                valueLabel,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  color: palette.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              backgroundColor: palette.surfaceElevated,
              color: color,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BibleSectionDivider
// Separador visual entre bloques dentro de una sección.
// ─────────────────────────────────────────────────────────────────────────────

class BibleSectionDivider extends StatelessWidget {
  final String? label;

  const BibleSectionDivider({super.key, this.label});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (label == null) {
      return Divider(color: palette.divider, height: AppSpacing.xl * 2);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Row(
        children: [
          Expanded(child: Divider(color: palette.divider, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              label!.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: palette.textTertiary,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Expanded(child: Divider(color: palette.divider, height: 1)),
        ],
      ),
    );
  }
}
