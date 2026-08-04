import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../moodboard_association.dart';
import 'bible_form_widgets.dart';

/// Selector de pantallas de la biblia donde debe aparecer una ref del moodboard.
class MoodboardSectionAssignField extends StatelessWidget {
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  const MoodboardSectionAssignField({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pantallas de la biblia',
          style: AppTypography.label(palette),
        ),
        const SizedBox(height: 4),
        Text(
          'Elige las pantallas donde debe aparecer esta referencia.',
          style: AppTypography.caption(palette),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: MoodboardAssociation.assignableSections().map((sectionId) {
            final isOn = selected.contains(sectionId);
            return FilterChip(
              label: Text(MoodboardAssociation.sectionLabel(sectionId)),
              selected: isOn,
              onSelected: (on) {
                final next = List<String>.from(selected);
                if (on) {
                  if (!next.contains(sectionId)) next.add(sectionId);
                } else {
                  next.remove(sectionId);
                }
                onChanged(next);
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Selector de set/localización (site → set) para refs en Localización.
class MoodboardLocationAssignField extends StatelessWidget {
  final List<LocationSite> sites;
  final List<LocationBasePlan> sets;
  final int? selectedPlanId;
  final ValueChanged<LocationBasePlan?> onChanged;

  const MoodboardLocationAssignField({
    super.key,
    required this.sites,
    required this.sets,
    required this.selectedPlanId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (sets.isEmpty) {
      return Text(
        'Importa el guion para vincular refs a sets concretos.',
        style: AppTypography.caption(context.palette),
      );
    }

    final options = <String>['— Sin set concreto —'];
    final planByLabel = <String, LocationBasePlan>{};

    for (final site in sites) {
      for (final set in sets.where((s) => s.siteId == site.id)) {
        final label = '${site.name} · ${set.locationName}';
        options.add(label);
        planByLabel[label] = set;
      }
    }
    for (final set in sets.where((s) => s.siteId == null)) {
      options.add(set.locationName);
      planByLabel[set.locationName] = set;
    }

    String selectedLabel = options.first;
    if (selectedPlanId != null) {
      for (final entry in planByLabel.entries) {
        if (entry.value.id == selectedPlanId) {
          selectedLabel = entry.key;
          break;
        }
      }
    }

    return BibleDropdown(
      label: 'Set / localización',
      options: options,
      value: selectedLabel,
      onChanged: (v) {
        if (v == null || v == options.first) {
          onChanged(null);
        } else {
          onChanged(planByLabel[v]);
        }
      },
    );
  }
}

/// Selector de sub-grupo dentro de una categoría del moodboard.
class MoodboardGroupAssignField extends StatelessWidget {
  final List<MoodboardGroup> groups;
  final int? selectedGroupId;
  final ValueChanged<int?> onChanged;

  const MoodboardGroupAssignField({
    super.key,
    required this.groups,
    required this.selectedGroupId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final options = ['— Sin grupo —', ...groups.map((g) => g.name)];
    final selectedName = selectedGroupId == null
        ? options.first
        : groups
            .where((g) => g.id == selectedGroupId)
            .map((g) => g.name)
            .firstOrNull ?? options.first;

    return BibleDropdown(
      label: 'Sub-grupo',
      options: options,
      value: selectedName,
      onChanged: (v) {
        if (v == null || v == options.first) {
          onChanged(null);
          return;
        }
        final group = groups.where((g) => g.name == v).firstOrNull;
        onChanged(group?.id);
      },
    );
  }
}

/// Chips resumen en tarjetas del moodboard.
class MoodboardAssignmentBadges extends StatelessWidget {
  final List<String> assignedSections;
  final String? linkedLocationName;

  const MoodboardAssignmentBadges({
    super.key,
    this.assignedSections = const [],
    this.linkedLocationName,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final labels = <String>[];

    if (assignedSections.isNotEmpty) {
      labels.addAll(
        assignedSections.map(MoodboardAssociation.sectionLabel),
      );
    }
    if (linkedLocationName != null && linkedLocationName!.isNotEmpty) {
      labels.add(linkedLocationName!);
    }

    if (labels.isEmpty) {
      return Text(
        'Sin clasificar',
        style: AppTypography.caption(palette).copyWith(
          color: Colors.white54,
          fontSize: 10,
        ),
      );
    }

    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: labels.take(4).map((label) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black45,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: AppTypography.caption(palette).copyWith(
              color: Colors.white70,
              fontSize: 9,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
    );
  }
}
