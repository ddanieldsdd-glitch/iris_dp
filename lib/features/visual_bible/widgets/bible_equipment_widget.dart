import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/visual_bible/bible_equipment.dart';
import 'bible_point_panel.dart';

/// Lo que devuelve un selector de equipo.
class BibleEquipmentPick {
  final int? catalogId;
  final String name;
  final Map<String, String> facts;

  const BibleEquipmentPick({
    required this.name,
    this.catalogId,
    this.facts = const {},
  });
}

typedef BibleEquipmentPicker =
    Future<BibleEquipmentPick?> Function(BuildContext context);

/// Datos de la ficha de una cámara del catálogo, con los rótulos de la
/// biblia.
Map<String, String> cameraFacts(Camera camera) => {
  'Sensor':
      '${camera.sensorWidthMm.toStringAsFixed(2)}×'
      '${camera.sensorHeightMm.toStringAsFixed(2)} mm',
  if ((camera.mountType ?? '').isNotEmpty) 'Montura': camera.mountType!,
  if (camera.dynamicRangeStops != null)
    'Rango dinámico':
        '${camera.dynamicRangeStops!.toStringAsFixed(camera.dynamicRangeStops! % 1 == 0 ? 0 : 1)} stops',
  if (camera.nativeIso != null) 'ISO nativo': '${camera.nativeIso}',
};

/// Selector de cámara: primero las del proyecto, después el catálogo, y
/// siempre la opción de usar lo escrito tal cual.
Future<BibleEquipmentPick?> pickBibleCamera(
  BuildContext context, {
  required AppDatabase db,
  required int projectId,
}) => showDialog<BibleEquipmentPick>(
  context: context,
  builder: (_) => _CameraPickerDialog(db: db, projectId: projectId),
);

class _CameraPickerDialog extends StatefulWidget {
  final AppDatabase db;
  final int projectId;
  const _CameraPickerDialog({required this.db, required this.projectId});

  @override
  State<_CameraPickerDialog> createState() => _CameraPickerDialogState();
}

