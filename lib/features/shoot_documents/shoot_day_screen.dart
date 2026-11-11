import 'package:drift/drift.dart' show Value;
import 'shoot_documents_export.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/user_error.dart';
import '../../core/weather/weather_models.dart';
import '../../core/weather/weather_service.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/safe_reorderable_column.dart';
import '../../shared/technical_script_export/technical_script_doc.dart';
import '../locations/site_place.dart';
import '../export_center/export_center_screen.dart';
import '../export_center/export_selection.dart';
import '../technical_script/technical_script_export.dart';
import 'shoot_day_on_set.dart';
import 'shoot_day_order.dart';
import 'shoot_day_timeline.dart';
import 'shoot_day_widgets.dart';
import 'shoot_document_block_types.dart';
import 'shoot_document_script_picker.dart';

export 'shoot_plan.dart' show kShootDayKind, sortShootDays;

/// Guion técnico de rodaje de una jornada: fecha, lugar, meteorología y los
/// planos del guion técnico en el orden en que se van a rodar.
class ShootDayScreen extends ConsumerStatefulWidget {
  final int projectId;
  final int documentId;

  const ShootDayScreen({
    super.key,
    required this.projectId,
    required this.documentId,
  });

  @override
  ConsumerState<ShootDayScreen> createState() => _ShootDayScreenState();
}

class _ShootDayScreenState extends ConsumerState<ShootDayScreen> {
  bool _loadingForecast = false;

  AppDatabase get _db => ref.read(databaseProvider);

  Future<void> _save(ShootDocument day) =>
      _db.updateShootDocument(day.copyWith(updatedAt: DateTime.now()));

