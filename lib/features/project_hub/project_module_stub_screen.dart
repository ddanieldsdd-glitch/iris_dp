import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/feature_coming_soon_card.dart';

/// Pantalla placeholder para módulos planificados en fases futuras.
class ProjectModuleStubScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  final String description;
  final List<String>? plannedFeatures;

  const ProjectModuleStubScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.description,
    this.plannedFeatures,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: palette.surface,
        title: Text(title, style: AppTypography.titleMedium(palette)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          FeatureComingSoonCard(
            icon: icon,
            title: title,
            description: description,
            plannedFeatures: plannedFeatures,
          ),
        ],
      ),
    );
  }
}
