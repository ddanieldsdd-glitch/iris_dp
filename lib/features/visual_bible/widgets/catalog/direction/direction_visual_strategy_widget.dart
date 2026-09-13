import 'package:flutter/material.dart';

import '../../bible_dark_glass_panel.dart';
import '../shared/bible_catalog_chrome.dart';

class DirectionStrategyPillar {
  final String id;
  final String title;
  final String body;
  final IconData icon;

  const DirectionStrategyPillar({
    required this.id,
    required this.title,
    this.body = '',
    this.icon = Icons.auto_awesome_outlined,
  });
}

/// Pilares Cámara / Blocking / POV + extras. Solo Dirección.
class DirectionVisualStrategyWidget extends StatelessWidget {
  final List<DirectionStrategyPillar> pillars;
  final VoidCallback? onAddStrategy;

  const DirectionVisualStrategyWidget({
    super.key,
    this.pillars = const [
      DirectionStrategyPillar(
        id: 'camera',
        title: 'Cámara',
        icon: Icons.videocam_outlined,
      ),
      DirectionStrategyPillar(
        id: 'blocking',
        title: 'Blocking',
        icon: Icons.person_pin_outlined,
      ),
      DirectionStrategyPillar(
        id: 'pov',
        title: 'POV',
        icon: Icons.center_focus_strong,
      ),
    ],
    this.onAddStrategy,
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
            label: 'Estrategia visual',
            icon: Icons.visibility_outlined,
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final pillar in pillars)
                SizedBox(width: 220, child: _Pillar(pillar: pillar)),
              if (onAddStrategy != null)
                TextButton.icon(
                  onPressed: onAddStrategy,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('AÑADIR ESTRATEGIA'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pillar extends StatelessWidget {
  final DirectionStrategyPillar pillar;

  const _Pillar({required this.pillar});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: Color(0xFF2A2A2C),
            shape: BoxShape.circle,
          ),
          child: Icon(pillar.icon, color: BibleCatalogChrome.accent, size: 20),
        ),
        const SizedBox(height: 12),
        Text(
          pillar.title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: BibleCatalogChrome.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          pillar.body.isEmpty ? 'Sin estrategia' : pillar.body,
          style: const TextStyle(
            fontSize: 14,
            height: 1.4,
            color: BibleCatalogChrome.onVariant,
          ),
        ),
      ],
    );
  }
}
