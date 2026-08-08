import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../bible_section_fields.dart';
import '../../v2/migration/freeform_v2_blocks_codec.dart';
import '../../v2/theme/bible_theme.dart';
import '../../v2/widgets/bible_block_compositor.dart';
import '../bible_form_widgets.dart';
import '../bible_navigation_scope.dart';
import '../bible_unified_references_panel.dart';
import '../block_reference_images.dart';
import '../narrative_bridge_card.dart';

/// Sección personalizada con sub-apartados configurables (texto, imágenes…).
/// Si `contentJson` contiene `v2Blocks`, usa el compositor modular.
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
  late Map<String, String> _values;
  late List<BibleSectionField> _fields;

  static String _imagesKey(String fieldKey) => '${fieldKey}__images';

  @override
  void initState() {
    super.initState();
    _reloadFromJson();
  }

  @override
  void didUpdateWidget(CustomBibleSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contentJson != widget.contentJson) {
      _reloadFromJson();
    }
  }

  void _reloadFromJson() {
    _fields = BibleSectionFieldsConfig.parse(
      widget.contentJson,
      widget.sectionId,
    );
    _values = BibleSectionFieldsConfig.parseValues(widget.contentJson);
    final legacy = _parseLegacy(widget.contentJson);
    if (legacy.$1.isNotEmpty && !_values.containsKey('body')) {
      _values['body'] = legacy.$1;
    }
    if (legacy.$2.isNotEmpty && !_values.containsKey('narrative')) {
      _values['narrative'] = legacy.$2;
    }
  }

  (String, String) _parseLegacy(String? json) {
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
      BibleSectionFieldsConfig.encode(_fields, values: _values),
    );
  }

  void _setValue(String key, String? value) {
    setState(() {
      if (value == null || value.trim().isEmpty) {
        _values.remove(key);
      } else {
        _values[key] = value.trim();
      }
    });
    _persist();
  }

  List<String> _imagesFor(String fieldKey) {
    final raw = _values[_imagesKey(fieldKey)];
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<String>().toList();
      }
    } catch (_) {}
    return const [];
  }

  void _setImages(String fieldKey, List<String> paths) {
    setState(() {
      if (paths.isEmpty) {
        _values.remove(_imagesKey(fieldKey));
      } else {
        _values[_imagesKey(fieldKey)] = jsonEncode(paths);
      }
    });
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    final v2Blocks = FreeformV2BlocksCodec.parseBlocks(widget.contentJson);
    if (v2Blocks.isNotEmpty) {
      final palette = context.palette;
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            'PANTALLA PERSONALIZADA',
            style: AppTypography.mono(palette).copyWith(
              fontSize: 11,
              letterSpacing: 1.2,
              color: palette.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.label,
            style: AppTypography.titleLarge(palette).copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Layout modular con hero, referencias e intención narrativa.',
            style: AppTypography.bodyMedium(palette).copyWith(
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          BibleBlockCompositor(
            blocks: v2Blocks,
            theme: BibleThemePresets.cinematic,
            projectId: widget.projectId,
            editing: true,
            onBlockChanged: (block) {
              final next = [
                for (final b in v2Blocks) b.id == block.id ? block : b,
              ];
              widget.onContentChanged(
                FreeformV2BlocksCodec.mergeBlocksIntoContentJson(
                  widget.contentJson,
                  next,
                ),
              );
            },
          ),
        ],
      );
    }

    final items = <Widget>[];
    for (final field in _fields) {
      final built = _buildField(field);
      if (built != null) {
        if (items.isNotEmpty) items.add(const SizedBox(height: AppSpacing.lg));
        items.add(built);
      }
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: items,
    );
  }

  Widget? _buildField(BibleSectionField field) {
    return switch (field.type) {
      BibleSectionFieldType.narrative => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NarrativeBridgeCard(
            title: field.label,
            hint: field.hint ?? 'Intención narrativa de «${widget.label}»…',
            value: _values[field.key],
            onChanged: (v) => _setValue(field.key, v),
          ),
          const SizedBox(height: 8),
          _imageAttachRow(field.key),
        ],
      ),
      BibleSectionFieldType.references ||
      BibleSectionFieldType.image => BibleReferencesPanel(
        projectId: widget.projectId,
        sectionId: widget.sectionId,
        title: field.label,
        onOpenMoodboard: () => BibleNavigationScope.openMoodboardForSection(
          context,
          widget.sectionId,
        ),
      ),
      BibleSectionFieldType.blocks => null,
      BibleSectionFieldType.text => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BibleTextField(
            label: field.label,
            hint: field.hint ?? '',
            maxLines: field.maxLines,
            initialValue: _values[field.key] ?? '',
            onChanged: (v) => _setValue(field.key, v),
          ),
          const SizedBox(height: 8),
          _imageAttachRow(field.key),
        ],
      ),
    };
  }

  Widget _imageAttachRow(String fieldKey) {
    final paths = _imagesFor(fieldKey);
    return blockReferenceImagesRow(
      projectId: widget.projectId,
      paths: paths,
      onAdd: () => pickBlockReferenceImage(
        projectId: widget.projectId,
        onSaved: (path) => _setImages(fieldKey, [...paths, path]),
      ),
      onSaved: (path) async => _setImages(fieldKey, [...paths, path]),
    );
  }
}
