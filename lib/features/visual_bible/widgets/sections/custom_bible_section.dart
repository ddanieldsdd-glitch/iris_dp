import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../visual_bible_model.dart';
import '../bible_form_widgets.dart';
import '../bible_navigation_scope.dart';
import '../bible_unified_references_panel.dart';
import '../narrative_bridge_card.dart';

/// Sección personalizada de la biblia (template freeform).
class CustomBibleSection extends StatefulWidget {
  final int projectId;
  final String sectionId;
  final String label;
  final String? contentJson;
  final ValueChanged<String?> onContentChanged;

  const CustomBibleSection({
    super.key,
    required this.projectId,
    required this.sectionId,
    required this.label,
    this.contentJson,
    required this.onContentChanged,
  });

  @override
  State<CustomBibleSection> createState() => _CustomBibleSectionState();
}

class _CustomBibleSectionState extends State<CustomBibleSection> {
  late TextEditingController _body;
  late TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    final parsed = _parse(widget.contentJson);
    _body = TextEditingController(text: parsed.$1);
    _notes = TextEditingController(text: parsed.$2);
  }

  @override
  void didUpdateWidget(CustomBibleSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contentJson != widget.contentJson) {
      final parsed = _parse(widget.contentJson);
      _body.text = parsed.$1;
      _notes.text = parsed.$2;
    }
  }

  (String, String) _parse(String? json) {
    if (json == null || json.isEmpty) return ('', '');
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map) {
        return (
          decoded['body']?.toString() ?? '',
          decoded['notes']?.toString() ?? '',
        );
      }
    } catch (_) {}
    return ('', '');
  }

  void _persist() {
    widget.onContentChanged(
      jsonEncode({
        'body': _body.text.trim(),
        'notes': _notes.text.trim(),
      }),
    );
  }

  @override
  void dispose() {
    _body.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        NarrativeBridgeCard(
          hint: 'Intención narrativa de «${widget.label}»…',
          value: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          onChanged: (v) {
            _notes.text = v;
            _persist();
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.label, style: AppTypography.titleMedium(palette)),
              const SizedBox(height: AppSpacing.md),
              BibleTextField(
                label: 'Contenido',
                hint: 'Notas, criterios, referencias escritas…',
                maxLines: 12,
                initialValue: _body.text,
                onChanged: (v) {
                  _body.text = v;
                  _persist();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        BibleReferencesPanel(
          projectId: widget.projectId,
          sectionId: widget.sectionId,
          onOpenMoodboard: () => BibleNavigationScope.openMoodboardForSection(
            context,
            widget.sectionId,
          ),
        ),
      ],
    );
  }
}
