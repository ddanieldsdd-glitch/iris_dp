import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/photo_source_picker.dart';
import '../../core/utils/user_error.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_snackbar.dart';
import '../visual_bible/visual_bible_model.dart';
import 'artemis_importer.dart';

/// Elige fotos de Artemis (fototeca, cámara o archivos) y abre el reparto.
Future<void> importFromArtemis(
  BuildContext context, {
  required int projectId,
}) async {
  final paths = await PhotoSourcePicker.pickImages(
    context,
    title: 'Importar de Artemis',
  );
  if (paths.isEmpty || !context.mounted) return;
  final assigned = await Navigator.of(context).push<int>(
    MaterialPageRoute(
      builder: (_) => ArtemisImportScreen(projectId: projectId, paths: paths),
    ),
  );
  if (assigned != null && assigned > 0 && context.mounted) {
    AppSnackBar.show(
      context,
      assigned == 1
          ? '1 foto de Artemis importada'
          : '$assigned fotos de Artemis importadas',
    );
  }
}

enum ArtemisTarget { shot, moodboard, site }

/// Reparto de una tanda de fotos de Artemis, una a una: a un plano (y pasa al
/// siguiente), al moodboard o a una localización.
class ArtemisImportScreen extends ConsumerStatefulWidget {
  final int projectId;
  final List<String> paths;

  const ArtemisImportScreen({
    super.key,
    required this.projectId,
    required this.paths,
  });

  @override
  ConsumerState<ArtemisImportScreen> createState() =>
      _ArtemisImportScreenState();
}

class _ArtemisImportScreenState extends ConsumerState<ArtemisImportScreen> {
  var _index = 0;
  var _assigned = 0;
  var _busy = false;
  var _loaded = false;

  var _target = ArtemisTarget.shot;
  List<Scene> _scenes = const [];
  Map<int, List<Shot>> _shotsByScene = const {};
  List<LocationSite> _sites = const [];

  int? _sceneId;
  int? _shotId;
  String? _category;
  int? _siteId;
  var _alsoMoodboard = true;

  /// Planos en orden de guion: escena a escena.
  List<Shot> get _shotsInOrder => [
    for (final scene in _scenes) ...?_shotsByScene[scene.id],
  ];

  final _subs = <StreamSubscription<Object?>>[];
  List<Scene>? _allScenes;
  List<Shot>? _allShots;

  @override
  void initState() {
    super.initState();
    final db = ref.read(databaseProvider);
    _subs.addAll([
      db.watchScenesForProject(widget.projectId).listen((rows) {
        _allScenes = rows;
        _rebuild();
      }),
      db.watchShotsForProject(widget.projectId).listen((rows) {
        _allShots = rows;
        _rebuild();
      }),
      db.watchSitesForProject(widget.projectId).listen((rows) {
        _sites = rows;
        _siteId ??= rows.firstOrNull?.id;
        _rebuild();
      }),
    ]);
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    super.dispose();
  }

  void _rebuild() {
    final scenes = _allScenes;
    final shots = _allShots;
    if (scenes == null || shots == null || !mounted) return;
    final byScene = <int, List<Shot>>{};
    for (final shot in shots) {
      byScene.putIfAbsent(shot.sceneId, () => []).add(shot);
    }
    setState(() {
      _scenes = scenes.where((s) => byScene.containsKey(s.id)).toList();
      _shotsByScene = byScene;
      if (!_loaded) {
        _loaded = true;
        final first = _shotsInOrder.firstOrNull;
        _sceneId = first?.sceneId;
        _shotId = first?.id;
        if (first == null) _target = ArtemisTarget.moodboard;
      }
    });
  }

  Shot? get _shot => _shotsInOrder.where((s) => s.id == _shotId).firstOrNull;

  LocationSite? get _site => _sites.where((s) => s.id == _siteId).firstOrNull;

  ArtemisDestination? _destination({Shot? shot}) => switch (_target) {
    ArtemisTarget.shot =>
      (shot ?? _shot) == null ? null : ArtemisToShot((shot ?? _shot)!),
    ArtemisTarget.moodboard => ArtemisToMoodboard(category: _category),
    ArtemisTarget.site =>
      _site == null
          ? null
          : ArtemisToSite(_site!, alsoMoodboard: _alsoMoodboard),
  };

