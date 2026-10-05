import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../visual_bible_model.dart';
import '../bible_navigation_scope.dart';
import '../bible_section_shared_widgets.dart';
import '../bible_unified_references_panel.dart';
import '../narrative_bridge_card.dart';
import '../../../../shared/visual_bible/bible_acts.dart';
import '../../../../shared/visual_bible/bible_cards.dart';
import '../../../../shared/visual_bible/bible_point_extras.dart';
import '../../../../shared/visual_bible/bible_stitch_module_registry.dart';
import '../../bible_section_fields.dart';
import '../bible_add_point.dart';
import '../bible_point_frame.dart';
import '../catalog/bible_widget_catalog.dart';

/// Layout común para secciones técnicas de la biblia.
///
/// Cuando se proporciona [fieldWidgets], los sub-apartados se renderizan
/// según el orden y nombres definidos en [sectionContentJson].
class BibleSectionScaffold extends ConsumerStatefulWidget {
  final String sectionId;
  final int projectId;
  final VisualBibleData data;
  final BibleChanged onChanged;
  final String narrativeHint;
  final String? sectionContentJson;
  final Map<String, Widget> fieldWidgets;
  final String? sectionNumber;
  final String? sectionTitle;

  /// Los actos del proyecto, si la sección ya los ha resuelto con lo que
  /// había escrito antes de compartirlos.
  final List<BibleCard>? sharedActs;

  /// Valor con el que se duplica cada punto propio de la sección que no lo
  /// guarda en `values[clave]`. Sin valor, el punto no se puede duplicar.
  final Map<String, String?> duplicateValues;

  /// Imágenes que acompañaban a cada punto antes de los complementos.
  final Map<String, List<int>> legacyPointImages;

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
    this.sharedActs,
    this.duplicateValues = const {},
    this.legacyPointImages = const {},
  });

  @override
  ConsumerState<BibleSectionScaffold> createState() =>
      _BibleSectionScaffoldState();
}

class _BibleSectionScaffoldState extends ConsumerState<BibleSectionScaffold> {
  static const _contentPadding = EdgeInsets.all(AppSpacing.lg);
  static const double _sectionGap = AppSpacing.xl;

