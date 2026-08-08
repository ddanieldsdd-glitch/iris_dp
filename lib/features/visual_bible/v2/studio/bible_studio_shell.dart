import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// Shell de Bible Studio (Fase 8) — no reemplaza Master Config todavía.
class BibleStudioShell extends StatelessWidget {
  final int projectId;
  final int bibleId;
  final int initialTab;

  const BibleStudioShell({
    super.key,
    required this.projectId,
    required this.bibleId,
    this.initialTab = 0,
  });

  static const tabs = [
    'Estructura',
    'Diseño',
    'Widgets',
    'Tema',
    'Plantillas',
    'Navegación',
    'Exportación',
    'Avanzado',
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DefaultTabController(
      length: tabs.length,
      initialIndex: initialTab.clamp(0, tabs.length - 1),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'BIBLE STUDIO',
            style: AppTypography.titleMedium(palette),
          ),
          bottom: TabBar(
            isScrollable: true,
            tabs: [for (final t in tabs) Tab(text: t)],
          ),
        ),
        body: TabBarView(
          children: [
            for (var i = 0; i < tabs.length; i++)
              _StudioPane(
                title: '0${i + 1} ${tabs[i].toUpperCase()}',
                body:
                    'Módulo preparado. Master Config legacy sigue activo hasta cutover.',
              ),
          ],
        ),
      ),
    );
  }
}

class _StudioPane extends StatelessWidget {
  final String title;
  final String body;

  const _StudioPane({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.titleLarge(palette)),
          const SizedBox(height: 12),
          Text(body, style: AppTypography.bodyMedium(palette)),
        ],
      ),
    );
  }
}
