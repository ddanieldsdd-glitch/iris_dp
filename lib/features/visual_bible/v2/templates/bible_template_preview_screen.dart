import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../bible_block_catalog.dart';
import '../commands/bible_document_history.dart';
import '../editor/bible_canvas_editor.dart';
import '../model/bible_document.dart';
import '../templates/bible_template_package.dart';
import '../templates/bible_v2_builtin_templates.dart';

/// Vista previa de plantilla antes de aplicar (solo lectura).
class BibleTemplatePreviewScreen extends StatelessWidget {
  final BibleTemplatePackage package;
  final bool isExample;
  final Future<void> Function() onUse;

  const BibleTemplatePreviewScreen({
    super.key,
    required this.package,
    required this.isExample,
    required this.onUse,
  });

  static Future<bool?> push(
    BuildContext context, {
    required BibleTemplatePackage package,
    required bool isExample,
    required Future<void> Function() onUse,
  }) => Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => BibleTemplatePreviewScreen(
        package: package,
        isExample: isExample,
        onUse: onUse,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final doc = package.document;
    if (doc == null) {
      return Scaffold(
        appBar: AppBar(title: Text(package.name)),
        body: const Center(child: Text('Plantilla sin documento V2')),
      );
    }

    final pageCount = doc.pages.length;
    final widgetCount = BibleV2BuiltinTemplates.widgetCount(package);
    final types = BibleV2BuiltinTemplates.widgetTypes(package);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(package.name),
        actions: [
          FilledButton(
            onPressed: () async {
              await onUse();
              if (context.mounted) Navigator.pop(context, true);
            },
            child: Text(isExample ? 'Usar este ejemplo' : 'Usar esta plantilla'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(package.description, style: AppTypography.bodyMedium(palette)),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetaChip(label: '$pageCount páginas'),
                    _MetaChip(label: package.category),
                    _MetaChip(label: '$widgetCount widgets'),
                    if (package.theme != null)
                      _MetaChip(label: package.theme!.name),
                    _MetaChip(label: 'v${package.version}'),
                    if (package.author.isNotEmpty)
                      _MetaChip(label: package.author),
                  ],
                ),
                if (types.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    types.map((t) => t.label).join(' · '),
                    style: AppTypography.caption(palette),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: BibleCanvasEditor(
              document: doc,
              history: BibleDocumentHistory(doc),
              previewMode: true,
              onDocumentChanged: (_) {},
              initialPageId: doc.pages.isNotEmpty ? doc.pages.first.id : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;

  const _MetaChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: palette.surfaceOverlay,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Text(label, style: AppTypography.caption(palette)),
    );
  }
}
