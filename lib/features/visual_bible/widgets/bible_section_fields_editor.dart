import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/visual_bible/bible_stitch_module_registry.dart';
import '../bible_section_fields.dart';
import 'bible_add_point.dart';
import 'bible_render_report.dart';
import 'catalog/bible_widget_catalog.dart';
import '../../../core/widgets/safe_reorderable_column.dart';

/// Puntos de una pantalla de la biblia: orden, nombre, añadir y quitar.
///
/// Cada cambio se guarda al momento. El tipo de un punto se fija al crearlo
/// y no se puede cambiar: así la pantalla y el PDF no se desajustan.
class BibleSectionFieldsEditor extends ConsumerStatefulWidget {
  final int bibleId;
  final BibleSectionDefinition definition;

  /// Dentro del panel lateral, sin cabecera propia.
  final bool embedded;

  const BibleSectionFieldsEditor({
    super.key,
    required this.bibleId,
    required this.definition,
    this.embedded = false,
  });

  static Future<void> show(
    BuildContext context, {
    required int bibleId,
    required BibleSectionDefinition definition,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.palette.surfaceElevated,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (ctx, scrollController) =>
            BibleSectionFieldsEditor(bibleId: bibleId, definition: definition),
      ),
    );
  }

  @override
  ConsumerState<BibleSectionFieldsEditor> createState() =>
      _BibleSectionFieldsEditorState();
}

