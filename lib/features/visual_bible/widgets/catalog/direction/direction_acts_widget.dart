import 'package:flutter/material.dart';

import '../../bible_dark_glass_panel.dart';
import '../shared/bible_catalog_chrome.dart';

class DirectionActItem {
  final String phase;
  final String title;
  final String body;

  const DirectionActItem({this.phase = '', this.title = '', this.body = ''});
}

/// Tres columnas de intención visual por acto. Solo Dirección.
class DirectionActsWidget extends StatelessWidget {
  final List<DirectionActItem> acts;

  const DirectionActsWidget({
    super.key,
    this.acts = const [
      DirectionActItem(phase: 'ACTO I', title: '', body: ''),
      DirectionActItem(phase: 'ACTO II', title: '', body: ''),
      DirectionActItem(phase: 'ACTO III', title: '', body: ''),
    ],
  });

  @override
  Widget build(BuildContext context) {
    return BibleDarkGlassPanel(
      borderRadius: 16,
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BibleCatalogTechLabel(
            label: 'Intención visual por acto',
            icon: Icons.timeline,
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final act in acts)
                SizedBox(width: 240, child: _ActColumn(act: act)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActColumn extends StatelessWidget {
  final DirectionActItem act;

  const _ActColumn({required this.act});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Color(0x4D2997FF), width: 4)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              act.phase.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                letterSpacing: 0.66,
                fontWeight: FontWeight.w700,
                color: BibleCatalogChrome.accent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              act.title.isEmpty ? 'Sin título' : act.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: BibleCatalogChrome.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              act.body.isEmpty ? 'Sin detalle' : act.body,
              style: const TextStyle(
                fontSize: 14,
                color: BibleCatalogChrome.onVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
