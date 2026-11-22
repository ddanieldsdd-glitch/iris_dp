import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/pdf_export/rig_sheet_pdf.dart';
import '../../shared/pdf_export/shoot_day_material.dart';
import '../camera_plan/light_sheet_export.dart';
import '../camera_plan/light_sheet_jobs.dart';
import '../camera_plan/plan_elevation_screen.dart';
import '../camera_plan/plan_gear_list.dart';
import '../camera_plan/plan_thumbnail.dart';
import 'light_crew_data.dart';

/// Vista de consulta de los eléctricos (LZ.3), pensada para el móvil: por
/// jornada, las plantas y hojas de luz de cada esquema, lo que consume cada
/// uno y el material de luz del día. No cambia nada del proyecto.
class LightCrewScreen extends ConsumerStatefulWidget {
  final int projectId;
  final String projectName;

  /// Los datos ya cargados (pruebas).
  final LightCrewData? preloaded;

  const LightCrewScreen({
    super.key,
    required this.projectId,
    required this.projectName,
    @visibleForTesting this.preloaded,
  });

  static Future<void> open(BuildContext context, Project project) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              LightCrewScreen(projectId: project.id, projectName: project.name),
        ),
      );

  @override
  ConsumerState<LightCrewScreen> createState() => _LightCrewScreenState();
}

class _LightCrewScreenState extends ConsumerState<LightCrewScreen> {
  late Future<LightCrewData?> _data = widget.preloaded != null
      ? Future.value(widget.preloaded)
      : _load();
  int? _dayIndex;

  Future<LightCrewData?> _load() =>
      LightCrewData.load(ref.read(databaseProvider), widget.projectId);

  /// La jornada de hoy; si no, la próxima; si no, la primera.
  static int initialDay(List<LightCrewDay> days, DateTime now) {
    final today =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    var best = -1;
    String? bestDate;
    for (final (i, d) in days.indexed) {
      final date = d.day?.shootDate;
      if (date == null || date.length < 10) continue;
      final day = date.substring(0, 10);
      if (day.compareTo(today) < 0) continue;
      if (bestDate == null || day.compareTo(bestDate) < 0) {
        best = i;
        bestDate = day;
      }
    }
    return best < 0 ? 0 : best;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.projectName, overflow: TextOverflow.ellipsis),
            Text('Luz · solo consulta', style: AppTypography.caption(palette)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _data = _load()),
          ),
        ],
      ),
      body: FutureBuilder<LightCrewData?>(
        future: _data,
        builder: (context, snap) {
          if (snap.hasError) {
            return _Message('No se pudo cargar la luz: ${snap.error}');
          }
          final data = snap.data;
          if (data == null) {
            return snap.connectionState == ConnectionState.done
                ? const _Message('Este proyecto ya no está en el aparato.')
                : const Center(child: CircularProgressIndicator());
          }
          final index = (_dayIndex ?? initialDay(data.days, DateTime.now()))
              .clamp(0, data.days.length - 1);
          final day = data.days[index];
          final gutter = AppLayout.gutter(context, regular: AppSpacing.xl);
          return Column(
            children: [
              if (data.days.length > 1)
                SizedBox(
                  height: 52,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(
                      horizontal: gutter,
                      vertical: AppSpacing.sm,
                    ),
                    itemCount: data.days.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: AppSpacing.sm),
                    itemBuilder: (_, i) => ChoiceChip(
                      label: Text(data.days[i].title),
                      selected: i == index,
                      onSelected: (_) => setState(() => _dayIndex = i),
                    ),
                  ),
                ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    gutter,
                    AppSpacing.sm,
                    gutter,
                    AppSpacing.xl,
                  ),
                  children: [
                    _DaySummary(day: day),
                    const SizedBox(height: AppSpacing.lg),
                    if (day.schemes.isEmpty)
                      Text(
                        'Ningún plano de esta jornada tiene esquema de luz.',
                        style: AppTypography.bodyMedium(palette),
                      ),
                    for (final scheme in day.schemes) ...[
                      _SchemeCard(
                        scheme: scheme,
                        info: lightSheetJob(
                          data.plan,
                          scheme.use,
                          project: data.project.name,
                        ).info,
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (day.material.lights.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _MaterialList(lines: day.material.lights),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  const _Message(this.text);

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppTypography.bodyMedium(context.palette),
      ),
    ),
  );
}

class _DaySummary extends StatelessWidget {
  final LightCrewDay day;
  const _DaySummary({required this.day});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final heaviest = day.heaviest;
    final lights = day.schemes.fold<int>(0, (n, s) => n + s.lightCount);
    final date = day.day?.shootDate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(day.title, style: AppTypography.titleLarge(palette)),
        if (date != null && date.length >= 10)
          Text(date.substring(0, 10), style: AppTypography.caption(palette)),
        const SizedBox(height: AppSpacing.sm),
        Text(
          [
            '${day.schemes.length} '
                '${day.schemes.length == 1 ? 'esquema' : 'esquemas'}',
            '$lights ${lights == 1 ? 'foco' : 'focos'}',
          ].join(' · '),
          style: AppTypography.bodyMedium(palette),
        ),
        if (heaviest != null && heaviest.watts > 0)
          Text(
            'El más cargado: ${heaviest.name}, '
            '${formatWatts(heaviest.watts)} '
            '(unos ${heaviest.amps.ceil()} A en monofásica)',
            style: AppTypography.bodyMedium(palette),
          ),
      ],
    );
  }
}

