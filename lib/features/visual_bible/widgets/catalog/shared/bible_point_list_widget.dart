import 'package:flutter/material.dart';

import '../../bible_dark_glass_panel.dart';
import 'bible_catalog_chrome.dart';

/// Lista título + cuerpo (tono, transiciones).
class BiblePointListWidget extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Map<String, String>> points;
  final VoidCallback? onAddPoint;

  const BiblePointListWidget({
    super.key,
    this.title = 'Tono y atmósfera',
    this.icon = Icons.blur_on,
    this.points = const [],
    this.onAddPoint,
  });

  @override
  Widget build(BuildContext context) {
    return BibleDarkGlassPanel(
      borderRadius: 16,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BibleCatalogTechLabel(label: title, icon: icon),
          const SizedBox(height: 16),
          for (var i = 0; i < points.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _PointRow(
              title: points[i]['title'] ?? '',
              body: points[i]['body'] ?? '',
            ),
          ],
          if (onAddPoint != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onAddPoint,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('AÑADIR PUNTO'),
            ),
          ],
        ],
      ),
    );
  }
}

class _PointRow extends StatelessWidget {
  final String title;
  final String body;

  const _PointRow({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.isEmpty ? 'Sin título' : title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: BibleCatalogChrome.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body.isEmpty ? 'Sin detalle' : body,
            style: const TextStyle(
              fontSize: 13,
              color: BibleCatalogChrome.onVariant,
            ),
          ),
        ],
      ),
    );
  }
}
