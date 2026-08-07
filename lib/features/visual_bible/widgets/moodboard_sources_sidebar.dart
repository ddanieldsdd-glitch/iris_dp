import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

enum MoodboardSourceKind {
  irisLibrary,
  personalLibrary,
  localFolder,
  shotDeck,
  filmGrab,
  tmdb,
  imdb,
}

class MoodboardSourceItem {
  final MoodboardSourceKind kind;
  final String label;
  final IconData icon;
  final String? badge;
  final bool enabled;

  const MoodboardSourceItem({
    required this.kind,
    required this.label,
    required this.icon,
    this.badge,
    this.enabled = true,
  });
}

const kMoodboardSources = <MoodboardSourceItem>[
  MoodboardSourceItem(
    kind: MoodboardSourceKind.irisLibrary,
    label: 'Biblioteca IRIS',
    icon: Icons.photo_library_outlined,
  ),
  MoodboardSourceItem(
    kind: MoodboardSourceKind.shotDeck,
    label: 'ShotDeck',
    icon: Icons.movie_outlined,
    badge: 'FUTURE',
    enabled: false,
  ),
  MoodboardSourceItem(
    kind: MoodboardSourceKind.filmGrab,
    label: 'FilmGrab',
    icon: Icons.camera_roll_outlined,
    badge: 'FUTURE',
    enabled: false,
  ),
  MoodboardSourceItem(
    kind: MoodboardSourceKind.tmdb,
    label: 'TMDb',
    icon: Icons.theaters_outlined,
    badge: 'SOON',
    enabled: false,
  ),
  MoodboardSourceItem(
    kind: MoodboardSourceKind.imdb,
    label: 'IMDb',
    icon: Icons.local_movies_outlined,
    badge: 'SOON',
    enabled: false,
  ),
  MoodboardSourceItem(
    kind: MoodboardSourceKind.personalLibrary,
    label: 'Biblioteca personal',
    icon: Icons.folder_shared_outlined,
  ),
  MoodboardSourceItem(
    kind: MoodboardSourceKind.localFolder,
    label: 'Carpeta local',
    icon: Icons.folder_outlined,
  ),
];

/// Sidebar "Visual Sources" del HTML Stitch.
class MoodboardSourcesSidebar extends StatelessWidget {
  final MoodboardSourceKind active;
  final ValueChanged<MoodboardSourceKind> onSelect;

  const MoodboardSourcesSidebar({
    super.key,
    required this.active,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: const Color(0xB31A1A1C),
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Text(
              'Visual Sources',
              style: AppTypography.titleMedium(palette),
            ),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (final item in kMoodboardSources) ...[
                  if (item.kind == MoodboardSourceKind.shotDeck)
                    _SectionLabel(text: 'Integrations', palette: palette),
                  if (item.kind == MoodboardSourceKind.personalLibrary)
                    _SectionLabel(text: 'Local', palette: palette),
                  _SourceRow(
                    item: item,
                    selected: active == item.kind,
                    onTap: item.enabled
                        ? () => onSelect(item.kind)
                        : null,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final AppPalette palette;

  const _SectionLabel({required this.text, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 6),
      child: Text(
        text.toUpperCase(),
        style: AppTypography.label(palette).copyWith(
          color: palette.textTertiary,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  final MoodboardSourceItem item;
  final bool selected;
  final VoidCallback? onTap;

  const _SourceRow({
    required this.item,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final muted = onTap == null;
    return Opacity(
      opacity: muted ? 0.5 : 1,
      child: Material(
        color: selected ? palette.surfaceOverlay : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 18,
                  color: selected ? palette.textPrimary : palette.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.label,
                    style: AppTypography.caption(palette).copyWith(
                      color:
                          selected ? palette.textPrimary : palette.textSecondary,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (item.badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: palette.surfaceElevated,
                      borderRadius: BorderRadius.circular(4),
                      border: item.badge == 'SOON'
                          ? Border.all(
                              color: palette.textTertiary.withValues(alpha: 0.35),
                            )
                          : null,
                    ),
                    child: Text(
                      item.badge!,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                        color: selected ? palette.accent : palette.textTertiary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Chips de faceta de catálogo (lugar / momento / look).
enum MoodboardFacet {
  interior,
  exterior,
  day,
  night,
  cool,
  warm,
}

extension MoodboardFacetX on MoodboardFacet {
  String get label => switch (this) {
        MoodboardFacet.interior => 'Interior',
        MoodboardFacet.exterior => 'Exterior',
        MoodboardFacet.day => 'Día',
        MoodboardFacet.night => 'Noche',
        MoodboardFacet.cool => 'Frío',
        MoodboardFacet.warm => 'Cálido',
      };
}

class MoodboardFacetChips extends StatelessWidget {
  final MoodboardFacet? active;
  final ValueChanged<MoodboardFacet?> onSelect;

  const MoodboardFacetChips({
    super.key,
    required this.active,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final f in MoodboardFacet.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(f.label),
                selected: active == f,
                onSelected: (v) => onSelect(v ? f : null),
                labelStyle: AppTypography.caption(palette).copyWith(
                  color: active == f ? palette.textPrimary : palette.textSecondary,
                ),
                selectedColor: palette.surfaceOverlay,
                backgroundColor: Colors.transparent,
                side: BorderSide(
                  color: active == f
                      ? palette.accent.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.1),
                ),
                visualDensity: VisualDensity.compact,
                showCheckmark: false,
              ),
            ),
        ],
      ),
    );
  }
}