  @override
  Widget build(BuildContext context) {
    final fields = BibleSectionFieldsConfig.parse(
      widget.sectionContentJson,
      widget.sectionId,
    );

    final values = BibleSectionFieldsConfig.parseValues(
      widget.sectionContentJson,
    );
    final items = <Widget>[];
    for (final field in fields) {
      final w = _buildField(context, field);
      if (w == null) continue;
      items.add(
        widget.data.id > 0 ? _framed(fields, values, field, w) : w,
      );
    }

    return ListView(
      padding: _contentPadding,
      children: [
        if (widget.sectionNumber != null)
          BibleSectionHeader(
            number: widget.sectionNumber!,
            title:
                widget.sectionTitle ?? BibleSectionId.label(widget.sectionId),
          ),
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: _sectionGap),
          items[i],
        ],
        if (widget.data.id > 0) ...[
          const SizedBox(height: _sectionGap),
          BibleAddPointTile(onTap: () => _addPoint(fields)),
        ],
      ],
    );
  }

  /// Valor con el que se duplica [field], o `null` si no se puede.
  String? _duplicateValue(Map<String, String> values, BibleSectionField field) {
    if (BibleWidgetCatalog.forField(field) == null) return null;
    return widget.duplicateValues[field.key] ?? values[field.key];
  }

  Widget _framed(
    List<BibleSectionField> fields,
    Map<String, String> values,
    BibleSectionField field,
    Widget point,
  ) {
    final db = ref.read(databaseProvider);
    final extras = BiblePointExtras.read(
      values,
      field.key,
      legacyImages: widget.legacyPointImages[field.key] ?? const [],
    );
    final copyValue = _duplicateValue(values, field);
    return BiblePointFrame(
      key: ValueKey('frame_${widget.sectionId}_${field.key}'),
      projectId: widget.projectId,
      bibleId: widget.data.id,
      sectionId: widget.sectionId,
      extras: extras,
      onExtrasChanged: (next) => db.saveBibleSectionFieldValue(
        widget.data.id,
        widget.sectionId,
        BiblePointExtras.keyFor(field.key),
        next.encode(),
      ),
      onDuplicate: copyValue == null
          ? null
          : () => _duplicate(fields, field, copyValue, extras),
      onRemove: () => _remove(fields, field),
      child: point,
    );
  }

  /// Copia [field] justo debajo, como punto del usuario, con su contenido.
  Future<void> _duplicate(
    List<BibleSectionField> fields,
    BibleSectionField field,
    String value,
    BiblePointExtras extras,
  ) async {
    final db = ref.read(databaseProvider);
    final entry = BibleWidgetCatalog.forField(field, value: value);
    final copy = BibleSectionField(
      key: BibleSectionFieldsConfig.newFieldKey(),
      label: '${field.label} (copia)',
      hint: field.hint,
      maxLines: field.maxLines,
      type: field.type,
      widget: field.widget ?? entry?.id,
    );
    final at = fields.indexWhere((f) => f.key == field.key);
    await db.saveBibleSectionFields(widget.data.id, widget.sectionId, [
      ...fields.take(at + 1),
      copy,
      ...fields.skip(at + 1),
    ]);
    await db.saveBibleSectionFieldValue(
      widget.data.id,
      widget.sectionId,
      copy.key,
      value,
    );
    if (!extras.isEmpty) {
      await db.saveBibleSectionFieldValue(
        widget.data.id,
        widget.sectionId,
        BiblePointExtras.keyFor(copy.key),
        extras.encode(),
      );
    }
  }

  /// Quita [field] de la pantalla: uno del usuario se borra con su contenido;
  /// uno propio de la pantalla lo conserva.
  Future<void> _remove(
    List<BibleSectionField> fields,
    BibleSectionField field,
  ) async {
    final own = BibleSectionFieldsConfig.isUserPoint(widget.sectionId, field);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Quitar «${field.label}»'),
        content: Text(
          own
              ? 'Es un punto que añadiste tú. Se borra con su contenido y '
                    'no se puede recuperar.'
              : 'Es un punto propio de esta pantalla. Deja de mostrarse y de '
                    'salir en el PDF, pero su contenido se conserva: puedes '
                    'volver a añadirlo desde «Añadir punto».',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(own ? 'Borrar punto' : 'Quitar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(databaseProvider).saveBibleSectionFields(
      widget.data.id,
      widget.sectionId,
      [
        for (final f in fields)
          if (f.key != field.key) f,
      ],
      dropValueKeys: own ? {field.key} : const {},
    );
  }

  Future<void> _addPoint(List<BibleSectionField> fields) async {
    final added = await showBibleAddPointDialog(
      context,
      sectionId: widget.sectionId,
      fields: fields,
    );
    if (added == null || !mounted) return;
    final db = ref.read(databaseProvider);
    await db.saveBibleSectionFields(widget.data.id, widget.sectionId, [
      ...fields,
      added.field,
    ]);
    if (added.initialValue != null) {
      await db.saveBibleSectionFieldValue(
        widget.data.id,
        widget.sectionId,
        added.field.key,
        added.initialValue,
      );
    }
  }

  /// Widget del catálogo para un punto sin vista propia de la sección.
  Widget? _catalogPoint(BibleSectionField field) {
    final db = ref.read(databaseProvider);
    return BibleWidgetCatalog.build(
      context,
      BibleWidgetContext(
        projectId: widget.projectId,
        bibleId: widget.data.id,
        sectionId: widget.sectionId,
        field: field,
        value: BibleSectionFieldsConfig.parseValues(
          widget.sectionContentJson,
        )[field.key],
        onChanged: (value) => db.saveBibleSectionFieldValue(
          widget.data.id,
          widget.sectionId,
          field.key,
          value,
        ),
        db: db,
        sharedActs:
            widget.sharedActs ??
            BibleSharedActs.resolve(widget.data.actVisualNotes),
        onSharedActsChanged: (acts) {
          widget.data.actVisualNotes = BibleSharedActs.encode(acts);
          widget.onChanged(widget.data);
        },
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
      BibleSectionFieldType.references || BibleSectionFieldType.image =>
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
      BibleSectionFieldType.text ||
      BibleSectionFieldType.list ||
      BibleSectionFieldType.specs ||
      BibleSectionFieldType.palette ||
      BibleSectionFieldType.gallery ||
      BibleSectionFieldType.cards ||
      BibleSectionFieldType.acts ||
      BibleSectionFieldType.tags ||
      BibleSectionFieldType.referenceDeck => _catalogPoint(field),
      // Módulo del catálogo cuyo widget dedicado aún no está conectado.
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
              '$label: este punto todavía no tiene vista.',
              style: AppTypography.caption(palette),
            ),
          ),
        ],
      ),
    );
  }
}