class _CameraPickerDialogState extends State<_CameraPickerDialog> {
  final _query = TextEditingController();
  List<Camera> _all = const [];
  Set<int> _inProject = const {};

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() {}));
    _load();
  }

  Future<void> _load() async {
    final cameras = await widget.db.select(widget.db.cameras).get();
    final assigned = await widget.db.getProjectEquipment(widget.projectId);
    if (!mounted) return;
    setState(() {
      _all = cameras;
      _inProject = {
        for (final e in assigned)
          if (e.equipmentType == 'camera') e.equipmentId,
      };
    });
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = _query.text.trim();
    final needle = text.toLowerCase();
    final matches = [
      for (final c in _all)
        if (needle.isEmpty ||
            '${c.brand} ${c.model}'.toLowerCase().contains(needle))
          c,
    ]..sort((a, b) {
      final pa = _inProject.contains(a.id) ? 0 : 1;
      final pb = _inProject.contains(b.id) ? 0 : 1;
      if (pa != pb) return pa - pb;
      return '${a.brand} ${a.model}'.compareTo('${b.brand} ${b.model}');
    });

    return Dialog(
      backgroundColor: palette.surfaceElevated,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Elegir cámara', style: AppTypography.titleMedium(palette)),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _query,
                autofocus: true,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'Buscar en el equipo, o escribir un nombre',
                  prefixIcon: Icon(Icons.search, size: 18),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: Material(
                  type: MaterialType.transparency,
                  child: ListView(
                    children: [
                      for (final camera in matches.take(60))
                        ListTile(
                          dense: true,
                          title: Text('${camera.brand} ${camera.model}'),
                          subtitle: Text(
                            [
                              if (_inProject.contains(camera.id))
                                'En el proyecto',
                              cameraFacts(camera)['Sensor']!,
                            ].join(' · '),
                          ),
                          onTap: () => Navigator.pop(
                            context,
                            BibleEquipmentPick(
                              catalogId: camera.id,
                              name: '${camera.brand} ${camera.model}',
                              facts: cameraFacts(camera),
                            ),
                          ),
                        ),
                      if (text.isNotEmpty)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.edit_outlined, size: 18),
                          title: Text('Usar «$text» tal cual'),
                          subtitle: const Text('Sin ficha del catálogo'),
                          onTap: () => Navigator.pop(
                            context,
                            BibleEquipmentPick(name: text),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Equipo del proyecto en la biblia: cada pieza con su papel, si es
/// tentativa o definitiva, una nota y, si se quiere, una alternativa.
class BibleEquipmentWidget extends StatefulWidget {
  final List<BibleEquipmentItem> items;
  final ValueChanged<List<BibleEquipmentItem>> onChanged;
  final BibleEquipmentPicker pick;

  /// «cámara», «juego de lentes»… para los rótulos.
  final String noun;

  /// El nombre es femenino («cámara tentativa») o masculino.
  final bool feminine;

  const BibleEquipmentWidget({
    super.key,
    required this.items,
    required this.onChanged,
    required this.pick,
    this.noun = 'cámara',
    this.feminine = true,
  });

  @override
  State<BibleEquipmentWidget> createState() => _BibleEquipmentWidgetState();
}

class _BibleEquipmentWidgetState extends State<BibleEquipmentWidget> {
  late List<BibleEquipmentItem> _items = [...widget.items];
  int _shape = 0;
  Timer? _debounce;
  bool _pending = false;

  @override
  void didUpdateWidget(covariant BibleEquipmentWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Lo que llega de fuera manda solo si aquí no hay nada a medio guardar.
    if (!_pending &&
        BibleEquipmentItem.encode(widget.items) !=
            BibleEquipmentItem.encode(_items)) {
      _items = [...widget.items];
      _shape++;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (_pending) widget.onChanged(_items);
    super.dispose();
  }

  void _typed(int index, BibleEquipmentItem next) {
    _items[index] = next;
    _pending = true;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _pending = false;
      widget.onChanged(_items);
    });
  }

  void _set(List<BibleEquipmentItem> next) {
    _debounce?.cancel();
    _pending = false;
    setState(() {
      _items = next;
      _shape++;
    });
    widget.onChanged(next);
  }

  void _replace(int index, BibleEquipmentItem item) =>
      _set([..._items]..[index] = item);

  String _nextRole() {
    const letters = 'ABCDEFGH';
    final used = {for (final item in _items) item.role};
    for (final letter in letters.split('')) {
      if (!used.contains(letter)) return letter;
    }
    return '';
  }

  Future<void> _add() async {
    final pick = await widget.pick(context);
    if (pick == null) return;
    _set([
      ..._items,
      BibleEquipmentItem(
        role: _nextRole(),
        catalogId: pick.catalogId,
        name: pick.name,
        facts: pick.facts,
      ),
    ]);
  }

  InputDecoration _bare(AppPalette palette, String hint, TextStyle style) =>
      InputDecoration(
        hintText: hint,
        hintStyle: style.copyWith(color: palette.textTertiary),
        isDense: true,
        filled: false,
        contentPadding: const EdgeInsets.symmetric(vertical: 4),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
      );

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final label = BiblePointPanel.labelStyle(palette);
    final note = AppTypography.bodyMedium(palette);

    Widget statusChip(int i, BibleEquipmentStatus status) {
      final on = _items[i].status == status;
      final definitive = status == BibleEquipmentStatus.definitive;
      final color = definitive ? palette.accent : palette.highlightYellow;
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: on ? null : () => _replace(i, _items[i].copyWith(status: status)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: on ? color.withValues(alpha: 0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: on ? color.withValues(alpha: 0.9) : palette.divider,
            ),
          ),
          child: Text(
            (widget.feminine ? status.feminine : status.masculine)
                .toUpperCase(),
            style: label.copyWith(
              color: on ? palette.textPrimary : palette.textTertiary,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _items.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: palette.background.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: palette.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 34,
                      child: TextFormField(
                        key: ValueKey('eq_role_${_shape}_$i'),
                        initialValue: _items[i].role,
                        style: AppTypography.titleLarge(
                          palette,
                        ).copyWith(color: palette.accent),
                        decoration: _bare(
                          palette,
                          '·',
                          AppTypography.titleLarge(palette),
                        ),
                        onChanged: (v) =>
                            _typed(i, _items[i].copyWith(role: v.trim())),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () async {
                          final pick = await widget.pick(context);
                          if (pick == null) return;
                          _replace(
                            i,
                            _items[i].withMain(
                              catalogId: pick.catalogId,
                              name: pick.name,
                              facts: pick.facts,
                            ),
                          );
                        },
                        child: Tooltip(
                          message: 'Cambiar ${widget.noun}',
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              _items[i].name,
                              style: AppTypography.titleMedium(palette),
                            ),
                          ),
                        ),
                      ),
                    ),
                    statusChip(i, BibleEquipmentStatus.tentative),
                    const SizedBox(width: 6),
                    statusChip(i, BibleEquipmentStatus.definitive),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 14,
                        color: palette.textTertiary,
                      ),
                      tooltip: 'Quitar ${widget.noun}',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _set([..._items]..removeAt(i)),
                    ),
                  ],
                ),
                if (_items[i].facts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 34, bottom: 4),
                    child: Text(
                      _items[i].facts.entries
                          .map((e) => '${e.key}: ${e.value}')
                          .join('  ·  '),
                      style: AppTypography.caption(palette),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(left: 34),
                  child: TextFormField(
                    key: ValueKey('eq_note_${_shape}_$i'),
                    initialValue: _items[i].note,
                    minLines: 1,
                    maxLines: null,
                    style: note,
                    decoration: _bare(
                      palette,
                      'Por qué esta ${widget.noun}, para qué unidad…',
                      note,
                    ),
                    onChanged: (v) => _typed(i, _items[i].copyWith(note: v)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 34, top: 6),
                  child: !_items[i].hasAlternative
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () async {
                              final pick = await widget.pick(context);
                              if (pick == null) return;
                              _replace(
                                i,
                                _items[i].withAlternative(
                                  catalogId: pick.catalogId,
                                  name: pick.name,
                                ),
                              );
                            },
                            icon: Icon(
                              Icons.alt_route,
                              size: 16,
                              color: palette.textSecondary,
                            ),
                            label: Text('AÑADIR ALTERNATIVA', style: label),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.alt_route,
                                  size: 14,
                                  color: palette.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'ALTERNATIVA · ${_items[i].altName}',
                                    style: label,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.close,
                                    size: 12,
                                    color: palette.textTertiary,
                                  ),
                                  tooltip: 'Quitar alternativa',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _replace(
                                    i,
                                    _items[i].withAlternative(),
                                  ),
                                ),
                              ],
                            ),
                            TextFormField(
                              key: ValueKey('eq_alt_${_shape}_$i'),
                              initialValue: _items[i].altNote,
                              minLines: 1,
                              maxLines: null,
                              style: note,
                              decoration: _bare(
                                palette,
                                'Cuándo se usaría: si no entra en '
                                'presupuesto…',
                                note,
                              ),
                              onChanged: (v) =>
                                  _typed(i, _items[i].copyWith(altNote: v)),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _add,
            icon: Icon(Icons.add, size: 16, color: palette.textSecondary),
            label: Text('AÑADIR ${widget.noun.toUpperCase()}', style: label),
          ),
        ),
      ],
    );
  }
}

/// Punto «Cámaras» listo para el catálogo y para la pantalla de Cámara.
class BibleCameraEquipmentPoint extends ConsumerWidget {
  final int projectId;
  final List<BibleEquipmentItem> items;
  final ValueChanged<List<BibleEquipmentItem>> onChanged;

  const BibleCameraEquipmentPoint({
    super.key,
    required this.projectId,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) => BibleEquipmentWidget(
    items: items,
    onChanged: onChanged,
    pick: (context) => pickBibleCamera(
      context,
      db: ref.read(databaseProvider),
      projectId: projectId,
    ),
  );
}
