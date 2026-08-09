import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../equipment/widgets/equipment_picker.dart';
import '../../../../shared/visual_bible/bible_optics_context.dart';
import '../../../../shared/visual_bible/format_pilot_resolve.dart';
import '../../moodboard_helpers.dart';
import '../../visual_bible_model.dart';
import '../bible_form_widgets.dart';
import '../bible_moodboard_image_target.dart';
import 'section_scaffold.dart';

/// Óptica — layout Stitch (hero lente + filtración + specs + mantenimiento).
class OpticsSection extends ConsumerStatefulWidget {
  final VisualBibleData data;
  final int projectId;
  final String? sectionContentJson;
  final String? formatSectionContentJson;
  final BibleChanged onChanged;

  const OpticsSection({
    super.key,
    required this.data,
    required this.projectId,
    this.sectionContentJson,
    this.formatSectionContentJson,
    required this.onChanged,
  });

  @override
  ConsumerState<OpticsSection> createState() => _OpticsSectionState();
}

class _OpticsSectionState extends ConsumerState<OpticsSection> {
  Map<String, dynamic> _getConfig() {
    final jsonStr = widget.data.opticsConfigJson;
    if (jsonStr == null || jsonStr.isEmpty) return {};
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return {};
  }

  void _updateConfig(Map<String, dynamic> patch) {
    final current = _getConfig();
    current.addAll(patch);
    widget.data.opticsConfigJson = jsonEncode(current);
    widget.onChanged(widget.data);
    setState(() {});
  }

