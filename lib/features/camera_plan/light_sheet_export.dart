import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/export_file_saver.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../shared/pdf_export/rig_sheet_pdf.dart';
import 'camera_plan_element_model.dart';
import 'light_sheet_prefs.dart';

/// Pide cómo se quiere la hoja de luz (reparto, papel, números y cajetín),
/// la hace y la guarda (LZ.1).
Future<void> showLightSheetExport(
  BuildContext context, {
  required List<PlanElement> elements,
  required double metersPerUnit,
  required RigSheetInfo info,
}) async {
  final result = await showModalBottomSheet<(RigSheetOptions, RigSheetInfo)>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _LightSheetOptions(info: info),
  );
  if (result == null || !context.mounted) return;
  final (options, filled) = result;
  try {
    final bytes = await RigSheetPdf.build(
      elements,
      metersPerUnit: metersPerUnit,
      info: filled,
      options: options,
    );
    final name = [
      'Hoja de luz',
      if (filled.set.isNotEmpty) filled.set,
      if (filled.scheme.isNotEmpty) filled.scheme,
    ].join(' · ');
    final path = await ExportFileSaver.saveBytes(
      bytes: bytes,
      dialogTitle: 'Guardar la hoja de luz',
      fileName: name,
      extension: 'pdf',
    );
    if (path != null && context.mounted) {
      AppSnackBar.show(context, 'Hoja de luz guardada.');
    }
  } catch (e) {
    if (context.mounted) {
      AppSnackBar.showError(context, 'No se pudo hacer la hoja de luz: $e');
    }
  }
}

class _LightSheetOptions extends StatefulWidget {
  final RigSheetInfo info;

  const _LightSheetOptions({required this.info});

  @override
  State<_LightSheetOptions> createState() => _LightSheetOptionsState();
}

class _LightSheetOptionsState extends State<_LightSheetOptions> {
  var _o = const RigSheetOptions();
  late final _set = TextEditingController(text: widget.info.set);
  late final _scheme = TextEditingController(text: widget.info.scheme);
  late final _scenes = TextEditingController(text: widget.info.scenes);
  late final _day = TextEditingController(text: widget.info.shootDay);
  late final _gaffer = TextEditingController(text: widget.info.gaffer);
  late final _revision = TextEditingController(text: widget.info.revision);

  @override
  void initState() {
    super.initState();
    _restore();
  }

  /// Lo último que se eligió, para no repetirlo cada vez.
  Future<void> _restore() async {
    final o = await LightSheetPrefs.load();
    final gaffer = await LightSheetPrefs.gaffer();
    if (!mounted) return;
    setState(() {
      _o = o;
      if (_gaffer.text.isEmpty) _gaffer.text = gaffer;
    });
  }

  Future<void> _remember() async {
    await LightSheetPrefs.save(_o);
    await LightSheetPrefs.saveGaffer(_gaffer.text.trim());
  }

  @override
  void dispose() {
    for (final c in [_set, _scheme, _scenes, _day, _gaffer, _revision]) {
      c.dispose();
    }
    super.dispose();
  }

  void _make() {
    _remember();
    final i = widget.info;
    Navigator.of(context).pop((
      _o,
      RigSheetInfo(
        project: i.project,
        location: i.location,
        set: _set.text.trim(),
        scheme: _scheme.text.trim(),
        scenes: _scenes.text.trim(),
        shootDay: _day.text.trim(),
        gaffer: _gaffer.text.trim(),
        department: i.department,
        date: i.date,
        revision: _revision.text.trim().isEmpty ? 'A' : _revision.text.trim(),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    Widget field(TextEditingController c, String label) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: TextField(
        controller: c,
        decoration: InputDecoration(labelText: label, isDense: true),
        textInputAction: TextInputAction.next,
      ),
    );
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Hoja de luz', style: AppTypography.titleMedium(palette)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Planta, alzado y perfil a escala, con cada aparato '
                'dibujado y coloreado por modelo, cotas y leyenda.',
                style: AppTypography.caption(palette),
              ),
              const SizedBox(height: AppSpacing.md),
              SegmentedButton<RigSheetLayout>(
                segments: const [
                  ButtonSegment(
                    value: RigSheetLayout.split,
                    label: Text('Planta y alzados aparte'),
                  ),
                  ButtonSegment(
                    value: RigSheetLayout.compact,
                    label: Text('Todo en una hoja'),
                  ),
                ],
                selected: {_o.layout},
                onSelectionChanged: (s) =>
                    setState(() => _o = _o.copyWith(layout: s.first)),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  SegmentedButton<RigSheetPaper>(
                    segments: [
                      for (final p in RigSheetPaper.values)
                        ButtonSegment(value: p, label: Text(p.label)),
                    ],
                    selected: {_o.paper},
                    onSelectionChanged: (s) =>
                        setState(() => _o = _o.copyWith(paper: s.first)),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: DropdownButtonFormField<RigSheetNumbers>(
                      initialValue: _o.numbers,
                      isDense: true,
                      decoration: const InputDecoration(
                        labelText: 'Número de cada foco',
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: RigSheetNumbers.auto,
                          child: Text('Si hay 60 o menos'),
                        ),
                        DropdownMenuItem(
                          value: RigSheetNumbers.all,
                          child: Text('Siempre'),
                        ),
                        DropdownMenuItem(
                          value: RigSheetNumbers.none,
                          child: Text('Nunca'),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => _o = _o.copyWith(numbers: v)),
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _o.schedule,
                onChanged: (v) => setState(() => _o = _o.copyWith(schedule: v)),
                title: const Text('Lista de focos'),
                subtitle: const Text(
                  'Una hoja más con cada foco: accesorios, montaje, altura, '
                  'circuito y vatios',
                ),
              ),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  FilterChip(
                    label: const Text('Conos de luz'),
                    selected: _o.beams,
                    onSelected: (v) =>
                        setState(() => _o = _o.copyWith(beams: v)),
                  ),
                  FilterChip(
                    label: const Text('Manchas en el suelo'),
                    selected: _o.pools,
                    onSelected: (v) =>
                        setState(() => _o = _o.copyWith(pools: v)),
                  ),
                  FilterChip(
                    label: const Text('Personas y cámaras'),
                    selected: _o.people,
                    onSelected: (v) =>
                        setState(() => _o = _o.copyWith(people: v)),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('Cajetín', style: AppTypography.label(palette)),
              const SizedBox(height: AppSpacing.xs),
              field(_set, 'Set o localización'),
              field(_scheme, 'Esquema de luz'),
              field(_scenes, 'Escenas o planos'),
              field(_day, 'Jornada'),
              field(_gaffer, 'Gaffer'),
              field(_revision, 'Revisión'),
              const SizedBox(height: AppSpacing.sm),
              FilledButton.icon(
                onPressed: _make,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Hacer la hoja'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
