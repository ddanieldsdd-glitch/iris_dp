import 'package:flutter/material.dart';

import '../../bible_dark_glass_panel.dart';
import 'bible_catalog_chrome.dart';

/// Texto largo + chips. Nace en Dirección (intención); reutilizable.
class BibleTaggedTextWidget extends StatelessWidget {
  final String title;
  final String text;
  final List<String> tags;

  const BibleTaggedTextWidget({
    super.key,
    this.title = 'Intención narrativa',
    this.text = '',
    this.tags = const [],
  });

  static const dangerTags = {
    'TENSION',
    'TENSIÓN',
    'PELIGRO',
    'CLAUSTROPHOBIA',
    'CLAUSTROFOBIA',
  };

  @override
  Widget build(BuildContext context) {
    return BibleDarkGlassPanel(
      borderRadius: 16,
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BibleCatalogTechLabel(label: title, icon: Icons.psychology_outlined),
          const SizedBox(height: 16),
          Text(
            text.isEmpty ? 'Añade la intención narrativa…' : text,
            style: TextStyle(
              fontSize: 18,
              height: 28 / 18,
              color: BibleCatalogChrome.onSurface.withValues(alpha: 0.9),
            ),
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in tags)
                  _TagChip(
                    label: tag,
                    danger: dangerTags.contains(tag.toUpperCase()),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final bool danger;

  const _TagChip({required this.label, required this.danger});

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? BibleCatalogChrome.error
        : BibleCatalogChrome.onVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        color: color.withValues(alpha: 0.12),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          letterSpacing: 0.4,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}