class _BibleSectionFieldsEditorState
    extends ConsumerState<BibleSectionFieldsEditor> {
  late List<BibleSectionField> _fields;

  String get _sectionId => widget.definition.id;

  /// Las pantallas personalizadas no tienen puntos de fábrica.
  bool get _hasFactoryPoints => !_sectionId.startsWith('custom_');

  bool _isUserPoint(BibleSectionField field) =>
      !_hasFactoryPoints ||
      BibleSectionFieldsConfig.isUserPoint(_sectionId, field);

  @override
  void initState() {
    super.initState();
    _reloadFields();
  }

  void _reloadFields() {
    _fields = BibleSectionFieldsConfig.parse(
      widget.definition.contentJson,
      _sectionId,
    );
  }

  @override
  void didUpdateWidget(BibleSectionFieldsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.definition.id != widget.definition.id ||
        oldWidget.definition.contentJson != widget.definition.contentJson) {
      setState(_reloadFields);
    }
  }

  Future<void> _save({Set<String> dropValueKeys = const {}}) => ref
      .read(databaseProvider)
      .saveBibleSectionFields(
        widget.bibleId,
        _sectionId,
        _fields,
        dropValueKeys: dropValueKeys,
      );

  Future<void> _rename(int index) async {
    final field = _fields[index];
    final controller = TextEditingController(text: field.label);
    final label = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renombrar punto'),
        content: TextField(
          controller: controller,
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (label == null || label.isEmpty || !mounted) return;
    setState(() => _fields[index] = field.copyWith(label: label));
    await _save();
  }

  Future<void> _add() async {
    final added = await showBibleAddPointDialog(
      context,
      sectionId: _sectionId,
      // En una pantalla personalizada solo se ofrecen widgets.
      fields: _hasFactoryPoints
          ? _fields
          : [..._fields, ...BibleSectionFieldsConfig.defaultsFor(_sectionId)],
    );
    if (added == null || !mounted) return;
    setState(() => _fields.add(added.field));
    await _save();
    if (added.initialValue != null) {
      await ref
          .read(databaseProvider)
          .saveBibleSectionFieldValue(
            widget.bibleId,
            _sectionId,
            added.field.key,
            added.initialValue,
          );
    }
  }

  Future<void> _remove(int index) async {
    final field = _fields[index];
    final own = _isUserPoint(field);
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
    setState(() => _fields.removeAt(index));
    await _save(dropValueKeys: own ? {field.key} : const {});
  }

  Future<void> _reset() async {
    final next = BibleSectionFieldsConfig.resetKeepingUserPoints(
      _sectionId,
      _fields,
    );
    final present = _fields.map((f) => f.key).toSet();
    final returning = [
      for (final field in next)
        if (!present.contains(field.key)) field.label,
    ];
    final own = _fields.where(_isUserPoint).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restablecer pantalla'),
        content: Text(
          [
            'Los puntos de la pantalla vuelven a su orden y nombre originales.',
            if (returning.isNotEmpty)
              'Vuelven a mostrarse: ${returning.join(', ')}.',
            if (own > 0)
              own == 1
                  ? 'El punto que añadiste se conserva, al final.'
                  : 'Los $own puntos que añadiste se conservan, al final.',
            'No se borra ningún contenido.',
          ].join('\n\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restablecer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _fields = next);
    await _save();
  }

  /// Widget del catálogo que corresponde al punto: el que eligió el usuario
  /// o, en un punto de la pantalla, aquel al que equivale.
  BibleWidgetEntry? _entry(BibleSectionField field) {
    if (!_isUserPoint(field)) {
      return BibleWidgetCatalog.byId(
        BibleStitchModuleRegistry.module(_sectionId, field.key)?.widgetId,
      );
    }
    return BibleWidgetCatalog.forField(
      field,
      value: BibleSectionFieldsConfig.parseValues(
        widget.definition.contentJson,
      )[field.key],
    );
  }

  /// Qué es el punto, para el subtítulo de su fila.
  String _kindLabel(BibleSectionField field) {
    final entry = _entry(field);
    if (!_isUserPoint(field)) {
      return entry == null
          ? 'Punto de la pantalla'
          : 'Punto de la pantalla · ${entry.label}';
    }
    return entry == null
        ? BibleSectionFieldsConfig.labelForType(field.type)
        : '${entry.category.label} · ${entry.label}';
  }

  IconData _icon(BibleSectionField field) =>
      _entry(field)?.icon ??
      BibleStitchModuleRegistry.module(
        _sectionId,
        field.key,
      )?.catalogKind.icon ??
      Icons.article_outlined;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final sectionId = widget.definition.id;
    final fixed = kSectionFixedBlocks[sectionId];
    // Lo que la pantalla no ha podido pintar; en una pantalla de bloques
    // fijos, ninguno de sus puntos se ve todavía.
    final unrendered = fixed != null
        ? {for (final f in _fields) f.key}
        : (ref.watch(bibleRenderReportProvider)[sectionId] ?? const <String>{});
    final loose = [
      for (final f in _fields)
        if (unrendered.contains(f.key)) f.label,
      ...?fixed,
    ];

    return Material(
      color: palette.surfaceElevated,
      child: Padding(
        padding: EdgeInsets.all(
          widget.embedded ? AppSpacing.md : AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!widget.embedded) ...[
              Text(
                'Puntos · ${widget.definition.label}',
                style: AppTypography.titleMedium(palette),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            Text(
              'Arrastra para ordenar. El orden es el de la pantalla y el del '
              'PDF.',
              style: AppTypography.caption(palette),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: SafeReorderableColumn(
                itemCount: _fields.length,
                keyOf: (index) => ValueKey(_fields[index].key),
                dragLabel: (index) => _fields[index].label,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    _fields.insert(newIndex, _fields.removeAt(oldIndex));
                  });
                  _save();
                },
                itemBuilder: (context, index) {
                  final field = _fields[index];
                  return Material(
                    color: palette.surfaceElevated,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(_icon(field), size: 20),
                      title: Text(field.label),
                      subtitle: Text(
                        [
                          _kindLabel(field),
                          field.width.label,
                          if (unrendered.contains(field.key)) 'no se ve',
                        ].join(' · '),
                        style: AppTypography.caption(palette).copyWith(
                          color: unrendered.contains(field.key)
                              ? palette.warning
                              : null,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            tooltip: 'Renombrar',
                            onPressed: () => _rename(index),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            tooltip: 'Quitar',
                            onPressed: () => _remove(index),
                          ),
                          // Deja sitio al asa de arrastre de la lista.
                          const SizedBox(width: 28),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (loose.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              _LooseBlocks(items: loose, fixedScreen: fixed != null),
            ],
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: const Text('Añadir punto'),
            ),
            if (_hasFactoryPoints) ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Restablecer pantalla'),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Los cambios se guardan al instante.',
              style: AppTypography.caption(
                palette,
              ).copyWith(color: palette.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

/// «Sin vincular»: puntos que la pantalla no pinta y bloques que pinta por
/// su cuenta, fuera del sistema de puntos. Queda a la vista para
/// vincularlos más adelante.
class _LooseBlocks extends StatelessWidget {
  final List<String> items;
  final bool fixedScreen;

  const _LooseBlocks({required this.items, required this.fixedScreen});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: palette.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.warning.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.link_off, size: 16, color: palette.warning),
              const SizedBox(width: 6),
              Text(
                'SIN VINCULAR',
                style: AppTypography.mono(
                  palette,
                ).copyWith(fontSize: 11, color: palette.warning),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            fixedScreen
                ? 'Esta pantalla aún se pinta con bloques propios: no se '
                      'ordenan ni se quitan desde aquí, y sus puntos no se ven.'
                : 'Estos puntos están en la lista pero la pantalla no tiene '
                      'widget para pintarlos.',
            style: AppTypography.caption(palette),
          ),
          const SizedBox(height: 4),
          for (final item in items)
            Text('· $item', style: AppTypography.bodyMedium(palette)),
        ],
      ),
    );
  }
}
