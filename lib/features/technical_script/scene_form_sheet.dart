import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/color_edit_scope.dart';
import '../../core/utils/project_color_scheme.dart';
import '../../core/utils/scene_color.dart';
import '../../core/utils/scene_format.dart';
import '../../core/widgets/color_scope_prompt_dialog.dart';
import '../../core/widgets/scene_color_editor.dart';
import '../locations/location_picker.dart';

const kIntExtOptions = ['INT', 'EXT', 'INT/EXT'];
const kDayNightOptions = ['DÍA', 'NOCHE', 'AMANECER', 'ATARDECER', 'CONTINUO'];

class SceneFormSheet extends ConsumerStatefulWidget {
  final int projectId;
  final Scene? scene;

  const SceneFormSheet({super.key, required this.projectId, this.scene});

  @override
  ConsumerState<SceneFormSheet> createState() => _SceneFormSheetState();
}

class _SceneFormSheetState extends ConsumerState<SceneFormSheet> {
  late final TextEditingController _numberCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descriptionCtrl;
  late String _intExt;
  late String _dayNight;
  late String _pickedHex;
  late ColorEditScope _colorScope;
  Color _effectiveColor = sceneDisplayColor(null);
  int _scenesInSet = 0;
  int _setsInSite = 0;
  bool _saving = false;
  bool _loadingColor = true;
  bool _colorCustomizationConfirmed = false;
  String _linkedSetName = '';
  String _linkedSiteName = '';

  /// Localización y set elegidos; sin ellos no se puede guardar.
  LocationChoice? _choice;

  /// Solo se toca el color si el usuario lo ha cambiado aquí.
  bool _colorTouched = false;

  bool get _isEditing => widget.scene != null;

  @override
  void initState() {
    super.initState();
    final s = widget.scene;
    _numberCtrl = TextEditingController(text: '${s?.number ?? ''}');
    // Un nombre igual al que se genera solo no cuenta como nombre propio:
    // así sigue al lugar si este cambia.
    final autoName = s == null
        ? null
        : formatSceneDefaultName(
            intExt: s.intExt,
            dayNight: s.dayNight,
            location: locationFromCanonical(s.locationCanonical),
          );
    _nameCtrl = TextEditingController(
      text: s == null || s.name == autoName ? '' : s.name,
    );
    _descriptionCtrl = TextEditingController(text: s?.description ?? '');
    _intExt = s?.intExt ?? 'INT';
    _dayNight = s?.dayNight ?? 'DÍA';
    _pickedHex = kSceneColorNeutral;
    _colorScope = ColorEditScope.set;

    if (!_isEditing) {
      _prefillNextNumber();
      _loadingColor = false;
    } else {
      _loadColorContext();
    }
  }

  Future<void> _loadColorContext() async {
    final s = widget.scene;
    if (s == null) return;

    final db = ref.read(databaseProvider);
    final sites = await db.watchSitesForProject(widget.projectId).first;
    final sets = await db.watchLocationsForProject(widget.projectId).first;
    final scenes = await db.watchScenesForProject(widget.projectId).first;
    final scheme = ProjectColorScheme.resolve(
      sites: sites,
      sets: sets,
      scenes: scenes,
    );

    String siteName = s.locationPureName;
    LocationSite? site;
    if (s.locationSiteId != null) {
      site = await db.getSiteById(s.locationSiteId!);
      if (site != null) siteName = site.name;
    }

    var scenesInSet = 0;
    var setsInSite = 0;
    if (s.locationId != null) {
      scenesInSet = await db.countScenesForLocation(s.locationId!);
    }
    if (s.locationSiteId != null) {
      setsInSite = await db.countSetsForSite(s.locationSiteId!);
    }

    final effective = scheme.sceneColor(s);
    final hasOverride = persistSceneColor(s.locationColor) != null;
    LocationBasePlan? linkedSet;
    if (s.locationId != null) {
      linkedSet = await db.getLocationById(s.locationId!);
    }

    if (!mounted) return;
    setState(() {
      if (site != null && linkedSet != null) {
        _choice = LocationChoice(site: site, set: linkedSet);
      }
      _effectiveColor = effective;
      _pickedHex = hexFromColor(effective);
      _colorScope = hasOverride ? ColorEditScope.scene : ColorEditScope.set;
      if (linkedSet != null && !hasOverride) {
        _pickedHex = sceneColorForPicker(linkedSet.color);
      }
      _scenesInSet = scenesInSet;
      _setsInSite = setsInSite;
      _linkedSetName = s.locationPureName;
      _linkedSiteName = siteName;
      _colorCustomizationConfirmed = hasOverride;
      _loadingColor = false;
    });
  }

