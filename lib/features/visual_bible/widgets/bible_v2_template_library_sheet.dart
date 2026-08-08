import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../v2/templates/bible_template_package.dart';
import '../v2/templates/bible_v2_builtin_templates.dart';

/// Biblioteca V2 con categorías y flujo preview (no aplicar al clic).
class BibleV2TemplateLibrarySheet extends StatelessWidget {
  final List<BibleTemplatePackage> packages;
  final bool examplesMode;
  final Future<void> Function(BibleTemplatePackage package) onPreview;

  const BibleV2TemplateLibrarySheet({
    super.key,
    required this.packages,
    required this.examplesMode,
    required this.onPreview,
  });

  static const categories = [
    'Todas',
    'Cinematográfica',
    'Técnica',
    'Editorial',
    'Comercial',
    'Documental',
    'Minimalista',
    'Mis plantillas',
  ];

  static Future<void> show(
    BuildContext context, {
    required List<BibleTemplatePackage> packages,
    required bool examplesMode,
    required Future<void> Function(BibleTemplatePackage package) onPreview,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.palette.surface,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.92,
      child: BibleV2TemplateLibrarySheet(
        packages: packages,
        examplesMode: examplesMode,
        onPreview: onPreview,
      ),
    ),
  );

  List<BibleTemplatePackage> _filtered(String category) {
    if (category == 'Todas') return packages;
    if (category == 'Mis plantillas') {
      return packages.where((p) => p.category == 'Mis plantillas').toList();
    }
    return packages.where((p) => p.category == category).toList();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DefaultTabController(
      length: categories.length,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          examplesMode
                              ? 'Explorar ejemplos'
                              : 'Biblioteca de plantillas',
                          style: AppTypography.titleLarge(palette),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          examplesMode
                              ? 'Contenido demo para inspirarte. Revisa antes de usar.'
                              : 'Selecciona una plantilla para previsualizarla.',
                          style: AppTypography.bodyMedium(palette).copyWith(
                            color: palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            TabBar(
              isScrollable: true,
              tabs: [for (final c in categories) Tab(text: c)],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  for (final category in categories)
                    _TemplateList(
                      packages: _filtered(category),
                      examplesMode: examplesMode,
                      onPreview: onPreview,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateList extends StatelessWidget {
  final List<BibleTemplatePackage> packages;
  final bool examplesMode;
  final Future<void> Function(BibleTemplatePackage package) onPreview;

  const _TemplateList({
    required this.packages,
    required this.examplesMode,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (packages.isEmpty) {
      return Center(
        child: Text(
          'No hay plantillas en esta categoría',
          style: AppTypography.bodyMedium(palette),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: packages.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, i) {
        final pack = packages[i];
        final doc = pack.document;
        final pageCount = doc?.pages.length ?? 0;
        final widgetCount = BibleV2BuiltinTemplates.widgetCount(pack);
        return Material(
          color: palette.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              Navigator.pop(context);
              await onPreview(pack);
            },
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 72,
                    height: 96,
                    decoration: BoxDecoration(
                      color: palette.surfaceOverlay,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: palette.border),
                    ),
                    child: Icon(
                      Icons.auto_stories_outlined,
                      color: palette.accent,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pack.name,
                          style: AppTypography.titleMedium(palette),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          pack.description,
                          style: AppTypography.bodyMedium(palette).copyWith(
                            color: palette.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            Text(
                              '$pageCount páginas',
                              style: AppTypography.caption(palette),
                            ),
                            Text(
                              pack.category,
                              style: AppTypography.caption(palette),
                            ),
                            Text(
                              '$widgetCount widgets',
                              style: AppTypography.caption(palette),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
