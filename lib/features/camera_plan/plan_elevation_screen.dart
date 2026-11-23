import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/export_file_saver.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../shared/pdf_export/rig_sheet_pdf.dart';
import 'arch/plan_section.dart';
import 'camera_plan_element_model.dart';
import 'light/light_scene.dart';
import 'light_sheet_export.dart';
import 'light_sheet_prefs.dart';
import 'plan_cad_export.dart';
import 'plan_elevation.dart';

/// La hoja de luz tal como saldrá en PDF —planta, alzado y perfil a
/// escala—, con lo que entra en ella a la vista: conos, manchas en el
/// suelo, personas y números. Lo elegido aquí es lo que usa luego la
/// ventana de exportar. También exporta a DXF (CAD) y MVR (iluminación).
Future<void> showPlanElevation(
  BuildContext context, {
  required List<PlanElement> elements,
  required double metersPerUnit,
  required String name,
  LightScene? scene,
  RigSheetInfo? sheetInfo,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => PlanElevationScreen(
      elements: elements,
      scene: scene,
      metersPerUnit: metersPerUnit,
      name: name,
      sheetInfo: sheetInfo,
    ),
  ),
);

class PlanElevationScreen extends StatefulWidget {
  final List<PlanElement> elements;
  final double metersPerUnit;

  /// Nombre de la planta, para los archivos.
  final String name;

  /// La planta vista por la luz, si ya la tiene quien abre el alzado: de
  /// ella salen las alturas de las paredes.
  final LightScene? scene;

  /// Lo que ya se sabe para el cajetín de la hoja de luz.
  final RigSheetInfo? sheetInfo;

  const PlanElevationScreen({
    super.key,
    required this.elements,
    this.scene,
    required this.metersPerUnit,
    required this.name,
    this.sheetInfo,
  });

  @override
  State<PlanElevationScreen> createState() => _PlanElevationScreenState();
}

class _PlanElevationScreenState extends State<PlanElevationScreen> {
  /// Qué hoja se mira: la planta (1) o el alzado y el perfil (2); con
  /// secciones, la primera de ellas (3). En una sola hoja, la hoja (1) o
  /// las secciones (2).
  var _page = 2;
  var _compactPage = 1;

  /// Las líneas de sección de la planta (AM.6).
  late final List<PlanElement> _sections = PlanSection.of(widget.elements);

  RigSheetOptions _o = const RigSheetOptions();
  var _gaffer = '';
  var _loaded = false;

  /// La hoja ya dibujada y la clave de lo que se eligió para ella.
  Uint8List? _bytes;
  var _key = '';
  var _building = false;
  var _pending = false;
  Object? _error;

  /// Una vista por lado, para el DXF; hecha la primera vez que se pide.
  final _elevations = <ElevationSide, PlanElevation>{};

  PlanElevation _elevation(ElevationSide side) =>
      _elevations[side] ??= PlanElevation.of(
        widget.elements,
        metersPerUnit: widget.metersPerUnit,
        side: side,
        scene: widget.scene,
      );

  String get _base =>
      widget.name.trim().isEmpty ? 'planta' : widget.name.trim();

  RigSheetInfo get _info {
    final info =
        widget.sheetInfo ??
        RigSheetInfo(project: _base, set: _base, date: DateTime.now());
    if (info.gaffer.isNotEmpty || _gaffer.isEmpty) return info;
    return RigSheetInfo(
      project: info.project,
      location: info.location,
      set: info.set,
      scheme: info.scheme,
      scenes: info.scenes,
      shootDay: info.shootDay,
      gaffer: _gaffer,
      department: info.department,
      date: info.date,
      revision: info.revision,
    );
  }

  /// En pantalla, sin la lista de focos: solo los dibujos.
  RigSheetOptions get _preview => _o.copyWith(schedule: false);