class _SchemeCard extends StatelessWidget {
  final LightCrewScheme scheme;
  final RigSheetInfo info;

  const _SchemeCard({required this.scheme, required this.info});

  void _openPlan(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(scheme.name)),
        body: InteractiveViewer(
          maxScale: 8,
          child: Center(child: PlanThumbnail(elements: scheme.elements)),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final place = [
      info.set,
      info.location,
    ].where((s) => s.isNotEmpty).join(' · ');
    return Material(
      color: palette.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.medium,
        side: BorderSide(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => _openPlan(context),
            child: SizedBox(
              height: 200,
              child: Tooltip(
                message: 'Ver la planta en grande',
                child: PlanThumbnail(elements: scheme.elements),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(scheme.name, style: AppTypography.titleMedium(palette)),
                if (place.isNotEmpty)
                  Text(place, style: AppTypography.caption(palette)),
                if (info.scenes.isNotEmpty)
                  Text(info.scenes, style: AppTypography.caption(palette)),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${scheme.lightCount} focos · '
                  '${formatWatts(scheme.watts)} · '
                  'unos ${scheme.amps.ceil()} A',
                  style: AppTypography.bodyMedium(palette),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => showPlanElevation(
                        context,
                        elements: scheme.elements,
                        metersPerUnit: scheme.metersPerUnit,
                        name: scheme.name,
                        sheetInfo: info,
                      ),
                      icon: const Icon(Icons.architecture_outlined),
                      label: const Text('Alzado y perfil'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => showLightSheetExport(
                        context,
                        elements: scheme.elements,
                        metersPerUnit: scheme.metersPerUnit,
                        info: info,
                      ),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Hoja de luz'),
                    ),
                  ],
                ),
                if (scheme.loads.isNotEmpty)
                  Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: EdgeInsets.zero,
                      title: Text(
                        'Focos y consumo',
                        style: AppTypography.label(palette),
                      ),
                      children: [
                        for (final load in scheme.loads)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Text(
                              '${load.unit}',
                              style: AppTypography.label(palette),
                            ),
                            title: Text(load.name),
                            trailing: Text(formatWatts(load.watts)),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterialList extends StatelessWidget {
  final List<MaterialLine> lines;
  const _MaterialList({required this.lines});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    (String, Color)? badge(MaterialStock s) => switch (s) {
      MaterialStock.unchecked => null,
      MaterialStock.reserved => ('Reservado', palette.success),
      MaterialStock.short => ('Falta alguno', palette.warning),
      MaterialStock.missing => ('Sin reservar', palette.error),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Material de luz del día',
          style: AppTypography.titleMedium(palette),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final line in lines)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Text(
              '${line.quantity}×',
              style: AppTypography.label(palette),
            ),
            title: Text(line.name),
            subtitle: line.detail.isEmpty ? null : Text(line.detail),
            trailing: switch (badge(line.stock)) {
              (final text, final color) => Text(
                text,
                style: AppTypography.caption(palette).copyWith(color: color),
              ),
              null => null,
            },
          ),
      ],
    );
  }
}