  List<Map<String, dynamic>> _list(String key) {
    final raw = _getConfig()[key];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  double _densityProgress(String density) {
    final d = density.toLowerCase().trim();
    if (d.contains('1/16')) return 0.12;
    if (d.contains('1/8')) return 0.25;
    if (d.contains('1/4')) return 0.5;
    if (d.contains('1/2')) return 0.75;
    if (d.contains('1') && !d.contains('/')) return 1.0;
    if (d.contains('-') || d.contains('–')) return 1.0;
    return 0.4;
  }

  bool _isHeavyDistortion(String d) {
    final t = d.toLowerCase();
    return t.contains('heavy') || t.contains('fuerte') || t.contains('alto');
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final data = widget.data;
    final config = _getConfig();
    final formatBlob =
        FormatPilotResolve.parseBlob(widget.formatSectionContentJson);
    final aspectForOptics = FormatPilotResolve.activeRatio(formatBlob, data);

    final styleSubtitle =
        config['styleSubtitle'] as String? ?? 'Minimalist Character';
    final setName = config['primarySetName'] as String? ?? '';
    final tStop = config['tStop'] as String? ?? 'T2.0';
    final squeeze = config['squeeze'] as String? ??
        (data.opticType?.toLowerCase().contains('anam') == true
            ? '2x Squeeze'
            : data.opticType ?? 'Spherical');
    final bokeh = config['bokehCharacteristic'] as String? ?? '';
    final flare = config['flareBehavior'] as String? ?? '';

    var filtration = _list('filtrationStack');
    if (filtration.isEmpty) {
      filtration = [
        {
          'name': 'Tiffen Black Pro-Mist',
          'density': '1/8',
          'justification':
              'Base level diffusion for digital edge reduction without halation blowing out.',
        },
        {
          'name': 'Hollywood Black Magic',
          'density': '1/4',
          'justification':
              'Reserved for close-ups to soften skin tones while maintaining eye contrast.',
        },
        {
          'name': 'FSND Rotation',
          'density': '0.3 - 2.1',
          'justification':
              'Strict adherence to internal IRND to prevent color shift.',
          'muted': true,
        },
      ];
    }

    var specs = _list('anamorphicSpecs');
    if (specs.isEmpty && data.primaryFocalLengths.isNotEmpty) {
      specs = data.primaryFocalLengths
          .map((f) => {
                'focalLength': '${f}mm',
                'tStop': tStop,
                'cfd': '—',
                'distortion': '—',
              })
          .toList();
    }

    final maintenance = _list('maintenanceLog');
    final lensSets = BibleOpticsContext.lensSetsFromJson(data.opticsConfigJson);

    return BibleSectionScaffold(
      sectionId: BibleSectionId.optics,
      projectId: widget.projectId,
      data: data,
      onChanged: widget.onChanged,
      sectionContentJson: widget.sectionContentJson,
      narrativeHint:
          '¿Por qué esta lente y este T-stop? Qué queremos contar con este carácter óptico…',
      sectionNumber: null,
      sectionTitle: 'Óptica',
      fieldWidgets: {
        'narrative': _OpticsHeader(
          subtitle: styleSubtitle,
          narrative: data.opticsNarrativeIntent ?? data.lensPhilosophy ?? '',
          palette: palette,
          onEditSubtitle: () async {
            final c = TextEditingController(text: styleSubtitle);
            final v = await _prompt(context, 'Estilo / subtítulo', c);
            if (v != null) _updateConfig({'styleSubtitle': v});
          },
          onNarrativeChanged: (v) {
            data.opticsNarrativeIntent = v;
            data.lensPhilosophy = v;
            widget.onChanged(data);
          },
        ),
        'opticSettings': LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1000;
            final mid = constraints.maxWidth >= 700;
            final db = ref.read(databaseProvider);

            return FutureBuilder<Lense?>(
              future: db.resolveProjectLens(widget.projectId),
              builder: (context, lensSnap) {
                final opticsCtx = BibleOpticsContext.resolve(
                  primaryLens: lensSnap.data,
                  opticType: data.opticType,
                  aspectRatio: aspectForOptics,
                  opticsConfig: config,
                  formatData: formatBlob,
                );
                final showAnamorphic = opticsCtx.isAnamorphic;

            final hero = _PrimaryLensHero(
              projectId: widget.projectId,
              data: data,
              setName: setName,
              tStop: tStop,
              squeeze: squeeze,
              bokeh: bokeh,
              flare: flare,
              palette: palette,
              onEditMeta: () async {
                final nameC = TextEditingController(text: setName);
                final tC = TextEditingController(text: tStop);
                final sC = TextEditingController(text: squeeze);
                final bC = TextEditingController(text: bokeh);
                final fC = TextEditingController(text: flare);
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Primary Set'),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          EquipmentPicker(
                            projectId: widget.projectId,
                            equipmentType: 'lens',
                            label: 'Lente principal',
                            selectedId: data.primaryLensId,
                            onSelected: (id) {
                              data.primaryLensId = id;
                              widget.onChanged(data);
                            },
                          ),
                          TextField(
                            controller: nameC,
                            decoration: const InputDecoration(
                              labelText: 'Nombre del set',
                            ),
                          ),
                          TextField(
                            controller: tC,
                            decoration:
                                const InputDecoration(labelText: 'T-Stop'),
                          ),
                          TextField(
                            controller: sC,
                            decoration: const InputDecoration(
                              labelText: 'Squeeze / tipo',
                            ),
                          ),
                          TextField(
                            controller: bC,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Bokeh Characteristic',
                            ),
                          ),
                          TextField(
                            controller: fC,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Flare Behavior',
                            ),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancelar'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Guardar'),
                      ),
                    ],
                  ),
                );
                if (ok != true) return;
                _updateConfig({
                  'primarySetName': nameC.text.trim(),
                  'tStop': tC.text.trim(),
                  'squeeze': sC.text.trim(),
                  'bokehCharacteristic': bC.text.trim(),
                  'flareBehavior': fC.text.trim(),
                });
                if (sC.text.trim().isNotEmpty) {
                  data.opticType = sC.text.trim();
                  widget.onChanged(data);
                }
              },
            );

            final filtrationCard = _GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.filter_b_and_w, color: palette.accent, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'Filtration Stack',
                        style: AppTypography.titleMedium(palette)
                            .copyWith(fontSize: 18),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () async {
                          final edited = await _editFilter(context, {});
                          if (edited == null) return;
                          _updateConfig({
                            'filtrationStack': [...filtration, edited],
                          });
                        },
                        icon: Icon(Icons.add, color: palette.accent, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < filtration.length; i++) ...[
                    if (i > 0) const SizedBox(height: 18),
                    _FilterRow(
                      name: filtration[i]['name']?.toString() ?? 'Filtro',
                      density: filtration[i]['density']?.toString() ?? '—',
                      note: filtration[i]['justification']?.toString() ?? '',
                      progress: _densityProgress(
                        filtration[i]['density']?.toString() ?? '',
                      ),
                      muted: filtration[i]['muted'] == true,
                      palette: palette,
                      onEdit: () async {
                        final edited =
                            await _editFilter(context, filtration[i]);
                        if (edited == null) return;
                        final next =
                            List<Map<String, dynamic>>.from(filtration);
                        next[i] = edited;
                        _updateConfig({'filtrationStack': next});
                      },
                      onDelete: () {
                        final next =
                            List<Map<String, dynamic>>.from(filtration)
                              ..removeAt(i);
                        _updateConfig({'filtrationStack': next});
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  BibleTextField(
                    label: '',
                    hint: 'Notas de filtración…',
                    maxLines: 2,
                    initialValue: data.filtrationNotes ?? '',
                    onChanged: (v) {
                      data.filtrationNotes = v;
                      widget.onChanged(data);
                    },
                  ),
                ],
              ),
            );

            final specsCard = _GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.straighten, color: palette.textTertiary, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'Anamorphic Specifics',
                        style: AppTypography.titleMedium(palette)
                            .copyWith(fontSize: 18),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          final edited = await _editSpec(context, {});
                          if (edited == null) return;
                          _updateConfig({
                            'anamorphicSpecs': [...specs, edited],
                          });
                        },
                        child: Text(
                          'Añadir',
                          style: TextStyle(color: palette.accent, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (specs.isEmpty)
                    Text(
                      'Añade focals del set (32mm, 40mm…)',
                      style: AppTypography.bodyMedium(palette).copyWith(
                        color: palette.textTertiary,
                      ),
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth > 400
                              ? (wide
                                  ? constraints.maxWidth * 0.45
                                  : constraints.maxWidth - 40)
                              : 360,
                        ),
                        child: Table(
                          columnWidths: const {
                            0: FlexColumnWidth(1.2),
                            1: FlexColumnWidth(1),
                            2: FlexColumnWidth(1),
                            3: FlexColumnWidth(1.4),
                          },
                          children: [
                            TableRow(
                              children: [
                                _th('Focal Length', palette),
                                _th('T-Stop', palette),
                                _th('CFD', palette),
                                _th('Distortion', palette),
                              ],
                            ),
                            for (var i = 0; i < specs.length; i++)
                              TableRow(
                                children: [
                                  _td(
                                    specs[i]['focalLength']?.toString() ?? '—',
                                    palette,
                                    primary: true,
                                    onTap: () async {
                                      final edited =
                                          await _editSpec(context, specs[i]);
                                      if (edited == null) return;
                                      final next = List<
                                          Map<String, dynamic>>.from(specs);
                                      next[i] = edited;
                                      _updateConfig(
                                        {'anamorphicSpecs': next},
                                      );
                                    },
                                  ),
                                  _td(
                                    specs[i]['tStop']?.toString() ?? '—',
                                    palette,
                                    onTap: () async {
                                      final edited =
                                          await _editSpec(context, specs[i]);
                                      if (edited == null) return;
                                      final next = List<
                                          Map<String, dynamic>>.from(specs);
                                      next[i] = edited;
                                      _updateConfig(
                                        {'anamorphicSpecs': next},
                                      );
                                    },
                                  ),
                                  _td(
                                    specs[i]['cfd']?.toString() ?? '—',
                                    palette,
                                    onTap: () async {
                                      final edited =
                                          await _editSpec(context, specs[i]);
                                      if (edited == null) return;
                                      final next = List<
                                          Map<String, dynamic>>.from(specs);
                                      next[i] = edited;
                                      _updateConfig(
                                        {'anamorphicSpecs': next},
                                      );
                                    },
                                  ),
                                  _td(
                                    specs[i]['distortion']?.toString() ?? '—',
                                    palette,
                                    danger: _isHeavyDistortion(
                                      specs[i]['distortion']?.toString() ?? '',
                                    ),
                                    onTap: () async {
                                      final edited =
                                          await _editSpec(context, specs[i]);
                                      if (edited == null) return;
                                      final next = List<
                                          Map<String, dynamic>>.from(specs);
                                      next[i] = edited;
                                      _updateConfig(
                                        {'anamorphicSpecs': next},
                                      );
                                    },
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );

            final maintenanceCard = _GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.build_outlined,
                          color: palette.textTertiary, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'Maintenance Log',
                        style: AppTypography.titleMedium(palette)
                            .copyWith(fontSize: 18),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          final edited = await _editMaintenance(context, {});
                          if (edited == null) return;
                          _updateConfig({
                            'maintenanceLog': [edited, ...maintenance],
                          });
                        },
                        child: Text(
                          'Add Entry',
                          style: AppTypography.mono(palette).copyWith(
                            fontSize: 12,
                            color: palette.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (maintenance.isEmpty)
                    Text(
                      'Sin entradas aún.',
                      style: AppTypography.bodyMedium(palette).copyWith(
                        color: palette.textTertiary,
                      ),
                    )
                  else
                    for (var i = 0; i < maintenance.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      _MaintenanceEntry(
                        title: maintenance[i]['title']?.toString() ??
                            maintenance[i]['description']?.toString() ??
                            'Entry',
                        date: maintenance[i]['date']?.toString() ?? '',
                        body: maintenance[i]['description']?.toString() ??
                            maintenance[i]['body']?.toString() ??
                            '',
                        icon: maintenance[i]['icon']?.toString() == 'clean'
                            ? Icons.cleaning_services_outlined
                            : Icons.check,
                        palette: palette,
                        showLine: i < maintenance.length - 1,
                        onEdit: () async {
                          final edited =
                              await _editMaintenance(context, maintenance[i]);
                          if (edited == null) return;
                          final next =
                              List<Map<String, dynamic>>.from(maintenance);
                          next[i] = edited;
                          _updateConfig({'maintenanceLog': next});
                        },
                        onDelete: () {
                          final next =
                              List<Map<String, dynamic>>.from(maintenance)
                                ..removeAt(i);
                          _updateConfig({'maintenanceLog': next});
                        },
                      ),
                    ],
                ],
              ),
            );

            final lensSetsPanel = _LensSetsPanel(
              lensSets: lensSets,
              palette: palette,
              onChanged: (sets) => _updateConfig({'lensSets': sets}),
            );

            if (wide) {
              return Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 8, child: hero),
                      const SizedBox(width: 16),
                      Expanded(flex: 4, child: filtrationCard),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (showAnamorphic)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: specsCard),
                        const SizedBox(width: 16),
                        Expanded(child: maintenanceCard),
                      ],
                    )
                  else
                    maintenanceCard,
                  const SizedBox(height: 16),
                  lensSetsPanel,
                ],
              );
            }

            if (mid) {
              return Column(
                children: [
                  hero,
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: filtrationCard),
                      if (showAnamorphic) ...[
                        const SizedBox(width: 16),
                        Expanded(child: specsCard),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  maintenanceCard,
                  const SizedBox(height: 16),
                  lensSetsPanel,
                ],
              );
            }

            return Column(
              children: [
                hero,
                const SizedBox(height: 16),
                filtrationCard,
                if (showAnamorphic) ...[
                  const SizedBox(height: 16),
                  specsCard,
                ],
                const SizedBox(height: 16),
                maintenanceCard,
                const SizedBox(height: 16),
                lensSetsPanel,
              ],
            );
              },
            );
          },
        ),
      },
    );
  }

  Widget _th(String label, AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.label(palette).copyWith(
          fontSize: 10,
          letterSpacing: 1.1,
          color: palette.textTertiary,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _td(
    String value,
    AppPalette palette, {
    bool primary = false,
    bool danger = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          value,
          style: AppTypography.mono(palette).copyWith(
            fontSize: 13,
            color: danger
                ? const Color(0xFFFFB4AB)
                : primary
                    ? palette.textPrimary
                    : palette.textSecondary,
          ),
        ),
      ),
    );
  }

  Future<String?> _prompt(
    BuildContext context,
    String title,
    TextEditingController c,
  ) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _editFilter(
    BuildContext context,
    Map<String, dynamic> initial,
  ) async {
    final name =
        TextEditingController(text: initial['name']?.toString() ?? '');
    final density =
        TextEditingController(text: initial['density']?.toString() ?? '');
    final note = TextEditingController(
      text: initial['justification']?.toString() ?? '',
    );
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Filtro'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            TextField(
              controller: density,
              decoration: const InputDecoration(labelText: 'Densidad (1/8)'),
            ),
            TextField(
              controller: note,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notas'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, {
              'name': name.text.trim(),
              'density': density.text.trim(),
              'justification': note.text.trim(),
              'muted': initial['muted'] == true,
            }),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _editSpec(
    BuildContext context,
    Map<String, dynamic> initial,
  ) async {
    final focal =
        TextEditingController(text: initial['focalLength']?.toString() ?? '');
    final tStop =
        TextEditingController(text: initial['tStop']?.toString() ?? 'T2.0');
    final cfd = TextEditingController(text: initial['cfd']?.toString() ?? '');
    final dist =
        TextEditingController(text: initial['distortion']?.toString() ?? '');
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Spec óptica'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: focal,
              decoration: const InputDecoration(labelText: 'Focal'),
            ),
            TextField(
              controller: tStop,
              decoration: const InputDecoration(labelText: 'T-Stop'),
            ),
            TextField(
              controller: cfd,
              decoration: const InputDecoration(labelText: 'CFD'),
            ),
            TextField(
              controller: dist,
              decoration: const InputDecoration(labelText: 'Distortion'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, {
              'focalLength': focal.text.trim(),
              'tStop': tStop.text.trim(),
              'cfd': cfd.text.trim(),
              'distortion': dist.text.trim(),
            }),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _editMaintenance(
    BuildContext context,
    Map<String, dynamic> initial,
  ) async {
    final title = TextEditingController(
      text: initial['title']?.toString() ?? '',
    );
    final date = TextEditingController(
      text: initial['date']?.toString() ??
          '${DateTime.now().month}/${DateTime.now().day}/${DateTime.now().year}',
    );
    final body = TextEditingController(
      text: initial['description']?.toString() ??
          initial['body']?.toString() ??
          '',
    );
    var icon = initial['icon']?.toString() ?? 'check';
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Maintenance entry'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Título'),
              ),
              TextField(
                controller: date,
                decoration: const InputDecoration(labelText: 'Fecha'),
              ),
              TextField(
                controller: body,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Descripción'),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'check', label: Text('Check')),
                  ButtonSegment(value: 'clean', label: Text('Clean')),
                ],
                selected: {icon},
                onSelectionChanged: (s) => setLocal(() => icon = s.first),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, {
                'title': title.text.trim(),
                'date': date.text.trim(),
                'description': body.text.trim(),
                'icon': icon,
                'status': 'ok',
              }),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpticsHeader extends StatelessWidget {
  final String subtitle;
  final String narrative;
  final AppPalette palette;
  final VoidCallback onEditSubtitle;
  final ValueChanged<String> onNarrativeChanged;

  const _OpticsHeader({
    required this.subtitle,
    required this.narrative,
    required this.palette,
    required this.onEditSubtitle,
    required this.onNarrativeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 10,
          children: [
            Text(
              'Óptica',
              style: AppTypography.displayMedium(palette).copyWith(
                fontSize: 40,
                letterSpacing: -0.8,
              ),
            ),
            InkWell(
              onTap: onEditSubtitle,
              child: Text(
                '/ $subtitle',
                style: AppTypography.displayMedium(palette).copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w400,
                  color: palette.textTertiary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        BibleTextField(
          label: '',
          hint:
              'Definir la textura visual mediante selección de lentes y filtración…',
          maxLines: 3,
          initialValue: narrative,
          onChanged: onNarrativeChanged,
        ),
      ],
    );
  }
}

class _PrimaryLensHero extends ConsumerWidget {
  final int projectId;
  final VisualBibleData data;
  final String setName;
  final String tStop;
  final String squeeze;
  final String bokeh;
  final String flare;
  final AppPalette palette;
  final VoidCallback onEditMeta;

  const _PrimaryLensHero({
    required this.projectId,
    required this.data,
    required this.setName,
    required this.tStop,
    required this.squeeze,
    required this.bokeh,
    required this.flare,
    required this.palette,
    required this.onEditMeta,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);

    return _GlassPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BibleMoodboardImageTarget(
            projectId: projectId,
            sectionId: BibleSectionId.optics,
            bibleId: data.id,
            hint: 'Clic aquí → ⌘V para pegar hero de óptica',
            child: SizedBox(
              height: 240,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  StreamBuilder<List<Lense>>(
                  stream: db.watchAllLenses(),
                  builder: (context, snap) {
                    final lenses = snap.data ?? [];
                    Lense? selected;
                    if (data.primaryLensId != null) {
                      for (final l in lenses) {
                        if (l.id == data.primaryLensId) {
                          selected = l;
                          break;
                        }
                      }
                    }
                    final path = selected?.heroImagePath;
                    if (path != null && File(path).existsSync()) {
                      return Image.file(File(path), fit: BoxFit.cover);
                    }
                    return StreamBuilder<List<MoodboardImage>>(
                      stream: db.watchMoodboardImagesForSection(
                        projectId,
                        BibleSectionId.optics,
                      ),
                      builder: (context, mb) {
                        final imgs = mb.data ?? [];
                        if (imgs.isNotEmpty) {
                          final f = File(imgs.first.imagePath);
                          if (f.existsSync()) {
                            return Image.file(f, fit: BoxFit.cover);
                          }
                        }
                        return ColoredBox(
                          color: palette.surfaceOverlay,
                          child: Icon(
                            Icons.camera_roll_outlined,
                            size: 64,
                            color: palette.textTertiary,
                          ),
                        );
                      },
                    );
                  },
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Color(0xF2131315),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 20,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: palette.accent.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: palette.accent.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Text(
                                'PRIMARY SET',
                                style: AppTypography.label(palette).copyWith(
                                  fontSize: 10,
                                  color: palette.accent,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            StreamBuilder<List<Lense>>(
                              stream: db.watchAllLenses(),
                              builder: (context, snap) {
                                final lenses = snap.data ?? [];
                                String title = setName;
                                if (title.isEmpty &&
                                    data.primaryLensId != null) {
                                  for (final l in lenses) {
                                    if (l.id == data.primaryLensId) {
                                      title = '${l.brand} ${l.model}';
                                      break;
                                    }
                                  }
                                }
                                if (title.isEmpty) {
                                  title = 'Seleccionar lente…';
                                }
                                return InkWell(
                                  onTap: onEditMeta,
                                  child: Text(
                                    title,
                                    style: AppTypography.titleMedium(palette)
                                        .copyWith(
                                      fontSize: 22,
                                      color: Colors.white,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _chip(tStop, palette),
                      const SizedBox(width: 6),
                      _chip(squeeze, palette),
                    ],
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: IconButton(
                    onPressed: onEditMeta,
                    icon: Icon(Icons.edit, color: palette.accent, size: 18),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black45,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, c) {
                final side = c.maxWidth >= 480;
                final bokehCol = _charCol(
                  'Bokeh Characteristic',
                  bokeh.isEmpty
                      ? 'Toca editar para definir el bokeh…'
                      : bokeh,
                  palette,
                  onEditMeta,
                );
                final flareCol = _charCol(
                  'Flare Behavior',
                  flare.isEmpty
                      ? 'Toca editar para definir el flare…'
                      : flare,
                  palette,
                  onEditMeta,
                );
                if (side) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: bokehCol),
                      const SizedBox(width: 24),
                      Expanded(child: flareCol),
                    ],
                  );
                }
                return Column(
                  children: [
                    bokehCol,
                    const SizedBox(height: 16),
                    flareCol,
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () async {
                    await MoodboardHelpers.addManualImages(
                      db: db,
                      projectId: projectId,
                      bibleId: data.id,
                      category: MoodboardCategory.reference,
                      assignedSections: [BibleSectionId.optics],
                    );
                  },
                  icon: Icon(Icons.add_photo_alternate_outlined,
                      size: 16, color: palette.accent),
                  label: Text(
                    'Hero image',
                    style: TextStyle(color: palette.accent, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, AppPalette palette) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        text,
        style: AppTypography.mono(palette).copyWith(
          fontSize: 12,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _charCol(
    String label,
    String body,
    AppPalette palette,
    VoidCallback onEdit,
  ) {
    return InkWell(
      onTap: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTypography.label(palette).copyWith(
              fontSize: 10,
              letterSpacing: 1.2,
              color: palette.textTertiary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: AppTypography.bodyMedium(palette).copyWith(
              color: palette.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final String name;
  final String density;
  final String note;
  final double progress;
  final bool muted;
  final AppPalette palette;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _FilterRow({
    required this.name,
    required this.density,
    required this.note,
    required this.progress,
    required this.muted,
    required this.palette,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onEdit,
      onLongPress: onDelete,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: AppTypography.mono(palette).copyWith(fontSize: 13),
                ),
              ),
              Text(
                density,
                style: AppTypography.mono(palette).copyWith(
                  fontSize: 13,
                  color: muted ? palette.textTertiary : palette.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0.05, 1.0),
              minHeight: 4,
              backgroundColor: palette.surfaceElevated,
              color: muted
                  ? palette.textTertiary.withValues(alpha: 0.5)
                  : palette.accent,
            ),
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              note,
              style: AppTypography.bodyMedium(palette).copyWith(
                fontSize: 13,
                color: palette.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MaintenanceEntry extends StatelessWidget {
  final String title;
  final String date;
  final String body;
  final IconData icon;
  final AppPalette palette;
  final bool showLine;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MaintenanceEntry({
    required this.title,
    required this.date,
    required this.body,
    required this.icon,
    required this.palette,
    required this.showLine,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.surfaceElevated,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 2,
                  ),
                ),
                child: Icon(icon, size: 14, color: palette.textTertiary),
              ),
              if (showLine)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: onEdit,
              onLongPress: onDelete,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0x661A1A1C),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: AppTypography.mono(palette)
                                .copyWith(fontSize: 13),
                          ),
                        ),
                        Text(
                          date.toUpperCase(),
                          style: AppTypography.label(palette).copyWith(
                            fontSize: 10,
                            color: palette.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        body,
                        style: AppTypography.bodyMedium(palette).copyWith(
                          fontSize: 13,
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LensSetsPanel extends StatelessWidget {
  final List<Map<String, dynamic>> lensSets;
  final AppPalette palette;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;

  const _LensSetsPanel({
    required this.lensSets,
    required this.palette,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.videocam_outlined, color: palette.accent, size: 18),
              const SizedBox(width: 8),
              Text(
                'Lens sets (A-Cam / B-Cam)',
                style: AppTypography.titleMedium(palette).copyWith(fontSize: 16),
              ),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  final name = TextEditingController(text: 'A-Cam');
                  final squeeze = TextEditingController(text: '2.0');
                  final ratio = TextEditingController(text: '2.39:1');
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Nuevo lens set'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: name,
                            decoration: const InputDecoration(labelText: 'Nombre'),
                          ),
                          TextField(
                            controller: squeeze,
                            decoration: const InputDecoration(
                              labelText: 'Squeeze (1.0 esférica)',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          TextField(
                            controller: ratio,
                            decoration: const InputDecoration(
                              labelText: 'Aspect ratio',
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancelar'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Añadir'),
                        ),
                      ],
                    ),
                  );
                  if (ok != true) return;
                  final sq = double.tryParse(squeeze.text.trim()) ?? 1.0;
                  onChanged([
                    ...lensSets,
                    {
                      'name': name.text.trim(),
                      'isAnamorphic': sq > 1.05,
                      'squeezeRatio': sq,
                      'aspectRatio': ratio.text.trim(),
                    },
                  ]);
                },
                child: Text('Añadir', style: TextStyle(color: palette.accent)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (lensSets.isEmpty)
            Text(
              'Define sets mixtos (esférica + anamórfica) por cámara.',
              style: AppTypography.bodyMedium(palette)
                  .copyWith(color: palette.textTertiary),
            )
          else
            for (var i = 0; i < lensSets.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${lensSets[i]['name'] ?? 'Set'} · '
                        '${lensSets[i]['isAnamorphic'] == true ? 'Anam' : 'Sph'} · '
                        '${lensSets[i]['squeezeRatio'] ?? 1.0}x · '
                        '${lensSets[i]['aspectRatio'] ?? '—'}',
                        style: AppTypography.bodyMedium(palette),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline,
                          color: palette.error, size: 18),
                      onPressed: () {
                        final next = [...lensSets]..removeAt(i);
                        onChanged(next);
                      },
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xB31A1A1C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.08),
            blurRadius: 0,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}