  Shot? _nextShotAfter(int? shotId) {
    final ordered = _shotsInOrder;
    final i = ordered.indexWhere((s) => s.id == shotId);
    if (i < 0 || i + 1 >= ordered.length) return null;
    return ordered[i + 1];
  }

  void _selectShot(Shot? shot) {
    if (shot == null) return;
    _sceneId = shot.sceneId;
    _shotId = shot.id;
  }

  void _advance() {
    if (_index + 1 >= widget.paths.length) {
      Navigator.of(context).pop(_assigned);
      return;
    }
    setState(() => _index++);
  }

  Future<void> _run(Future<void> Function() body) async {
    setState(() => _busy = true);
    try {
      await body();
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, userFriendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _assignCurrent() => _run(() async {
    final dest = _destination();
    if (dest == null) return;
    final db = ref.read(databaseProvider);
    await dest.apply(db, widget.projectId, widget.paths[_index]);
    _assigned++;
    // Una tanda de Artemis suele ir en orden de rodaje: plano a plano.
    if (_target == ArtemisTarget.shot) {
      final next = _nextShotAfter(_shotId);
      if (next != null) setState(() => _selectShot(next));
    }
    if (mounted) _advance();
  });

  /// Las que quedan: a planos seguidos, o todas al mismo destino.
  Future<void> _assignRest() => _run(() async {
    final db = ref.read(databaseProvider);
    var shot = _shot;
    for (var i = _index; i < widget.paths.length; i++) {
      final dest = _destination(shot: shot);
      if (dest == null) break;
      await dest.apply(db, widget.projectId, widget.paths[i]);
      _assigned++;
      // Sin más planos, las que sobren se quedan sin importar.
      if (_target == ArtemisTarget.shot) {
        shot = _nextShotAfter(shot?.id);
        if (shot == null) break;
      }
    }
    if (mounted) Navigator.of(context).pop(_assigned);
  });

  String get _restLabel {
    final left = widget.paths.length - _index;
    return _target == ArtemisTarget.shot
        ? 'Repartir las $left en planos seguidos'
        : 'Asignar las $left aquí';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final total = widget.paths.length;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.surface,
        title: Text(
          'Artemis · ${_index + 1} de $total',
          style: AppTypography.titleMedium(palette),
        ),
        actions: [
          TextButton(
            onPressed: _busy
                ? null
                : () => Navigator.of(context).pop(_assigned),
            child: Text(
              'Terminar',
              style: AppTypography.bodyMedium(
                palette,
              ).copyWith(color: palette.accent),
            ),
          ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 700;
                final preview = _Preview(path: widget.paths[_index]);
                final panel = _panel(palette);
                if (wide) {
                  return Row(
                    children: [
                      Expanded(child: preview),
                      SizedBox(width: 380, child: panel),
                    ],
                  );
                }
                return Column(
                  children: [
                    Expanded(child: preview),
                    // La foto siempre se ve: el panel, como mucho, 60 %.
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: constraints.maxHeight * 0.6,
                      ),
                      child: panel,
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _panel(AppPalette palette) {
    final hasShots = _shotsInOrder.isNotEmpty;
    final left = widget.paths.length - _index;
    return Material(
      color: palette.surface,
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Los destinos se desplazan; «Asignar» se queda siempre a mano.
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('¿A dónde va?', style: AppTypography.label(palette)),
                    const SizedBox(height: AppSpacing.sm),
                    SegmentedButton<ArtemisTarget>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                          value: ArtemisTarget.shot,
                          label: const Text('Plano'),
                          enabled: hasShots,
                        ),
                        const ButtonSegment(
                          value: ArtemisTarget.moodboard,
                          label: Text('Moodboard'),
                        ),
                        ButtonSegment(
                          value: ArtemisTarget.site,
                          label: const Text('Localiz.'),
                          enabled: _sites.isNotEmpty,
                        ),
                      ],
                      selected: {_target},
                      onSelectionChanged: _busy
                          ? null
                          : (v) => setState(() => _target = v.first),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ...switch (_target) {
                      ArtemisTarget.shot => _shotFields(palette),
                      ArtemisTarget.moodboard => _moodboardFields(palette),
                      ArtemisTarget.site => _siteFields(palette),
                    },
                    if (!hasShots && _target != ArtemisTarget.shot) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Para mandarlas a un plano, primero crea los planos en el guion técnico.',
                        style: AppTypography.caption(palette),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppButton(
                    label: 'Asignar',
                    icon: Icons.check,
                    loading: _busy,
                    onTap: _busy || _destination() == null
                        ? null
                        : _assignCurrent,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: _busy ? null : _advance,
                        child: Text(
                          'Saltar',
                          style: AppTypography.caption(
                            palette,
                          ).copyWith(color: palette.textSecondary),
                        ),
                      ),
                      if (left > 1)
                        TextButton(
                          onPressed: _busy || _destination() == null
                              ? null
                              : _assignRest,
                          child: Text(
                            _restLabel,
                            style: AppTypography.caption(
                              palette,
                            ).copyWith(color: palette.accent),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _shotFields(AppPalette palette) {
    final shots = _shotsByScene[_sceneId] ?? const <Shot>[];
    return [
      _Dropdown<int>(
        label: 'Escena',
        value: _sceneId,
        items: {for (final s in _scenes) s.id: 'Esc ${s.label} · ${s.name}'},
        onChanged: (id) => setState(() {
          _sceneId = id;
          _shotId = _shotsByScene[id]?.firstOrNull?.id;
        }),
      ),
      const SizedBox(height: AppSpacing.sm),
      _Dropdown<int>(
        label: 'Plano',
        value: _shotId,
        items: {
          for (final s in shots)
            s.id: [
              'Plano ${s.number}',
              if (s.framing?.isNotEmpty == true) s.framing!,
              if (s.lens?.isNotEmpty == true) s.lens!,
            ].join(' · '),
        },
        onChanged: (id) => setState(() => _shotId = id),
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        'Al asignar, pasa al plano siguiente.',
        style: AppTypography.caption(palette),
      ),
    ];
  }

  List<Widget> _moodboardFields(AppPalette palette) => [
    Text('Categoría', style: AppTypography.caption(palette)),
    const SizedBox(height: AppSpacing.xs),
    Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final c in [null, ...MoodboardCategory.all])
          ChoiceChip(
            label: Text(
              c == null ? 'Sin categoría' : MoodboardCategory.label(c),
            ),
            selected: _category == c,
            onSelected: (_) => setState(() => _category = c),
          ),
      ],
    ),
  ];

  List<Widget> _siteFields(AppPalette palette) => [
    _Dropdown<int>(
      label: 'Localización',
      value: _siteId,
      items: {for (final s in _sites) s.id: s.name},
      onChanged: (id) => setState(() => _siteId = id),
    ),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: _alsoMoodboard,
      onChanged: (v) => setState(() => _alsoMoodboard = v),
      title: Text(
        'También en su moodboard',
        style: AppTypography.bodyMedium(palette),
      ),
      subtitle: Text(
        'Va a la galería de la localización y a la biblia, en Localización.',
        style: AppTypography.caption(palette),
      ),
    ),
  ];
}

class _Preview extends StatelessWidget {
  final String path;
  const _Preview({required this.path});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Image.file(
        File(path),
        key: ValueKey(path),
        fit: BoxFit.contain,
        cacheWidth: 1600,
        errorBuilder: (_, _, _) => const Icon(
          Icons.broken_image_outlined,
          color: Colors.white54,
          size: 48,
        ),
      ),
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final Map<T, String> items;
  final ValueChanged<T?> onChanged;

  const _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DropdownButtonFormField<T>(
      initialValue: items.containsKey(value) ? value : null,
      key: ValueKey('$label-$value'),
      isExpanded: true,
      decoration: InputDecoration(labelText: label, isDense: true),
      dropdownColor: palette.surfaceElevated,
      items: [
        for (final e in items.entries)
          DropdownMenuItem(
            value: e.key,
            child: Text(
              e.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMedium(palette),
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