  String _keyOf(RigSheetOptions o) =>
      [o.layout.name, o.numbers.name, o.beams, o.pools, o.people].join('-');

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final o = await LightSheetPrefs.load();
    final gaffer = await LightSheetPrefs.gaffer();
    if (!mounted) return;
    setState(() {
      _o = o;
      _gaffer = gaffer;
      _loaded = true;
    });
    unawaited(_rebuild());
  }

  void _change(RigSheetOptions o) {
    setState(() => _o = o);
    unawaited(LightSheetPrefs.save(o));
    unawaited(_rebuild());
  }

  /// Dibuja la hoja otra vez. Si ya se está dibujando, vuelve a empezar al
  /// acabar con lo último elegido.
  Future<void> _rebuild() async {
    if (widget.elements.isEmpty) return;
    if (_building) {
      _pending = true;
      return;
    }
    _building = true;
    try {
      do {
        _pending = false;
        final o = _preview;
        final bytes = await RigSheetPdf.build(
          widget.elements,
          metersPerUnit: widget.metersPerUnit,
          info: _info,
          options: o,
        );
        if (!mounted) return;
        setState(() {
          _bytes = bytes;
          _key = _keyOf(o);
          _error = null;
        });
      } while (_pending && mounted);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      _building = false;
    }
  }

  Future<void> _save(
    Uint8List bytes,
    String suffix,
    String extension,
    String what,
  ) async {
    try {
      final path = await ExportFileSaver.saveBytes(
        bytes: bytes,
        dialogTitle: 'Guardar $what',
        fileName: '$_base $suffix',
        extension: extension,
      );
      if (path != null && mounted) {
        AppSnackBar.show(context, '$what guardado.');
      }
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, 'No se pudo guardar: $e');
    }
  }

  /// La hoja A3 de luz y rigging, para imprimir o mandar al rigger. Sale
  /// con lo que se ha elegido aquí.
  Future<void> _saveSheet() async {
    await showLightSheetExport(
      context,
      elements: widget.elements,
      metersPerUnit: widget.metersPerUnit,
      info: _info,
    );
    // Lo que se cambie en la ventana de exportar vale también aquí.
    if (mounted) unawaited(_restore());
  }

  void _saveSection(PlanElement section) {
    final e = PlanSection.elevationOf(
      section,
      widget.elements,
      metersPerUnit: widget.metersPerUnit,
    );
    _save(
      utf8.encode(PlanCadExport.elevationDxf(e)),
      'seccion ${PlanSection.name(section)}',
      'dxf',
      'DXF de la ${e.title.toLowerCase()}',
    );
  }

  void _saveSide(ElevationSide side) => _save(
    utf8.encode(PlanCadExport.elevationDxf(_elevation(side))),
    side.label.toLowerCase(),
    'dxf',
    'DXF del ${side.label.toLowerCase()}',
  );

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final split = _o.layout == RigSheetLayout.split;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: const Text('Alzado y perfil'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Exportar',
            icon: const Icon(Icons.ios_share),
            onSelected: (choice) => switch (choice) {
              'pdf-a3' => _saveSheet(),
              'dxf-plan' => _save(
                utf8.encode(
                  PlanCadExport.planDxf(widget.elements, widget.metersPerUnit),
                ),
                'planta',
                'dxf',
                'DXF de la planta',
              ),
              'dxf-front' => _saveSide(ElevationSide.front),
              'dxf-side' => _saveSide(ElevationSide.side),
              final String c when c.startsWith('dxf-sec-') => _saveSection(
                _sections[int.parse(c.substring(8))],
              ),
              _ => _save(
                PlanCadExport.planMvr(
                  widget.elements,
                  widget.metersPerUnit,
                  layerName: _base,
                ),
                'luces',
                'mvr',
                'MVR de las luces',
              ),
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'pdf-a3',
                child: ListTile(
                  dense: true,
                  title: Text('Hoja de luz en PDF'),
                  subtitle: Text(
                    'Lo que ves aquí, con cajetín y lista de focos. A3 o A4',
                  ),
                ),
              ),
              const PopupMenuItem(
                value: 'dxf-plan',
                child: ListTile(
                  dense: true,
                  title: Text('Planta en DXF'),
                  subtitle: Text('Para AutoCAD, Vectorworks o LibreCAD'),
                ),
              ),
              for (final side in ElevationSide.values)
                PopupMenuItem(
                  value: side == ElevationSide.front ? 'dxf-front' : 'dxf-side',
                  child: ListTile(
                    dense: true,
                    title: Text('${side.label} en DXF'),
                    subtitle: Text('Visto ${side.hint}, en metros'),
                  ),
                ),
              for (final (i, s) in _sections.indexed)
                PopupMenuItem(
                  value: 'dxf-sec-$i',
                  child: ListTile(
                    dense: true,
                    title: Text('Sección ${PlanSection.name(s)}-'
                        '${PlanSection.name(s)} en DXF'),
                    subtitle: const Text(
                      'Lo que hay detrás del corte, en metros',
                    ),
                  ),
                ),
              const PopupMenuItem(
                value: 'mvr',
                child: ListTile(
                  dense: true,
                  title: Text('Luces en MVR'),
                  subtitle: Text(
                    'Para Vectorworks Spotlight, grandMA3, Capture o '
                    'WYSIWYG: posición, altura, giro y unidad',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SegmentedButton<RigSheetLayout>(
                  segments: const [
                    ButtonSegment(
                      value: RigSheetLayout.split,
                      label: Text('Dos hojas'),
                    ),
                    ButtonSegment(
                      value: RigSheetLayout.compact,
                      label: Text('Una hoja'),
                    ),
                  ],
                  selected: {_o.layout},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) =>
                      _change(_o.copyWith(layout: s.first)),
                ),
                if (split)
                  SegmentedButton<int>(
                    segments: [
                      const ButtonSegment(value: 1, label: Text('Planta')),
                      const ButtonSegment(
                        value: 2,
                        label: Text('Alzado y perfil'),
                      ),
                      if (_sections.isNotEmpty)
                        ButtonSegment(value: 3, label: Text(_sectionsLabel)),
                    ],
                    selected: {_page},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => setState(() => _page = s.first),
                  )
                else if (_sections.isNotEmpty)
                  SegmentedButton<int>(
                    segments: [
                      const ButtonSegment(value: 1, label: Text('Hoja')),
                      ButtonSegment(value: 2, label: Text(_sectionsLabel)),
                    ],
                    selected: {_compactPage},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) =>
                        setState(() => _compactPage = s.first),
                  ),
                FilterChip(
                  label: const Text('Conos de luz'),
                  selected: _o.beams,
                  onSelected: (v) => _change(_o.copyWith(beams: v)),
                ),
                FilterChip(
                  label: const Text('Manchas en el suelo'),
                  selected: _o.pools,
                  onSelected: (v) => _change(_o.copyWith(pools: v)),
                ),
                FilterChip(
                  label: const Text('Personas y cámaras'),
                  selected: _o.people,
                  onSelected: (v) => _change(_o.copyWith(people: v)),
                ),
                FilterChip(
                  label: const Text('Números'),
                  selected: _o.numbers != RigSheetNumbers.none,
                  onSelected: (v) => _change(
                    _o.copyWith(
                      numbers: v ? RigSheetNumbers.all : RigSheetNumbers.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _sheet(palette, split)),
        ],
      ),
    );
  }

  String get _sectionsLabel => _sections.length == 1
      ? 'Sección ${PlanSection.name(_sections.single)}'
      : 'Secciones';

  Widget _sheet(AppPalette palette, bool split) {
    if (widget.elements.isEmpty) {
      return Center(
        child: Text(
          'La planta está vacía.',
          style: AppTypography.bodyMedium(palette),
        ),
      );
    }
    final bytes = _bytes;
    if (bytes == null) {
      return Center(
        child: _error != null
            ? Text(
                'No se pudo dibujar la hoja: $_error',
                style: AppTypography.bodyMedium(palette),
              )
            : const CircularProgressIndicator(),
      );
    }
    final page = split
        ? (_page == 3 && _sections.isEmpty ? 2 : _page)
        : (_sections.isEmpty ? 1 : _compactPage);
    return Stack(
      children: [
        Positioned.fill(
          child: PdfViewer.data(
            bytes,
            // Una vista por hoja y por opciones: al cambiar algo se carga
            // la hoja nueva y se va a la página elegida.
            key: ValueKey('$_key-$page'),
            sourceName: 'alzado-$_key-${identityHashCode(bytes)}',
            params: PdfViewerParams(
              margin: 12,
              backgroundColor: palette.background,
              onViewerReady: (document, controller) {
                if (page > 1 && document.pages.length >= page) {
                  controller.goToPage(
                    pageNumber: page,
                    duration: Duration.zero,
                  );
                }
              },
            ),
          ),
        ),
        if (_building || !_loaded)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }
}
