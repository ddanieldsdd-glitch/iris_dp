import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/feature_coming_soon_card.dart';

/// Agrupa tarjetas «próximamente» en un panel colapsable.
class ComingSoonExpansion extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const ComingSoonExpansion({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
        title: Text(title, style: AppTypography.label(palette)),
        subtitle: Text(
          '${children.length} funciones planificadas',
          style: AppTypography.caption(palette),
        ),
        iconColor: palette.textSecondary,
        collapsedIconColor: palette.textSecondary,
        children: children,
      ),
    );
  }
}

/// Tarjetas estándar de funciones avanzadas para localizaciones.
class LocationAdvancedComingSoon extends StatelessWidget {
  final bool includeSetFeatures;

  const LocationAdvancedComingSoon({
    super.key,
    this.includeSetFeatures = false,
  });

  @override
  Widget build(BuildContext context) {
    final siteCards = const [
      FeatureComingSoonCard(
        icon: Icons.map_outlined,
        title: 'Mapa y logística',
        description:
            'Geolocalización, accesos, parking y distancias entre sets.',
        plannedFeatures: [
          'Pin en mapa',
          'Notas de acceso y permisos',
          'Distancias entre puntos de rodaje',
        ],
      ),
      SizedBox(height: AppSpacing.sm),
      FeatureComingSoonCard(
        icon: Icons.wb_sunny_outlined,
        title: 'Orientación solar',
        description:
            'Notas generales de cómo entra la luz en la localización.',
        plannedFeatures: [
          'Rumbo del sol y horas útiles',
          'Referencias por franja horaria',
          'Simulación solar (fase avanzada)',
        ],
      ),
    ];

    final setCards = const [
      FeatureComingSoonCard(
        icon: Icons.view_in_ar_outlined,
        title: 'Modelo 3D',
        description: 'Representación volumétrica del set.',
        plannedFeatures: ['Importar glTF / USDZ'],
      ),
      SizedBox(height: AppSpacing.sm),
      FeatureComingSoonCard(
        icon: Icons.wb_sunny_outlined,
        title: 'Estudio de luz',
        description: 'Referencias de luz por franja horaria.',
        plannedFeatures: ['Galería DÍA / NOCHE / ATARDECER'],
      ),
    ];

    return ComingSoonExpansion(
      title: 'Funciones avanzadas',
      children: [
        ...siteCards,
        if (includeSetFeatures) ...[
          const SizedBox(height: AppSpacing.sm),
          ...setCards,
        ],
      ],
    );
  }
}
