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
import '../../core/widgets/app_button.dart';
import '../../core/widgets/color_scope_prompt_dialog.dart';
import '../../core/widgets/scene_color_editor.dart';

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
  late final TextEditingController _slugCtrl;
  late final TextEditingController _siteCtrl;
  late final TextEditingController _setCtrl;
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

  bool get _isEditing => widget.scene != null;

  @override
  void initState() {
    super.initState();
    final s = widget.scene;
    _numberCtrl = TextEditingController(text: '${s?.number ?? ''}');
    _nameCtrl = TextEditingController(text: s?.name ?? '');
    _slugCtrl = TextEditingController(
      text: s != null ? locationFromCanonical(s.locationCanonical) : '',
    );
    _siteCtrl = TextEditingController(text: s?.locationPureName ?? '');
    _setCtrl = TextEditingController(text: s?.locationPureName ?? '');
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
    if (s.locationSiteId != null) {
      final site = await db.getSiteById(s.locationSiteId!);
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
      _siteCtrl.text = siteName;
      _setCtrl.text = s.locationPureName;
      _effectiveColor = effective;
      _pickedHex = hexFromColor(effective);
      _colorScope = hasOverride
          ? ColorEditScope.scene
          : ColorEditScope.set;
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
      });
      return;
    }

    setState(() => _pickedHex = hex);
  }

  Future<void> _prefillNextNumber() async {
    final db = ref.read(databaseProvider);
    final scenes = await db.watchScenesForProject(widget.projectId).first;
    final next = scenes.isEmpty
        ? 1
        : scenes.map((s) => s.number).reduce((a, b) => a > b ? a : b) + 1;
    if (mounted) _numberCtrl.text = '$next';
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    _nameCtrl.dispose();
    _slugCtrl.dispose();
    _siteCtrl.dispose();
    _setCtrl.dispose();
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
    final slugLocation = _slugCtrl.text.trim();
    if (number == null || slugLocation.isEmpty) return;

    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    final shootSet =
        _setCtrl.text.trim().isEmpty ? slugLocation : _setCtrl.text.trim();
    final siteName =
        _siteCtrl.text.trim().isEmpty ? shootSet : _siteCtrl.text.trim();
    final intExt = _intExt;
    final dayNight = _dayNight;
    final name = _nameCtrl.text.trim().isEmpty
        ? formatSceneDefaultName(
            intExt: intExt,
            dayNight: dayNight,
            location: slugLocation,
          )
        : _nameCtrl.text.trim();
    final canonical = '$intExt. $slugLocation - $dayNight';
    final description = _descriptionCtrl.text.trim();
    final colorHex = sceneColorForPicker(_pickedHex);

    final site = await db.ensureSite(
      projectId: widget.projectId,
      siteName: siteName,
    );
    final ensured = await db.ensureSiteAndSet(
      projectId: widget.projectId,
      siteName: siteName,
      setName: shootSet,
    );
    final setId = ensured.set.id;

    int? sceneId;
    if (_isEditing) {
      final s = widget.scene!;
      await db.updateScene(s.copyWith(
        number: number,
        name: name,
        locationCanonical: canonical,
        locationPureName: shootSet,
        locationSiteId: Value(site.id),
        locationId: Value(setId),
        intExt: intExt,
        dayNight: dayNight,
        locationColor: const Value(null),
        description: Value(description.isEmpty ? null : description),
        sortOrder: number,
      ));
      sceneId = s.id;
    } else {
      sceneId = await db.insertScene(ScenesCompanion.insert(
        projectId: widget.projectId,
        number: number,
        name: name,
        locationCanonical: canonical,
        locationPureName: shootSet,
        locationSiteId: Value(site.id),
        locationId: Value(setId),
        intExt: Value(intExt),
        dayNight: Value(dayNight),
        locationColor: const Value(null),
        description: Value(description.isEmpty ? null : description),
        sortOrder: Value(number),
      ));
    }

    await _applyColor(
      db: db,
      sceneId: sceneId,
      setId: setId,
      siteId: site.id,
      colorHex: colorHex,
    );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.xl,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEditing ? 'Editar escena' : 'Añadir escena',
              style: AppTypography.titleLarge(palette),
            ),
            const SizedBox(height: AppSpacing.lg),
            _field('Número', _numberCtrl, palette, keyboard: TextInputType.number),
            const SizedBox(height: AppSpacing.md),
            _field('Nombre (opcional)', _nameCtrl, palette),
            const SizedBox(height: AppSpacing.md),
            _dropdown('INT/EXT', _intExt, kIntExtOptions, palette, (v) {
              if (v != null) setState(() => _intExt = v);
            }),
            const SizedBox(height: AppSpacing.md),
            _dropdown('Día / Noche', _dayNight, kDayNightOptions, palette, (v) {
              if (v != null) setState(() => _dayNight = v);
            }),
            const SizedBox(height: AppSpacing.md),
            _field('Lugar en el guion', _slugCtrl, palette,
                hint: 'Como aparece en la slugline'),
            const SizedBox(height: AppSpacing.md),
            _field('Localización', _siteCtrl, palette, hint: 'Ej. BOSQUE'),
            const SizedBox(height: AppSpacing.md),
            _field('Set de rodaje', _setCtrl, palette,
                hint: 'Ej. RÍO, ENTRADA DEL BOSQUE'),
            const SizedBox(height: AppSpacing.md),
            _field(
              'Descripción',
              _descriptionCtrl,
              palette,
              hint: 'Resumen de la escena, tono, personajes…',
              minLines: 3,
            ),
            const SizedBox(height: AppSpacing.md),
            if (_loadingColor)
              const Center(child: CircularProgressIndicator())
            else
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
                }),
              ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: _isEditing ? 'Guardar cambios' : 'Añadir escena',
              icon: Icons.check,
              loading: _saving,
              onTap: _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl,
    AppPalette palette, {
    String? hint,
    TextInputType? keyboard,
    int minLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.label(palette)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: keyboard,
          minLines: minLines,
          maxLines: minLines > 1 ? null : 1,
          style: AppTypography.bodyLarge(palette),
          decoration: InputDecoration(hintText: hint ?? label),
        ),
      ],
    );
  }

  Widget _dropdown(
    String label,
    String value,
    List<String> options,
    AppPalette palette,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.label(palette)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: options.contains(value) ? value : options.first,
          dropdownColor: palette.surfaceElevated,
          style: AppTypography.bodyLarge(palette),
          items: options
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: onChanged,
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
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.palette.surfaceElevated,
    builder: (_) => SceneFormSheet(projectId: projectId, scene: scene),
  );
}
