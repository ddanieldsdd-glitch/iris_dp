import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../bible_blueprint.dart';
import '../../bible_section_style_store.dart';
import '../../visual_bible_model.dart';
import '../bible_navigation_scope.dart';
import '../bible_section_shared_widgets.dart';
import '../bible_unified_references_panel.dart';
import '../narrative_bridge_card.dart';
import '../../../../shared/visual_bible/bible_stitch_module_registry.dart';
import '../../bible_section_fields.dart';
import '../bible_form_widgets.dart';

/// Layout común para secciones técnicas de la biblia.
///
/// Cuando se proporciona [fieldWidgets], los sub-apartados se renderizan
/// según el orden y nombres definidos en [sectionContentJson].
/// El estilo (Cinematic / Technical / Minimalist) se lee y persiste en
/// [BibleSectionStyleStore].
class BibleSectionScaffold extends StatefulWidget {
  final String sectionId;
  final int projectId;
  final VisualBibleData data;
  final BibleChanged onChanged;
  final String narrativeHint;
  final String? sectionContentJson;
  final Map<String, Widget> fieldWidgets;
  final String? sectionNumber;
  final String? sectionTitle;

  const BibleSectionScaffold({
    super.key,
    required this.sectionId,
    required this.projectId,
    required this.data,
    required this.onChanged,
    required this.narrativeHint,
    this.sectionContentJson,
    required this.fieldWidgets,
    this.sectionNumber,
    this.sectionTitle,
  });

  @override
  State<BibleSectionScaffold> createState() => _BibleSectionScaffoldState();
}

class _BibleSectionScaffoldState extends State<BibleSectionScaffold> {
  BibleVisualMode _mode = BibleVisualMode.cinematic;
  bool _styleLoaded = false;

  @override
  void initState() {
    super.initState();
    BibleSectionStyleStore.revision.addListener(_loadStyle);
    _loadStyle();
  }

  @override
  void dispose() {
    BibleSectionStyleStore.revision.removeListener(_loadStyle);
    super.dispose();
  }

  @override
  void didUpdateWidget(BibleSectionScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sectionId != widget.sectionId ||
        oldWidget.projectId != widget.projectId) {
      _loadStyle();
    }
  }

  Future<void> _loadStyle() async {
    final style = await BibleSectionStyleStore.load(
      widget.projectId,
      widget.sectionId,
    );
    if (!mounted) return;
    setState(() {
      _mode = _fromStyle(style);
      _styleLoaded = true;
    });
  }

  BibleVisualMode _fromStyle(BibleSectionStyle style) => switch (style) {
        BibleSectionStyle.cinematic => BibleVisualMode.cinematic,
        BibleSectionStyle.technical => BibleVisualMode.technical,
        BibleSectionStyle.minimalist => BibleVisualMode.minimalist,
      };

  BibleSectionStyle _toStyle(BibleVisualMode mode) => switch (mode) {
        BibleVisualMode.cinematic => BibleSectionStyle.cinematic,
        BibleVisualMode.technical => BibleSectionStyle.technical,
        BibleVisualMode.minimalist => BibleSectionStyle.minimalist,
      };

  Future<void> _onModeChanged(BibleVisualMode mode) async {
    setState(() => _mode = mode);
    await BibleSectionStyleStore.save(
      widget.projectId,
      widget.sectionId,
      _toStyle(mode),
    );
  }

  EdgeInsets get _contentPadding => switch (_mode) {
        BibleVisualMode.minimalist => const EdgeInsets.all(AppSpacing.md),
        BibleVisualMode.technical => const EdgeInsets.all(AppSpacing.lg),
        BibleVisualMode.cinematic => const EdgeInsets.all(AppSpacing.lg),
      };

  double get _sectionGap => switch (_mode) {
        BibleVisualMode.minimalist => AppSpacing.md,
        BibleVisualMode.technical => AppSpacing.lg,
        BibleVisualMode.cinematic => AppSpacing.xl,
      };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final fields = BibleSectionFieldsConfig.parse(
      widget.sectionContentJson,
      widget.sectionId,
    );

    final items = <Widget>[];
    for (final field in fields) {
      final w = _buildField(context, field);
      if (w != null) items.add(w);
    }

    final density = switch (_mode) {
      BibleVisualMode.technical => 0.92,
      BibleVisualMode.minimalist => 0.88,
      BibleVisualMode.cinematic => 1.0,
    };

    return AnimatedOpacity(
      opacity: _styleLoaded ? 1 : 0.85,
      duration: const Duration(milliseconds: 180),
      child: ListView(
        padding: _contentPadding,
        children: [
          if (widget.sectionNumber != null)
            BibleSectionHeader(
              number: widget.sectionNumber!,
              title:
                  widget.sectionTitle ?? BibleSectionId.label(widget.sectionId),
              trailing: BibleSectionModeDropdown(
                value: _mode,
                onChanged: _onModeChanged,
              ),
            ),
          if (_mode == BibleVisualMode.technical)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                'MODO TÉCNICO · valores mono · densidad alta',
                style: AppTypography.mono(palette).copyWith(
                      fontSize: 10,
                      color: palette.accent,
                      letterSpacing: 0.6,
                    ),
              ),
            ),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) SizedBox(height: _sectionGap * density),
            items[i],
          ],
        ],
      ),
    );
  }

  Widget? _buildField(BuildContext context, BibleSectionField field) {
    final override = widget.fieldWidgets[field.key];
    if (override != null) return override;

    return switch (field.type) {
      BibleSectionFieldType.narrative => NarrativeBridgeCard(
          title: field.label,
          hint: field.hint ?? widget.narrativeHint,
          subtitle: null,
          value: widget.data.narrativeIntentForSection(widget.sectionId),
          onChanged: (v) {
            widget.data.setNarrativeIntentForSection(
              widget.sectionId,
              v.trim().isEmpty ? null : v.trim(),
            );
            widget.onChanged(widget.data);
          },
        ),
      BibleSectionFieldType.references ||
      BibleSectionFieldType.image =>
        widget.data.id > 0
            ? BibleReferencesPanel(
                projectId: widget.projectId,
                sectionId: widget.sectionId,
                bibleId: widget.data.id,
                title: field.label,
                onOpenMoodboard: () =>
                    BibleNavigationScope.openMoodboardForSection(
                  context,
                  widget.sectionId,
                ),
              )
            : null,
      BibleSectionFieldType.text => BibleTextField(
          label: field.label,
          hint: field.hint ?? 'Notas orientativas…',
          maxLines: field.maxLines,
          initialValue: BibleSectionFieldsConfig.parseValues(
            widget.sectionContentJson,
          )[field.key] ??
              '',
          onChanged: (_) {},
        ),
      BibleSectionFieldType.blocks => _MissingModulePlaceholder(
          sectionId: widget.sectionId,
          fieldKey: field.key,
          label: field.label,
        ),
    };
  }
}

class _MissingModulePlaceholder extends StatelessWidget {
  final String sectionId;
  final String fieldKey;
  final String label;

  const _MissingModulePlaceholder({
    required this.sectionId,
    required this.fieldKey,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final known = BibleStitchModuleRegistry.module(sectionId, fieldKey) != null;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Icon(
            known ? Icons.hourglass_empty : Icons.help_outline,
            color: palette.textTertiary,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              known
                  ? '$label — renderer Stitch pendiente de conectar'
                  : '$label — módulo personalizado sin vista dedicada',
              style: AppTypography.caption(palette),
            ),
          ),
        ],
      ),
    );
  }
}
