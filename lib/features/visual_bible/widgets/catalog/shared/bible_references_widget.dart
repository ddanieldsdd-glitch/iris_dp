import 'dart:io';

import 'package:flutter/material.dart';

import '../../bible_dark_glass_panel.dart';
import 'bible_catalog_chrome.dart';

enum ReferencesWidgetMode { narrative, lighting, technical }

class BibleReferenceItem {
  final int? moodboardImageId;
  final String? path;
  final String title;
  final String body;
  final String refLabel;
  final List<Map<String, String>> specs;

  const BibleReferenceItem({
    this.moodboardImageId,
    this.path,
    this.title = '',
    this.body = '',
    this.refLabel = '',
    this.specs = const [],
  });

  factory BibleReferenceItem.fromJson(Map<String, dynamic> json) {
    final specsRaw = json['specs'];
    return BibleReferenceItem(
      moodboardImageId: json['moodboardImageId'] is int
          ? json['moodboardImageId'] as int
          : int.tryParse('${json['moodboardImageId'] ?? ''}'),
      path: json['path']?.toString(),
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      refLabel: json['refLabel']?.toString() ?? '',
      specs: [
        if (specsRaw is List)
          for (final spec in specsRaw)
            if (spec is Map)
              {
                'label': spec['label']?.toString() ?? '',
                'value': spec['value']?.toString() ?? '',
              },
      ],
    );
  }
}

/// Referencias compartidas. En Dirección usa [ReferencesWidgetMode.narrative].
class BibleReferencesWidget extends StatelessWidget {
  final String title;
  final ReferencesWidgetMode mode;
  final List<BibleReferenceItem> items;
  final ValueChanged<BibleReferenceItem>? onOpenItem;

  const BibleReferencesWidget({
    super.key,
    this.title = 'Referencias',
    this.mode = ReferencesWidgetMode.narrative,
    this.items = const [],
    this.onOpenItem,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      key: ValueKey(mode.name),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BibleCatalogTechLabel(label: title, icon: Icons.collections_outlined),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final item in items)
              SizedBox(
                width: 360,
                child: _ReferenceCard(
                  item: item,
                  onTap: onOpenItem == null ? null : () => onOpenItem!(item),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ReferenceCard extends StatelessWidget {
  final BibleReferenceItem item;
  final VoidCallback? onTap;

  const _ReferenceCard({required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final file = item.path != null && item.path!.isNotEmpty
        ? File(item.path!)
        : null;
    return BibleDarkGlassPanel(
      borderRadius: 16,
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 160,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (file != null && file.existsSync())
                    Image.file(file, fit: BoxFit.cover)
                  else
                    const ColoredBox(color: Color(0xFF1F1F21)),
                  if (item.refLabel.isNotEmpty)
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xCC131315),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Text(
                          item.refLabel.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            letterSpacing: 0.3,
                            color: BibleCatalogChrome.onSurface,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title.isEmpty ? 'Referencia' : item.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: BibleCatalogChrome.onSurface,
                    ),
                  ),
                  if (item.body.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      item.body,
                      style: const TextStyle(
                        fontSize: 14,
                        color: BibleCatalogChrome.onVariant,
                      ),
                    ),
                  ],
                  if (item.specs.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        for (final spec in item.specs) ...[
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (spec['label'] ?? '').toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  letterSpacing: 0.66,
                                  color: BibleCatalogChrome.accent,
                                ),
                              ),
                              Text(
                                spec['value'] ?? '',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: BibleCatalogChrome.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
