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
import '../../shared/technical_script_export/technical_script_docx.dart';
import '../technical_script/technical_script_export.dart';
import '../technical_script/technical_script_settings.dart';
import 'shoot_document_block_types.dart';
import 'shoot_document_script_picker.dart';

/// Tipo de documento de rodaje que es una jornada con su guion técnico.
const kShootDayKind = 'technical_day';

/// De dónde sale la previsión; los tests ponen aquí uno de mentira.
final weatherProviderProvider = Provider<WeatherProvider>(
  (ref) => OpenMeteoWeather(),
);

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

  Future<void> _locate(LocationSite site) async {
    final place = await showDialog<PlaceResult>(
      context: context,
      builder: (_) => _PlaceSearchDialog(initialQuery: site.name),
    );
    if (place == null) return;
    await _db.updateSite(
      site.copyWith(
        latitude: Value(place.latitude),
        longitude: Value(place.longitude),
        placeLabel: Value(place.label),
      ),
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

  Future<void> _export({required bool word}) async {
    try {
      final doc = await buildShootDayScriptDoc(
        _db,
        widget.documentId,
        ref.read(technicalScriptSettingsProvider),
      );
      if (!mounted) return;
      if (doc == null || doc.sections.isEmpty) {
        AppSnackBar.show(context, 'Añade planos a la jornada para exportarla.');
        return;
      }
      final day = await _db.getShootDocument(widget.documentId);
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
      if (!mounted || path == null) return;
      AppSnackBar.show(context, '${word ? 'Word' : 'PDF'} guardado en $path');
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, userFriendlyError(e));
    }
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
              PopupMenuButton<bool>(
                tooltip: 'Exportar la jornada',
                icon: Icon(Icons.ios_share, color: palette.accent),
                color: palette.surfaceElevated,
                onSelected: (word) => _export(word: word),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: false, child: Text('PDF')),
                  PopupMenuItem(value: true, child: Text('Word (.docx)')),
                ],
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
                        'Sin ubicar en el mapa: hace falta para el sol y '
                            'la previsión.',
                    style: AppTypography.caption(palette),
                  ),
                ),
                TextButton(
                  onPressed: () => _locate(site),
                  child: Text(site.latitude == null ? 'Ubicar' : 'Cambiar'),
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

/// Planos de la jornada en su orden de rodaje.
class _OrderList extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    return StreamBuilder<List<Scene>>(
      stream: db.watchScenesForProject(projectId),
      builder: (context, sceneSnap) => StreamBuilder<List<Shot>>(
        stream: db.watchShotsForProject(projectId),
        builder: (context, shotSnap) {
          final scenes = {
            for (final s in sceneSnap.data ?? const <Scene>[]) s.id: s,
          };
          final shots = {
            for (final s in shotSnap.data ?? const <Shot>[]) s.id: s,
          };
          final rows = [
            for (final b in blocks)
              if (shots[b.shotId] != null) b,
          ];

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
                                : 'Arrastra para ordenar. El número de plano '
                                      'es el del guion técnico.',
                            style: AppTypography.caption(palette),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: onAdd,
                      icon: const Icon(Icons.playlist_add, size: 18),
                      label: const Text('Escenas y planos'),
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
                    : SafeReorderableColumn(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        itemCount: rows.length,
                        keyOf: (i) => ValueKey(rows[i].id),
                        dragLabel: (i) {
                          final shot = shots[rows[i].shotId]!;
                          return 'Esc. ${scenes[shot.sceneId]?.number ?? '—'} '
                              '· Plano ${shot.number}';
                        },
                        onReorder: (from, to) {
                          final ids = [for (final b in rows) b.id];
                          ids.insert(to, ids.removeAt(from));
                          db.reorderShootDocumentBlocks(documentId, ids);
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
                                    '${scene.number}. ${scene.locationCanonical}',
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
                                          'Esc. ${scene?.number ?? '—'} · '
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
}

/// Busca un lugar por su nombre para ubicar una localización.
class _PlaceSearchDialog extends ConsumerStatefulWidget {
  final String initialQuery;
  const _PlaceSearchDialog({required this.initialQuery});

  @override
  ConsumerState<_PlaceSearchDialog> createState() => _PlaceSearchDialogState();
}

class _PlaceSearchDialogState extends ConsumerState<_PlaceSearchDialog> {
  final _query = TextEditingController();
  List<PlaceResult> _results = const [];
  bool _searching = false;
  String? _notice;

  @override
  void initState() {
    super.initState();
    // El nombre de la localización suele ser un lugar; sirve de partida.
    _query.text = widget.initialQuery;
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final text = _query.text.trim();
    if (text.length < 2 || _searching) return;
    setState(() {
      _searching = true;
      _notice = null;
    });
    try {
      final results = await ref
          .read(weatherProviderProvider)
          .searchPlaces(text);
      if (!mounted) return;
      setState(() {
        _results = results;
        _notice = results.isEmpty ? 'No se ha encontrado ese lugar.' : null;
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => _notice =
              'No se pudo buscar. Comprueba la conexión. '
              '${userFriendlyError(e)}',
        );
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AlertDialog(
      backgroundColor: palette.surfaceElevated,
      title: Text(
        '¿Dónde está la localización?',
        style: AppTypography.titleMedium(palette),
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Escribe la ciudad o el pueblo. Sirve para calcular el sol y '
              'pedir la previsión.',
              style: AppTypography.caption(palette),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _query,
              autofocus: true,
              style: AppTypography.bodyLarge(palette),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Ej. Barcelona',
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        tooltip: 'Buscar',
                        icon: const Icon(Icons.search, size: 18),
                        onPressed: _search,
                      ),
              ),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_notice != null)
              Text(_notice!, style: AppTypography.bodyMedium(palette)),
            SizedBox(
              height: 240,
              child: ListView(
                children: [
                  for (final place in _results)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.place_outlined, size: 18),
                      title: Text(place.label),
                      onTap: () => Navigator.pop(context, place),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar', style: AppTypography.bodyMedium(palette)),
        ),
      ],
    );
  }
}