  Future<void> _pickDate(ShootDocument day) async {
    final current = DateTime.tryParse(day.shootDate ?? '') ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(current.year - 2),
      lastDate: DateTime(current.year + 5),
      helpText: 'Fecha de la jornada',
    );
    if (picked == null) return;
    final iso =
        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}';
    await _save(day.copyWith(shootDate: Value(iso)));
  }

  Future<void> _pickTime(ShootDocument day, {required bool from}) async {
    final value = await pickClockTime(
      context,
      current: from ? day.shootFromTime : day.shootToTime,
      fallback: from ? '08:00' : '18:00',
      help: from ? 'Se rueda desde' : 'Se rueda hasta',
    );
    if (value == null) return;
    await _save(
      from
          ? day.copyWith(shootFromTime: Value(value))
          : day.copyWith(shootToTime: Value(value)),
    );
  }

  Future<void> _refreshForecast(ShootDocument day, LocationSite site) async {
    final date = day.shootDate;
    final lat = site.latitude;
    final lon = site.longitude;
    if (date == null || lat == null || lon == null || _loadingForecast) return;
    setState(() => _loadingForecast = true);
    try {
      final snapshot = await ref
          .read(weatherProviderProvider)
          .forecast(latitude: lat, longitude: lon, date: date);
      if (!mounted) return;
      if (snapshot == null) {
        AppSnackBar.show(context, 'No hay previsión para esa fecha.');
        return;
      }
      await _save(day.copyWith(weatherSnapshotJson: Value(snapshot.encode())));
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          'No se pudo descargar la previsión. ${userFriendlyError(e)}',
        );
      }
    } finally {
      if (mounted) setState(() => _loadingForecast = false);
    }
  }

  Future<void> _addFromScript(List<ShootDocumentBlock> blocks) async {
    final picked = await showShootDocumentScriptPicker(
      context,
      db: _db,
      projectId: widget.projectId,
      alreadyInDocument: {
        for (final b in blocks)
          if (b.shotId != null) b.shotId!,
      },
    );
    if (picked == null) return;
    var order = blocks.isEmpty ? 0 : blocks.last.sortOrder + 1;
    for (final entry in picked.scenes) {
      for (final shot in entry.shots) {
        await _db.insertShootDocumentBlock(
          ShootDocumentBlocksCompanion.insert(
            documentId: widget.documentId,
            sortOrder: Value(order++),
            blockType: ShootBlockType.shot,
            sceneId: Value(entry.scene.id),
            shotId: Value(shot.id),
          ),
        );
      }
    }
  }

  void _openOnSet(ShootDocument day) => ShootDayOnSetScreen.open(
    context,
    projectId: widget.projectId,
    documentId: widget.documentId,
    title: day.name,
  );

  Future<void> _order(ShootDocument day, [BuildContext? from]) =>
      exportShootDayOrder(
        from ?? context,
        ref.read(databaseProvider),
        projectId: widget.projectId,
        dayIds: {day.id},
        dayName: day.name,
      );

  void _export() => ExportCenterScreen.open(
    context,
    projectId: widget.projectId,
    document: ExportDocument.technicalScript,
    dayId: widget.documentId,
  );

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    return StreamBuilder<List<ShootDocument>>(
      stream: db.watchShootDocumentsForProject(widget.projectId),
      builder: (context, docSnap) {
        final day = docSnap.data
            ?.where((d) => d.id == widget.documentId)
            .firstOrNull;
        if (day == null) {
          return Scaffold(
            appBar: AppBar(backgroundColor: palette.surface),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        return Scaffold(
          appBar: AppBar(
            backgroundColor: palette.surface,
            title: Text(day.name, style: AppTypography.titleMedium(palette)),
            actions: AppLayout.isCompact(context)
                ? [
                    IconButton(
                      tooltip: 'En set',
                      onPressed: () => _openOnSet(day),
                      icon: const Icon(Icons.checklist),
                    ),
                    IconButton(
                      tooltip: 'Orden del día (PDF)',
                      onPressed: () => _order(day),
                      icon: const Icon(Icons.assignment_outlined),
                    ),
                    IconButton(
                      tooltip: 'Exportar',
                      onPressed: _export,
                      icon: const Icon(Icons.ios_share),
                    ),
                  ]
                : [
                    TextButton.icon(
                      onPressed: () => _openOnSet(day),
                      icon: const Icon(Icons.checklist, size: 18),
                      label: const Text('En set'),
                    ),
                    Builder(
                      builder: (context) => TextButton.icon(
                        onPressed: () => _order(day, context),
                        icon: const Icon(Icons.assignment_outlined, size: 18),
                        label: const Text('Orden del día'),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilledButton.icon(
                        onPressed: _export,
                        icon: const Icon(Icons.ios_share, size: 18),
                        label: const Text('Exportar'),
                      ),
                    ),
                  ],
          ),
          body: StreamBuilder<List<LocationSite>>(
            stream: db.watchSitesForProject(widget.projectId),
            builder: (context, siteSnap) {
              final sites = siteSnap.data ?? const <LocationSite>[];
              final site = sites
                  .where((s) => s.id == day.locationSiteId)
                  .firstOrNull;
              return StreamBuilder<List<ShootDocumentBlock>>(
                stream: db.watchBlocksForShootDocument(widget.documentId),
                builder: (context, blockSnap) {
                  final blocks = blockSnap.data ?? const <ShootDocumentBlock>[];
                  final header = _header(day, sites, site, palette);
                  Widget order({required bool embedded}) => _DayOrder(
                    projectId: widget.projectId,
                    documentId: widget.documentId,
                    blocks: blocks,
                    sites: sites,
                    embedded: embedded,
                    onAdd: () => _addFromScript(blocks),
                  );
                  return LayoutBuilder(
                    builder: (context, constraints) =>
                        constraints.maxWidth < 900
                        ? ListView(
                            padding: const EdgeInsets.only(bottom: 40),
                            children: [
                              header,
                              const Divider(height: 1),
                              order(embedded: true),
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 380,
                                child: SingleChildScrollView(child: header),
                              ),
                              VerticalDivider(width: 1, color: palette.divider),
                              Expanded(child: order(embedded: false)),
                            ],
                          ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _header(
    ShootDocument day,
    List<LocationSite> sites,
    LocationSite? site,
    AppPalette palette,
  ) {
    final options = WeatherOptions.decode(day.weatherOptionsJson);
    final weather = shootDayWeather(day, site);
    final date = DateTime.tryParse(day.shootDate ?? '');
    final inForecast = date != null && isWithinForecast(date, DateTime.now());
    final label = AppTypography.label(palette);
    final body = AppTypography.bodyMedium(
      palette,
    ).copyWith(color: palette.textPrimary);

    Future<void> setOptions(WeatherOptions next) =>
        _save(day.copyWith(weatherOptionsJson: Value(next.encode())));

    Widget toggle(String text, bool value, WeatherOptions Function() next) =>
        FilterChip(
          label: Text(text),
          selected: value,
          onSelected: (_) => setOptions(next()),
        );

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Fecha', style: label),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: () => _pickDate(day),
            icon: const Icon(Icons.event, size: 18),
            label: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                day.shootDate == null
                    ? 'Elegir fecha'
                    : formatShootDate(day.shootDate),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Se rueda (opcional)', style: label),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickTime(day, from: true),
                  child: Text(day.shootFromTime ?? 'Desde'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickTime(day, from: false),
                  child: Text(day.shootToTime ?? 'Hasta'),
                ),
              ),
              if (day.shootFromTime != null || day.shootToTime != null)
                IconButton(
                  tooltip: 'Quitar la franja',
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () => _save(
                    day.copyWith(
                      shootFromTime: const Value(null),
                      shootToTime: const Value(null),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Localización', style: label),
          const SizedBox(height: 6),
          DropdownButtonFormField<int>(
            key: ValueKey('site-${day.locationSiteId}'),
            initialValue: site?.id,
            isExpanded: true,
            dropdownColor: palette.surfaceElevated,
            decoration: const InputDecoration(isDense: true),
            hint: Text(
              sites.isEmpty
                  ? 'El proyecto aún no tiene localizaciones'
                  : 'Elegir localización',
            ),
            items: [
              for (final s in sites)
                DropdownMenuItem(value: s.id, child: Text(s.name)),
            ],
            onChanged: (id) => _save(
              day.copyWith(
                locationSiteId: Value(id),
                // La previsión era de otro sitio.
                weatherSnapshotJson: const Value(null),
              ),
            ),
          ),
          if (site != null) ...[
            const SizedBox(height: 8),
            SitePlaceCard(site: site, full: false, navigation: true),
            const SizedBox(height: 8),
            ShootSitePhotos(projectId: widget.projectId, site: site),
          ],
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(child: Text('Meteorología', style: label)),
              if (site?.latitude != null && day.shootDate != null)
                TextButton.icon(
                  onPressed: _loadingForecast || !inForecast
                      ? null
                      : () => _refreshForecast(day, site!),
                  icon: _loadingForecast
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 16),
                  label: Text(
                    weather.forecast == null ? 'Descargar' : 'Actualizar',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (weather.lines.isEmpty)
            Text(
              'Pon la fecha y ubica la localización para ver el sol y la '
              'previsión.',
              style: AppTypography.caption(palette),
            )
          else
            for (final line in weather.lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(line, style: body),
              ),
          if (weather.forecast != null) ...[
            const SizedBox(height: 2),
            Text(
              'Previsión descargada el '
              '${_stamp(weather.forecast!.fetchedAt.toLocal())}.',
              style: AppTypography.caption(palette),
            ),
          ],
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
            title: Text(
              'Qué sale en la jornada y en su documento',
              style: label,
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    toggle(
                      'Cielo',
                      options.sky,
                      () => options.copyWith(sky: !options.sky),
                    ),
                    toggle(
                      'Temperatura',
                      options.temperature,
                      () => options.copyWith(temperature: !options.temperature),
                    ),
                    toggle(
                      'Lluvia',
                      options.rain,
                      () => options.copyWith(rain: !options.rain),
                    ),
                    toggle(
                      'Viento',
                      options.wind,
                      () => options.copyWith(wind: !options.wind),
                    ),
                    toggle(
                      'Amanecer y atardecer',
                      options.sun,
                      () => options.copyWith(sun: !options.sun),
                    ),
                    toggle(
                      'Hora azul y dorada',
                      options.blueAndGolden,
                      () => options.copyWith(
                        blueAndGolden: !options.blueAndGolden,
                      ),
                    ),
                    toggle(
                      'Hora a hora',
                      options.hourly,
                      () => options.copyWith(hourly: !options.hourly),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _stamp(DateTime t) =>
      '${t.day}/${t.month} a las ${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';
}

/// Una opción del menú de una línea del orden.
typedef _OrderAction = ({String label, VoidCallback run});

/// Una fila en la vista plano a plano. La fila de escena sin planos que se
/// haya quedado junto a sus planos viaja con el primero.
class _FlatRow {
  final List<int> ids;
  final ShootDocumentBlock block;
  final Shot? shot;

  const _FlatRow(this.ids, this.block, this.shot);
}

/// El orden de rodaje de la jornada: escenas con sus planos y franjas de
/// montaje, comida o cambio de localización. Todo se puede arrastrar; en el
/// menú de cada línea también se sube, se baja y se añade otra franja.
class _DayOrder extends ConsumerStatefulWidget {
  final int projectId;
  final int documentId;
  final List<ShootDocumentBlock> blocks;
  final List<LocationSite> sites;
  final VoidCallback onAdd;

  /// Dentro de una lista con su propio desplazamiento.
  final bool embedded;

  const _DayOrder({
    required this.projectId,
    required this.documentId,
    required this.blocks,
    required this.sites,
    required this.onAdd,
    required this.embedded,
  });

  @override
  ConsumerState<_DayOrder> createState() => _DayOrderState();
}

class _DayOrderState extends ConsumerState<_DayOrder> {
  bool _byScene = true;

  AppDatabase get _db => ref.read(databaseProvider);
  ShootDayScheduleService get _service => ShootDayScheduleService(_db);

  Future<void> _apply(Map<int, Shot> shots, List<int> next) async {
    final undo = await _service.applyOrder(
      widget.documentId,
      widget.blocks,
      next,
      shots,
    );
    if (!mounted) return;
    AppSnackBar.show(
      context,
      'Orden de rodaje cambiado.',
      actionLabel: 'Deshacer',
      onAction: () => undo(),
    );
  }

  /// Quita [removed] de la jornada y deja deshacerlo.
  Future<void> _remove(List<ShootDocumentBlock> removed) async {
    final before = [for (final b in widget.blocks) b.id];
    final db = _db;
    for (final b in removed) {
      await db.deleteShootDocumentBlock(b.id);
    }
    if (!mounted) return;
    final n = removed.length;
    AppSnackBar.show(
      context,
      n == 1 ? 'Quitado de la jornada.' : '$n elementos quitados.',
      actionLabel: 'Deshacer',
      onAction: () async {
        final newIds = <int, int>{};
        for (final b in removed) {
          newIds[b.id] = await db.insertShootDocumentBlock(
            b.toCompanion(false).copyWith(id: const Value.absent()),
          );
        }
        await db.reorderShootDocumentBlocks(widget.documentId, [
          for (final id in before) newIds[id] ?? id,
        ]);
      },
    );
  }

  Future<void> _addStrip({int? beforeBlockId}) async {
    final edit = await showShootStripSheet(context, sites: widget.sites);
    if (edit?.draft case final draft?) {
      await _service.addStrip(
        widget.documentId,
        draft,
        beforeBlockId: beforeBlockId,
      );
    }
  }

  Future<void> _editStrip(ShootDocumentBlock block) async {
    final edit = await showShootStripSheet(
      context,
      block: block,
      sites: widget.sites,
    );
    if (edit == null) return;
    if (edit.draft case final draft?) {
      await _service.updateStrip(block, draft);
    } else {
      await _remove([block]);
    }
  }

  Future<void> _editScene(ShootDocumentBlock first, String title) async {
    final next = await showSceneScheduleSheet(
      context,
      title: title,
      initial: SceneSchedule.of(first),
    );
    if (next != null) await _service.setSceneSchedule(first, next);
  }

  Future<void> _confirmRemoveScene(
    ShootSceneEntry entry,
    Scene? scene,
    int shotCount,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Quitar la escena ${scene?.label ?? '—'} de la jornada'),
        content: Text(
          shotCount == 1
              ? 'Se quita 1 plano de este documento. El plano sigue en el '
                    'guion técnico.'
              : 'Se quitan $shotCount planos de este documento. Siguen en el '
                    'guion técnico.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (ok == true) await _remove(entry.blocks);
  }

  /// Lo común del menú de la línea [i]: añadir franja y mover.
  List<_OrderAction> _commonActions(
    List<ShootDayEntry> entries,
    int i,
    Map<int, Shot> shots,
  ) {
    void move(int to) => _apply(
      shots,
      shootDayOrderOf(moveShootDayEntry(entries, i, to), widget.blocks),
    );
    final after = i + 1 < entries.length ? entries[i + 1].blockIds.first : null;
    return [
      (
        label: 'Franja antes',
        run: () => _addStrip(beforeBlockId: entries[i].blockIds.first),
      ),
      (label: 'Franja después', run: () => _addStrip(beforeBlockId: after)),
      if (i > 0) (label: 'Subir', run: () => move(i - 1)),
      if (i + 1 < entries.length) (label: 'Bajar', run: () => move(i + 1)),
    ];
  }

  Widget _menu(List<_OrderAction> actions) => PopupMenuButton<VoidCallback>(
    tooltip: 'Acciones',
    padding: EdgeInsets.zero,
    iconSize: 18,
    onSelected: (run) => run(),
    itemBuilder: (_) => [
      for (final a in actions)
        PopupMenuItem(value: a.run, child: Text(a.label)),
    ],
  );

  String? _siteNameOf(ShootStrip strip) {
    if (strip.kind != ShootStripKind.move || strip.siteUid == null) return null;
    return widget.sites.where((s) => s.uid == strip.siteUid).firstOrNull?.name;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    return StreamBuilder<List<Scene>>(
      stream: db.watchScenesForProject(widget.projectId),
      builder: (context, sceneSnap) => StreamBuilder<List<Shot>>(
        stream: db.watchShotsForProject(widget.projectId),
        builder: (context, shotSnap) {
          final sceneList = sceneSnap.data ?? const <Scene>[];
          final scenes = {for (final s in sceneList) s.id: s};
          final scenePosition = {
            for (final (i, s) in sceneList.indexed) s.id: i,
          };
          final shots = {
            for (final s in shotSnap.data ?? const <Shot>[]) s.id: s,
          };
          final blocks = widget.blocks;
          final entries = buildShootDayEntries(blocks, shots);
          final sceneCount = entries.whereType<ShootSceneEntry>().length;
          final flat = _flatRows(entries, shots);
          final shotBlocks = [
            for (final b in blocks)
              if (b.blockType == ShootBlockType.shot &&
                  shots.containsKey(b.shotId))
                b,
          ];
          final shotIds = [for (final b in shotBlocks) b.id];
          final byBlock = {for (final b in shotBlocks) b.id: shots[b.shotId]!};
          final inScriptOrder = scriptOrderOf(
            shotIds,
            scenePosition: (id) =>
                scenePosition[byBlock[id]!.sceneId] ?? 1 << 30,
            shotNumber: (id) => byBlock[id]!.number,
          );

          void toScriptOrder() {
            final sorted = inScriptOrder.iterator;
            final positions = shotIds.toSet();
            final all = shootDayOrderOf(entries, blocks);
            _apply(shots, [
              for (final id in all)
                if (positions.contains(id))
                  (sorted..moveNext()).current
                else
                  id,
            ]);
          }

          final list = entries.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Center(
                    child: Text(
                      'La jornada aún no tiene nada en su orden.',
                      style: AppTypography.bodyMedium(palette),
                    ),
                  ),
                )
              : _byScene
              ? SafeReorderableColumn(
                  scrollable: !widget.embedded,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  itemCount: entries.length,
                  keyOf: (i) => ValueKey('linea-${entries[i].blockIds.first}'),
                  dragLabel: (i) => switch (entries[i]) {
                    ShootSceneEntry(:final sceneId) =>
                      'Escena ${scenes[sceneId]?.label ?? '—'}',
                    ShootStripEntry(:final block) => ShootStrip.titleOf(block),
                  },
                  onReorder: (from, to) => _apply(
                    shots,
                    shootDayOrderOf(
                      moveShootDayEntry(entries, from, to),
                      blocks,
                    ),
                  ),
                  itemBuilder: (context, i) =>
                      _entry(entries, i, shots, scenes),
                )
              : SafeReorderableColumn(
                  scrollable: !widget.embedded,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  itemCount: flat.length,
                  keyOf: (i) => ValueKey('fila-${flat[i].block.id}'),
                  dragLabel: (i) => _flatLabel(flat[i], scenes, shots),
                  onReorder: (from, to) {
                    final next = [...flat];
                    next.insert(to, next.removeAt(from));
                    final seen = {for (final r in next) ...r.ids};
                    _apply(shots, [
                      for (final r in next) ...r.ids,
                      for (final b in blocks)
                        if (!seen.contains(b.id)) b.id,
                    ]);
                  },
                  itemBuilder: (context, i) => _flatRow(flat, i, shots, scenes),
                );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: widget.embedded ? MainAxisSize.min : MainAxisSize.max,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Orden de rodaje',
                      style: AppTypography.titleMedium(palette),
                    ),
                    Text(
                      'Arrastra escenas, planos y franjas. Así se ve en el '
                      'plan, en el set y en los documentos.',
                      style: AppTypography.caption(palette),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: widget.onAdd,
                          icon: const Icon(Icons.playlist_add, size: 18),
                          label: const Text('Escenas y planos'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _addStrip,
                          icon: const Icon(Icons.more_time, size: 18),
                          label: const Text('Franja'),
                        ),
                        if (entries.isNotEmpty)
                          SegmentedButton<bool>(
                            showSelectedIcon: false,
                            style: const ButtonStyle(
                              visualDensity: VisualDensity.compact,
                            ),
                            segments: [
                              ButtonSegment(
                                value: true,
                                icon: const Icon(
                                  Icons.view_agenda_outlined,
                                  size: 16,
                                ),
                                label: Text('Escenas ($sceneCount)'),
                              ),
                              ButtonSegment(
                                value: false,
                                icon: const Icon(
                                  Icons.format_list_numbered,
                                  size: 16,
                                ),
                                label: Text('Planos (${shotIds.length})'),
                              ),
                            ],
                            selected: {_byScene},
                            onSelectionChanged: (v) =>
                                setState(() => _byScene = v.first),
                          ),
                        if (shotIds.isNotEmpty)
                          TextButton.icon(
                            onPressed: _sameOrder(shotIds, inScriptOrder)
                                ? null
                                : toScriptOrder,
                            icon: const Icon(Icons.sort, size: 16),
                            label: const Text('Orden de guion'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (widget.embedded) list else Expanded(child: list),
            ],
          );
        },
      ),
    );
  }

  Widget _entry(
    List<ShootDayEntry> entries,
    int i,
    Map<int, Shot> shots,
    Map<int, Scene> scenes,
  ) {
    final common = _commonActions(entries, i, shots);
    switch (entries[i]) {
      case ShootStripEntry(:final block, :final strip):
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: ShootStripCard(
            block: block,
            siteName: _siteNameOf(strip),
            padding: const EdgeInsets.fromLTRB(10, 8, 40, 8),
            trailing: _menu([
              (label: 'Editar', run: () => _editStrip(block)),
              ...common,
              (label: 'Quitar', run: () => _remove([block])),
            ]),
          ),
        );
      case final ShootSceneEntry entry:
        final scene = scenes[entry.sceneId];
        final order = entries.take(i + 1).whereType<ShootSceneEntry>().length;
        final shotBlocks = entry.shotBlocks(shots);
        final title = _sceneTitle(scene);
        return _SceneCard(
          position: order,
          title: title,
          schedule: SceneSchedule.of(entry.blocks.first),
          shots: [for (final b in shotBlocks) shots[b.shotId]!],
          times: [for (final b in shotBlocks) ShotTime.of(b)],
          menu: _menu([
            (
              label: 'Hora y aclaración',
              run: () => _editScene(entry.blocks.first, title),
            ),
            ...common,
            (
              label: 'Quitar de la jornada',
              run: () => _confirmRemoveScene(entry, scene, shotBlocks.length),
            ),
          ]),
        );
    }
  }

  static String _sceneTitle(Scene? scene) => scene == null
      ? 'Escena desconocida'
      : scriptIndexLabel(
          sceneLabel: scene.label,
          intExt: scene.intExt,
          location: scene.locationPureName,
          dayNight: scene.dayNight,
        );

  List<_FlatRow> _flatRows(List<ShootDayEntry> entries, Map<int, Shot> shots) {
    final rows = <_FlatRow>[];
    for (final entry in entries) {
      switch (entry) {
        case ShootStripEntry(:final block):
          rows.add(_FlatRow([block.id], block, null));
        case ShootSceneEntry():
          final withShot = entry.shotBlocks(shots);
          if (withShot.isEmpty) {
            rows.add(_FlatRow(entry.blockIds, entry.blocks.first, null));
            continue;
          }
          final loose = [
            for (final b in entry.blocks)
              if (!shots.containsKey(b.shotId)) b.id,
          ];
          for (final (i, b) in withShot.indexed) {
            rows.add(
              _FlatRow([if (i == 0) ...loose, b.id], b, shots[b.shotId]),
            );
          }
      }
    }
    return rows;
  }

  String _flatLabel(
    _FlatRow row,
    Map<int, Scene> scenes,
    Map<int, Shot> shots,
  ) {
    if (ShootStrip.isStrip(row.block)) return ShootStrip.titleOf(row.block);
    final scene = scenes[shootBlockSceneId(row.block, shots)];
    return row.shot == null
        ? 'Esc. ${scene?.label ?? '—'}'
        : 'Esc. ${scene?.label ?? '—'} · Plano ${row.shot!.number}';
  }

  Widget _flatRow(
    List<_FlatRow> rows,
    int i,
    Map<int, Shot> shots,
    Map<int, Scene> scenes,
  ) {
    final palette = context.palette;
    final row = rows[i];
    if (ShootStrip.isStrip(row.block)) {
      final block = row.block;
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: ShootStripCard(
          block: block,
          siteName: _siteNameOf(ShootStrip.of(block)),
          padding: const EdgeInsets.fromLTRB(10, 8, 40, 8),
          trailing: IconButton(
            tooltip: 'Editar',
            icon: Icon(
              Icons.edit_outlined,
              size: 16,
              color: palette.textSecondary,
            ),
            onPressed: () => _editStrip(block),
          ),
        ),
      );
    }
    final sceneId = shootBlockSceneId(row.block, shots);
    final scene = scenes[sceneId];
    final previous = i == 0
        ? null
        : shootBlockSceneId(rows[i - 1].block, shots);
    final newScene =
        ShootStrip.isStrip(rows[i == 0 ? 0 : i - 1].block) ||
        previous != sceneId ||
        i == 0;
    final removed = [
      for (final id in row.ids) widget.blocks.firstWhere((b) => b.id == id),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (newScene && scene != null)
          Padding(
            padding: EdgeInsets.only(
              top: i == 0 ? 0 : AppSpacing.sm,
              bottom: 4,
            ),
            child: Text(
              '${scene.label}. ${scene.locationCanonical}',
              style: AppTypography.label(
                palette,
              ).copyWith(color: palette.accent),
            ),
          ),
        Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.fromLTRB(8, 6, 40, 6),
          decoration: BoxDecoration(
            color: palette.surfaceElevated,
            border: Border.all(color: palette.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: row.shot == null
              ? Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Escena sin planos todavía',
                        style: AppTypography.caption(palette),
                      ),
                    ),
                    _removeButton(palette, removed),
                  ],
                )
              : ShootShotRow(
                  shot: row.shot!,
                  thumbWidth: 72,
                  time: ShotTime.of(row.block),
                  trailing: [_removeButton(palette, removed)],
                ),
        ),
      ],
    );
  }

  Widget _removeButton(AppPalette palette, List<ShootDocumentBlock> blocks) =>
      IconButton(
        tooltip: 'Quitar de la jornada',
        icon: Icon(Icons.close, size: 16, color: palette.textSecondary),
        onPressed: () => _remove(blocks),
      );

  static bool _sameOrder(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Una escena del orden: su puesto, su hora y sus planos en imagen.
class _SceneCard extends StatelessWidget {
  final int position;
  final String title;
  final SceneSchedule schedule;
  final List<Shot> shots;
  final List<ShotTime> times;
  final Widget menu;

  const _SceneCard({
    required this.position,
    required this.title,
    required this.schedule,
    required this.shots,
    required this.times,
    required this.menu,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final time = shootTimeRange(schedule.from, schedule.to);
    final note = schedule.note.trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(12, 10, 40, 10),
      decoration: BoxDecoration(
        color: palette.surfaceElevated,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$position',
                  style: AppTypography.mono(
                    palette,
                  ).copyWith(color: palette.accent),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.label(
                        palette,
                      ).copyWith(color: palette.textPrimary),
                    ),
                    if (time.isNotEmpty)
                      Text(
                        time,
                        style: AppTypography.caption(
                          palette,
                        ).copyWith(color: palette.accent),
                      ),
                    if (note.isNotEmpty)
                      Text(note, style: AppTypography.caption(palette)),
                  ],
                ),
              ),
              menu,
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (shots.isEmpty)
            Text('Sin planos todavía.', style: AppTypography.caption(palette))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (i, shot) in shots.indexed)
                  ShootShotTile(shot: shot, time: times[i]),
              ],
            ),
        ],
      ),
    );
  }
}