  Future<void> _onColorChanged(String hex) async {
    if (!_colorCustomizationConfirmed &&
        _setsInSite > 1 &&
        _colorScope != ColorEditScope.scene) {
      final palette = context.palette;
      final result = await showSetColorCustomizationDialog(
        context,
        palette: palette,
        setName: _linkedSetName,
        locationSiteName: _linkedSiteName,
        initialHex: hex,
        scenesInSet: _scenesInSet,
        setsInSite: _setsInSite,
      );
      if (!mounted || result == null) return;
      setState(() {
        _pickedHex = result.colorHex;
        _colorScope = result.scope;
        _colorCustomizationConfirmed = true;
        _colorTouched = true;
      });
      return;
    }

    setState(() {
      _pickedHex = hex;
      _colorTouched = true;
    });
  }

  Future<void> _prefillNextNumber() async {
    final db = ref.read(databaseProvider);
    final scenes = await (db.select(
      db.scenes,
    )..where((s) => s.projectId.equals(widget.projectId))).get();
    final next = scenes.isEmpty
        ? 1
        : scenes.map((s) => s.number).reduce((a, b) => a > b ? a : b) + 1;
    if (!mounted) return;
    // Repintar: el botón de crear depende de que haya número.
    setState(() => _numberCtrl.text = '$next');
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _applyColor({
    required AppDatabase db,
    required int? sceneId,
    required int? setId,
    required int? siteId,
    required String colorHex,
  }) async {
    switch (_colorScope) {
      case ColorEditScope.scene:
        if (sceneId != null) {
          await db.applySceneColorOverride(sceneId, colorHex);
        }
      case ColorEditScope.set:
        if (setId != null) {
          await db.applySetColorHex(setId, colorHex);
        }
      case ColorEditScope.location:
        if (siteId != null) {
          await db.applySiteColorFromBase(siteId, colorHex);
        }
    }
  }

  Future<void> _save() async {
    final number = int.tryParse(_numberCtrl.text.trim());
    final choice = _choice;
    if (number == null || choice == null || _saving) return;

    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    final place = choice.placeName;
    final name = _nameCtrl.text.trim().isEmpty
        ? formatSceneDefaultName(
            intExt: _intExt,
            dayNight: _dayNight,
            location: place,
          )
        : _nameCtrl.text.trim();
    final canonical = '$_intExt. $place - $_dayNight';
    final description = _descriptionCtrl.text.trim();

    int sceneId;
    if (_isEditing) {
      final s = widget.scene!;
      await db.updateScene(
        s.copyWith(
          number: number,
          name: name,
          locationCanonical: canonical,
          locationPureName: choice.set.locationName,
          locationSiteId: Value(choice.site.id),
          locationId: Value(choice.set.id),
          intExt: _intExt,
          dayNight: _dayNight,
          description: Value(description.isEmpty ? null : description),
          sortOrder: number,
        ),
      );
      sceneId = s.id;
    } else {
      sceneId = await db.insertScene(
        ScenesCompanion.insert(
          projectId: widget.projectId,
          number: number,
          name: name,
          locationCanonical: canonical,
          locationPureName: choice.set.locationName,
          locationSiteId: Value(choice.site.id),
          locationId: Value(choice.set.id),
          intExt: Value(_intExt),
          dayNight: Value(_dayNight),
          description: Value(description.isEmpty ? null : description),
          sortOrder: Value(number),
        ),
      );
    }

    if (_colorTouched) {
      await _applyColor(
        db: db,
        sceneId: sceneId,
        setId: choice.set.id,
        siteId: choice.site.id,
        colorHex: sceneColorForPicker(_pickedHex),
      );
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final canSave =
        _choice != null && int.tryParse(_numberCtrl.text.trim()) != null;

    Widget segmented(
      List<String> options,
      String value,
      ValueChanged<String> onChanged,
    ) => SegmentedButton<String>(
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      segments: [
        for (final o in options) ButtonSegment(value: o, label: Text(o)),
      ],
      selected: {options.contains(value) ? value : options.first},
      onSelectionChanged: (s) => onChanged(s.first),
    );

    return Dialog(
      backgroundColor: palette.surfaceElevated,
      insetPadding: const EdgeInsets.all(AppSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEditing ? 'Editar escena' : 'Nueva escena',
                style: AppTypography.titleLarge(palette),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 84,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Escena', style: AppTypography.label(palette)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _numberCtrl,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyLarge(palette),
                          decoration: const InputDecoration(isDense: true),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: segmented(
                      kIntExtOptions,
                      _intExt,
                      (v) => setState(() => _intExt = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              segmented(
                kDayNightOptions,
                _dayNight,
                (v) => setState(() => _dayNight = v),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Localización', style: AppTypography.label(palette)),
              const SizedBox(height: 6),
              if (_isEditing && _loadingColor)
                const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                LocationPickerPanel(
                  projectId: widget.projectId,
                  initialSiteId: _choice?.site.id,
                  initialSetId: _choice?.set.id,
                  onChanged: (c) => setState(() => _choice = c),
                ),
              const SizedBox(height: AppSpacing.sm),
              Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: AppSpacing.md),
                  title: Text(
                    'Más opciones',
                    style: AppTypography.label(palette),
                  ),
                  subtitle: Text(
                    _isEditing
                        ? 'Nombre, descripción y color'
                        : 'Nombre y descripción',
                    style: AppTypography.caption(palette),
                  ),
                  children: [
                    _field(
                      'Nombre (opcional)',
                      _nameCtrl,
                      palette,
                      hint: 'Si lo dejas vacío, se compone solo',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _field(
                      'Descripción',
                      _descriptionCtrl,
                      palette,
                      hint: 'Resumen de la escena, tono, personajes…',
                      minLines: 3,
                    ),
                    if (_isEditing && !_loadingColor) ...[
                      const SizedBox(height: AppSpacing.md),
                      SceneColorEditor(
                        palette: palette,
                        effectiveColor: _effectiveColor,
                        selectedHex: _pickedHex,
                        scope: _colorScope,
                        scenesInSet: _scenesInSet,
                        setsInSite: _setsInSite,
                        onColorChanged: _onColorChanged,
                        onScopeChanged: (scope) => setState(() {
                          _colorScope = scope;
                          _colorCustomizationConfirmed = true;
                          _colorTouched = true;
                        }),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancelar',
                      style: AppTypography.bodyMedium(palette),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton.icon(
                    onPressed: canSave && !_saving ? _save : null,
                    icon: const Icon(Icons.check, size: 18),
                    label: Text(_isEditing ? 'Guardar' : 'Crear escena'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl,
    AppPalette palette, {
    String? hint,
    int minLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.label(palette)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          minLines: minLines,
          maxLines: minLines > 1 ? null : 1,
          style: AppTypography.bodyLarge(palette),
          decoration: InputDecoration(hintText: hint ?? label),
        ),
      ],
    );
  }
}

void showSceneFormSheet(
  BuildContext context, {
  required int projectId,
  Scene? scene,
}) {
  showDialog<void>(
    context: context,
    builder: (_) => SceneFormSheet(projectId: projectId, scene: scene),
  );
}
