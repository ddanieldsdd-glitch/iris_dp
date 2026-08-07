// lib/features/visual_bible/widgets/narrative_bridge_card.dart
//
// Tarjeta de Intención Narrativa — rediseñada con borde azul izquierdo,
// fondo ambientBlue, texto en cursiva y etiqueta en caps con icono.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import 'bible_form_widgets.dart';

/// Tarjeta transversal: ¿por qué esta decisión técnica sirve a la narrativa?
///
/// Muestra un borde izquierdo azul, fondo con tinte azul sutil,
/// la etiqueta "INTENCIÓN NARRATIVA" con icono, y el texto en cursiva.
class NarrativeBridgeCard extends StatelessWidget {
  final String hint;
  final String? value;
  final ValueChanged<String> onChanged;
  final String title;
  final String? subtitle;

  const NarrativeBridgeCard({
    super.key,
    required this.hint,
    required this.value,
    required this.onChanged,
    this.title = 'Intención narrativa',
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: palette.ambientBlue,
          border: Border.all(
            color: palette.accent.withValues(alpha: 0.15),
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
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.auto_stories_outlined,
                            color: palette.accent,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            title.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: palette.accent,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: palette.accent.withValues(alpha: 0.6),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      BibleTextField(
                        label: '',
                        hint: hint,
                        maxLines: 3,
                        initialValue: value,
                        onChanged: onChanged,
                        italic: true,
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
