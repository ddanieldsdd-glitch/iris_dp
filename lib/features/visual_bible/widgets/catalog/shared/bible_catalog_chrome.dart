import 'package:flutter/material.dart';

/// Tokens visuales locales del catálogo (look IRIS / Stitch).
abstract final class BibleCatalogChrome {
  static const accent = Color(0xFF2997FF);
  static const onSurface = Color(0xFFE4E2E4);
  static const onVariant = Color(0xFFC0C7D5);
  static const error = Color(0xFFFFB4AB);
}

class BibleCatalogTechLabel extends StatelessWidget {
  final String label;
  final IconData? icon;

  const BibleCatalogTechLabel({super.key, required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: BibleCatalogChrome.accent),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              letterSpacing: 0.66,
              fontWeight: FontWeight.w700,
              color: BibleCatalogChrome.accent,
            ),
          ),
        ),
      ],
    );
  }
}
