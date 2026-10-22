import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../visual_bible_model.dart';
import '../bible_navigation_scope.dart';
import '../bible_unified_references_panel.dart';
import '../narrative_bridge_card.dart';
import '../../../../shared/visual_bible/bible_acts.dart';
import '../../../../shared/visual_bible/bible_cards.dart';
import '../../../../shared/visual_bible/bible_point_extras.dart';
import '../../../../shared/visual_bible/bible_stitch_module_registry.dart';
import '../../bible_section_fields.dart';
import '../bible_add_point.dart';
import '../bible_point_frame.dart';
import '../bible_render_report.dart';
import '../bible_screen_hero.dart';
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

  /// Imagen y subtítulo de la cabecera cuando la pantalla los toma de otro
  /// sitio (Iluminación: su tratamiento de luz).
  final int? heroFallbackImageId;
  final String? heroSubtitle;

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
    this.heroFallbackImageId,
    this.heroSubtitle,
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
  static const double _rowBreakpoint = 1100;

  /// Veces que se ha reiniciado la pantalla desde que está abierta.
  int _resetCount = 0;

  @override
  Widget build(BuildContext context) {
    final fields = BibleSectionFieldsConfig.parse(
      widget.sectionContentJson,
      widget.sectionId,
    );

    final values = BibleSectionFieldsConfig.parseValues(
      widget.sectionContentJson,
    );
    final points = <(BiblePointWidth, Widget)>[];
    final unrendered = <String>{};
    for (final field in fields) {
      final w = _buildField(context, field);
      if (w == null) {
        unrendered.add(field.key);
        continue;
      }
      points.add((
        field.width,
        widget.data.id > 0 ? _framed(fields, values, field, w) : w,
      ));
    }
    // El panel lateral avisa de lo que no se ha podido pintar.
    final report = ref.read(bibleRenderReportProvider.notifier);
    final sectionId = widget.sectionId;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => report.report(sectionId, unrendered),
    );
    // En estrecho no hay sitio para dos puntos por fila.
    final wide = MediaQuery.sizeOf(context).width >= _rowBreakpoint;
    final items = _rows(points, wide: wide);

    return ListView(
      padding: _contentPadding,
      children: [
        BibleSectionHero(
          projectId: widget.projectId,
          bibleId: widget.data.id,
          sectionId: widget.sectionId,
          title: widget.sectionTitle ?? BibleSectionId.label(widget.sectionId),
          fallbackImageId: widget.heroFallbackImageId,
          subtitle: widget.heroSubtitle,
          onAfterReset: () {
            // Lo que la pantalla escribe en la biblia, fuera de su definición.
            widget.data.clearSection(widget.sectionId);
            widget.onChanged(widget.data);
            if (mounted) setState(() => _resetCount++);
          },
        ),
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: _sectionGap),
          // Tras reiniciar, los campos se montan de nuevo: no deben
          // conservar el texto que tenían.
          KeyedSubtree(
            key: ValueKey('point_${_resetCount}_${wide}_$i'),
            child: items[i],
          ),
        ],
        if (widget.data.id > 0) ...[
          const SizedBox(height: _sectionGap),
          BibleAddPointTile(onTap: () => _addPoint(fields)),
        ],
      ],
    );
  }

  /// Agrupa los puntos estrechos que van seguidos en filas de seis sextos.
  static List<Widget> _rows(
    List<(BiblePointWidth, Widget)> points, {
    required bool wide,
  }) {
    if (!wide) return [for (final (_, w) in points) w];
    final rows = <Widget>[];
    var row = <(BiblePointWidth, Widget)>[];
    var used = 0;
    void flush() {
      if (row.isEmpty) return;
      if (row.length == 1 && row.first.$1 == BiblePointWidth.full) {
        rows.add(row.first.$2);
      } else {
        rows.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < row.length; i++) ...[
                if (i > 0) const SizedBox(width: _sectionGap),
                Expanded(flex: row[i].$1.sixths, child: row[i].$2),
              ],
              // Una fila a medias no estira su último punto.
              if (used < 6) Spacer(flex: 6 - used),
            ],
          ),
        );
      }
      row = [];
      used = 0;
    }

    for (final point in points) {
      if (used + point.$1.sixths > 6) flush();
      row.add(point);
      used += point.$1.sixths;
      if (used == 6) flush();
    }
    flush();
    return rows;
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
      width: field.width,
      onWidthChanged: (width) =>
          db.saveBibleSectionFields(widget.data.id, widget.sectionId, [
            for (final f in fields)
              f.key == field.key ? f.copyWith(width: width) : f,
          ]),
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
      BibleSectionFieldType.table ||
      BibleSectionFieldType.meters ||
      BibleSectionFieldType.equipment ||
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
