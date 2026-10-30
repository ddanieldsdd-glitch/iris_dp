import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/user_error.dart';
import '../../core/weather/weather_models.dart';
import '../../core/weather/weather_service.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/safe_reorderable_column.dart';
import '../../shared/pdf_export/technical_script_pdf.dart';
import '../../shared/rich_text/script_markup.dart';
import '../../shared/technical_script_export/technical_script_doc.dart';
import '../../shared/technical_script_export/technical_script_docx.dart';
import '../locations/locations_screen.dart';
import '../technical_script/script_export_dialog.dart';
import '../technical_script/technical_script_export.dart';
import '../technical_script/technical_script_settings.dart';
import 'shoot_day_order.dart';
import 'shoot_document_block_types.dart';
import 'shoot_document_script_picker.dart';

/// Tipo de documento de rodaje que es una jornada con su guion técnico.
const kShootDayKind = 'technical_day';

/// Exporta el guion técnico de la jornada [documentId] a PDF o Word, con o
/// sin índice, y avisa de dónde se guardó.
Future<void> exportShootDayDocument(
  BuildContext context,
  AppDatabase db,
  TechnicalScriptSettings settings,
  int documentId,
  ScriptExportChoice choice,
) async {
  final word = choice.word;
  try {
    final doc = (await buildShootDayScriptDoc(
      db,
      documentId,
      settings,
    ))?.copyWith(includeIndex: choice.index);
    if (!context.mounted) return;
    if (doc == null || doc.sections.isEmpty) {
      AppSnackBar.show(context, 'Añade planos a la jornada para exportarla.');
      return;
    }
    final day = await db.getShootDocument(documentId);
    final name = (day?.name ?? 'jornada')
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim();
    final fileName = name.isEmpty ? 'jornada' : name;
    final path = word
        ? await TechnicalScriptDocxExporter.exportAndSave(
            doc,
            fileName: fileName,
          )
        : await TechnicalScriptPdfExporter.exportAndSave(
            doc,
            fileName: fileName,
          );
    if (!context.mounted || path == null) return;
    AppSnackBar.show(context, '${word ? 'Word' : 'PDF'} guardado en $path');
  } catch (e) {
    if (context.mounted) AppSnackBar.showError(context, userFriendlyError(e));
  }
}

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
    final raw = from ? day.shootFromTime : day.shootToTime;
    final parts = (raw ?? (from ? '08:00' : '18:00')).split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 8,
        minute: int.tryParse(parts.last) ?? 0,
      ),
      helpText: from ? 'Se rueda desde' : 'Se rueda hasta',
    );
    if (picked == null) return;
    final value =
        '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';
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

  Future<void> _export() async {
    final choice = await showScriptExportDialog(
      context,
      title: 'Exportar la jornada',
    );
    if (choice == null || !mounted) return;
    await exportShootDayDocument(
      context,
      _db,
      ref.read(technicalScriptSettingsProvider),
      widget.documentId,
      choice,
    );
  }

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
            actions: [
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
                  final blocks = <ShootDocumentBlock>[
                    for (final b
                        in blockSnap.data ?? const <ShootDocumentBlock>[])
                      if (b.blockType == ShootBlockType.shot &&
                          b.shotId != null)
                        b,
                  ];
                  final header = _header(day, sites, site, palette);
                  final order = _OrderList(
                    projectId: widget.projectId,
                    documentId: widget.documentId,
                    blocks: blocks,
                    onAdd: () => _addFromScript(blocks),
                  );
                  return LayoutBuilder(
                    builder: (context, constraints) =>
                        constraints.maxWidth < 900
                        ? ListView(
                            children: [
                              header,
                              const Divider(height: 1),
                              SizedBox(height: 600, child: order),
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 400,
                                child: SingleChildScrollView(child: header),
                              ),
                              VerticalDivider(width: 1, color: palette.divider),
                              Expanded(child: order),
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
            Row(
              children: [
                Icon(
                  site.latitude == null
                      ? Icons.location_off_outlined
                      : Icons.place_outlined,
                  size: 16,
                  color: palette.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    site.placeLabel ??
                        'Sin ubicar en el mapa. Se fija en Localizaciones; '
                            'hace falta para el sol y la previsión.',
                    style: AppTypography.caption(palette),
                  ),
                ),
                if (site.latitude == null)
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LocationsScreen(
                          projectId: widget.projectId,
                          initialSiteId: site.id,
                        ),
                      ),
                    ),
                    child: const Text('Abrir localización'),
                  ),
              ],
            ),
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
          const SizedBox(height: AppSpacing.md),
          Text('Qué sale en la jornada y en su documento', style: label),
          const SizedBox(height: 6),
          Wrap(
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
                () => options.copyWith(blueAndGolden: !options.blueAndGolden),
              ),
              toggle(
                'Hora a hora',
                options.hourly,
                () => options.copyWith(hourly: !options.hourly),
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

/// Planos de la jornada en su orden de rodaje. Se ordena por escenas (cada
/// tramo seguido de una escena se mueve entero, y cada tarjeta es la línea
/// que tendrá en el índice del documento) o plano a plano.
class _OrderList extends ConsumerStatefulWidget {
  final int projectId;
  final int documentId;
  final List<ShootDocumentBlock> blocks;
  final VoidCallback onAdd;

  const _OrderList({
    required this.projectId,
    required this.documentId,
    required this.blocks,
    required this.onAdd,
  });

  @override
  ConsumerState<_OrderList> createState() => _OrderListState();
}

class _OrderListState extends ConsumerState<_OrderList> {
  bool _byScene = true;

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
          final rows = [
            for (final b in widget.blocks)
              if (shots[b.shotId] != null) b,
          ];
          final shotOfBlock = {for (final b in rows) b.id: shots[b.shotId]!};
          final ids = [for (final b in rows) b.id];
          final tracts = groupShootTracts(
            ids,
            (id) => shotOfBlock[id]!.sceneId,
          );

          void reorder(List<int> next) =>
              db.reorderShootDocumentBlocks(widget.documentId, next);

          final inScriptOrder = scriptOrderOf(
            ids,
            scenePosition: (id) =>
                scenePosition[shotOfBlock[id]!.sceneId] ?? 1 << 30,
            shotNumber: (id) => shotOfBlock[id]!.number,
          );
          final isScriptOrder = _sameOrder(ids, inScriptOrder);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Orden de rodaje',
                            style: AppTypography.titleMedium(palette),
                          ),
                          Text(
                            rows.isEmpty
                                ? 'Elige las escenas y planos que se ruedan '
                                      'este día.'
                                : _byScene
                                ? 'Arrastra las escenas para ordenarlas. Así '
                                      'sale el índice del documento.'
                                : 'Arrastra los planos para ordenarlos. El '
                                      'número de plano es el del guion técnico.',
                            style: AppTypography.caption(palette),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: widget.onAdd,
                      icon: const Icon(Icons.playlist_add, size: 18),
                      label: const Text('Escenas y planos'),
                    ),
                  ],
                ),
              ),
              if (rows.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SegmentedButton<bool>(
                        showSelectedIcon: false,
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                        ),
                        segments: [
                          ButtonSegment(
                            value: true,
                            icon: const Icon(Icons.view_agenda_outlined, size: 16),
                            label: Text('Escenas (${tracts.length})'),
                          ),
                          ButtonSegment(
                            value: false,
                            icon: const Icon(Icons.format_list_numbered, size: 16),
                            label: Text('Planos (${rows.length})'),
                          ),
                        ],
                        selected: {_byScene},
                        onSelectionChanged: (v) =>
                            setState(() => _byScene = v.first),
                      ),
                      TextButton.icon(
                        onPressed: isScriptOrder
                            ? null
                            : () => reorder(inScriptOrder),
                        icon: const Icon(Icons.sort, size: 16),
                        label: const Text('Orden de guion'),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: rows.isEmpty
                    ? Center(
                        child: Text(
                          'La jornada aún no tiene planos.',
                          style: AppTypography.bodyMedium(palette),
                        ),
                      )
                    : _byScene
                    ? SafeReorderableColumn(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        itemCount: tracts.length,
                        keyOf: (i) => ValueKey('tract-${tracts[i].blockIds.first}'),
                        dragLabel: (i) =>
                            'Escena ${scenes[tracts[i].sceneId]?.label ?? '—'}',
                        onReorder: (from, to) =>
                            reorder(moveShootTract(tracts, from, to)),
                        itemBuilder: (context, i) => _TractCard(
                          position: i + 1,
                          scene: scenes[tracts[i].sceneId],
                          shots: [
                            for (final id in tracts[i].blockIds)
                              shotOfBlock[id]!,
                          ],
                          onRemove: () async {
                            final tract = tracts[i];
                            final n = tract.blockIds.length;
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text(
                                  'Quitar la escena '
                                  '${scenes[tract.sceneId]?.label ?? '—'} '
                                  'de la jornada',
                                ),
                                content: Text(
                                  n == 1
                                      ? 'Se quita 1 plano de este documento. '
                                          'El plano sigue en el guion técnico.'
                                      : 'Se quitan $n planos de este '
                                          'documento. Siguen en el guion '
                                          'técnico.',
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
                            if (ok != true) return;
                            for (final id in tract.blockIds) {
                              await db.deleteShootDocumentBlock(id);
                            }
                          },
                        ),
                      )
                    : SafeReorderableColumn(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        itemCount: rows.length,
                        keyOf: (i) => ValueKey(rows[i].id),
                        dragLabel: (i) {
                          final shot = shots[rows[i].shotId]!;
                          return 'Esc. ${scenes[shot.sceneId]?.label ?? '—'} '
                              '· Plano ${shot.number}';
                        },
                        onReorder: (from, to) {
                          final next = [...ids];
                          next.insert(to, next.removeAt(from));
                          reorder(next);
                        },
                        itemBuilder: (context, i) {
                          final shot = shots[rows[i].shotId]!;
                          final scene = scenes[shot.sceneId];
                          final framing = scriptMarkupToPlain(
                            shot.framing,
                          ).trim();
                          // La escena se nombra cuando cambia respecto al
                          // plano anterior.
                          final previous = i == 0
                              ? null
                              : shots[rows[i - 1].shotId];
                          final newScene = previous?.sceneId != shot.sceneId;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (newScene && scene != null)
                                Padding(
                                  padding: EdgeInsets.only(
                                    top: i == 0 ? 0 : AppSpacing.md,
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
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  8,
                                  48,
                                  8,
                                ),
                                decoration: BoxDecoration(
                                  color: palette.surfaceElevated,
                                  border: Border.all(color: palette.border),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 34,
                                      child: Text(
                                        '${i + 1}',
                                        style: AppTypography.mono(
                                          palette,
                                        ).copyWith(color: palette.accent),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        [
                                          'Esc. ${scene?.label ?? '—'} · '
                                              'Plano ${shot.number}',
                                          if (framing.isNotEmpty) framing,
                                        ].join(' · '),
                                        style: AppTypography.bodyMedium(
                                          palette,
                                        ).copyWith(color: palette.textPrimary),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Quitar de la jornada',
                                      icon: Icon(
                                        Icons.close,
                                        size: 16,
                                        color: palette.textSecondary,
                                      ),
                                      onPressed: () => db
                                          .deleteShootDocumentBlock(rows[i].id),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  static bool _sameOrder(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Tarjeta de un tramo de escena: su puesto, la línea que tendrá en el
/// índice y sus planos.
class _TractCard extends StatelessWidget {
  final int position;
  final Scene? scene;
  final List<Shot> shots;
  final VoidCallback onRemove;

  const _TractCard({
    required this.position,
    required this.scene,
    required this.shots,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final scene = this.scene;
    final title = scene == null
        ? 'Escena desconocida'
        : scriptIndexLabel(
            sceneLabel: scene.label,
            intExt: scene.intExt,
            location: scene.locationPureName,
            dayNight: scene.dayNight,
          );
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(12, 10, 48, 10),
      decoration: BoxDecoration(
        color: palette.surfaceElevated,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
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
          const SizedBox(width: 12),
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
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final shot in shots)
                      Tooltip(
                        message: scriptMarkupToPlain(shot.framing).trim(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: palette.border),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Plano ${shot.number}',
                            style: AppTypography.caption(palette),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Quitar la escena de la jornada',
            icon: Icon(Icons.close, size: 16, color: palette.textSecondary),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
