import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/color_edit_scope.dart';
import '../../core/utils/project_scene_colors.dart';
import '../../core/utils/scene_characters.dart';
import '../../core/utils/scene_color.dart';
import '../../core/widgets/color_scope_prompt_dialog.dart';
import '../../core/widgets/scene_character_chips.dart';
import '../../core/widgets/scene_color_editor.dart';
import '../locations/location_picker.dart';
import '../locations/where_field.dart';
import '../technical_script/scene_form_sheet.dart';
import 'normalized_scene.dart';

class ImportSceneEditResult {
  final NormalizedScene scene;
  final String setColor;
  final ColorEditScope colorScope;

  const ImportSceneEditResult({
    required this.scene,
    required this.setColor,
    required this.colorScope,
  });
}

class ImportSceneSheet extends ConsumerStatefulWidget {
  final int projectId;
  final NormalizedScene? scene;
  final int nextNumber;
  final ProjectSceneColors colorContext;
  final int scenesInSet;
  final int setsInSite;

  const ImportSceneSheet({
    super.key,
    required this.projectId,
    this.scene,
    required this.nextNumber,
    required this.colorContext,
    this.scenesInSet = 1,
    this.setsInSite = 1,
  });

  @override
  ConsumerState<ImportSceneSheet> createState() => _ImportSceneSheetState();
}

class _ImportSceneSheetState extends ConsumerState<ImportSceneSheet> {
  late final TextEditingController _numberCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _siteCtrl;
  late final TextEditingController _setCtrl;
  late final TextEditingController _charactersCtrl;
  late final TextEditingController _descriptionCtrl;
  late String _intExt;
  late String _dayNight;
  late String _pickedHex;
  late ColorEditScope _colorScope;
  late Color _effectiveColor;
  bool _colorCustomizationConfirmed = false;
  late List<String> _characters;

  /// Localización y set elegidos de entre los del proyecto.
  LocationChoice? _choice;
  bool _loadingChoice = true;

  bool get _isEditing => widget.scene != null;

  @override
  void initState() {
    super.initState();
    final s = widget.scene;
    final number = s?.number ?? widget.nextNumber;
    _numberCtrl = TextEditingController(text: '$number');
    _nameCtrl = TextEditingController(text: s?.name ?? '');
    _locationCtrl = TextEditingController(text: s?.location ?? '');
    _siteCtrl = TextEditingController(text: s?.locationSite ?? '');
    _setCtrl = TextEditingController(text: s?.shootSet ?? '');
    _characters = List<String>.from(s?.characters ?? const []);
    _charactersCtrl = TextEditingController(
      text: formatCharactersInput(_characters),
    );
    _descriptionCtrl = TextEditingController(text: s?.description ?? '');
    _intExt = s?.intExt ?? 'INT';
    _dayNight = s?.dayNight ?? 'DÍA';

    final shootSet = s?.shootSet ?? '';
    final locationSite = s?.locationSite ?? _siteCtrl.text.trim();
    _effectiveColor = widget.colorContext.effective(
      shootSet: shootSet.isEmpty ? 'temp' : shootSet,
      sceneColorOverride: s?.locationColor,
      locationSite: locationSite.isEmpty ? null : locationSite,
    );
    _pickedHex = hexFromColor(_effectiveColor);
    _colorScope = persistSceneColor(s?.locationColor) != null
        ? ColorEditScope.scene
        : ColorEditScope.set;
    _colorCustomizationConfirmed = persistSceneColor(s?.locationColor) != null;

    _loadChoice();
  }

  /// Busca en el proyecto la localización y el set que la escena ya nombra,
  /// para enseñarlos elegidos.
  Future<void> _loadChoice() async {
    final db = ref.read(databaseProvider);
    final siteName = _siteCtrl.text.trim();
    final setName = _setCtrl.text.trim();
    LocationChoice? choice;
    if (siteName.isNotEmpty) {
      final site = await db.findSiteByName(widget.projectId, siteName);
      if (site != null) {
        final set =
            (setName.isEmpty
                ? null
                : await db.findSetInSite(site.id, setName)) ??
            await db.ensureDefaultSetForSite(
              projectId: widget.projectId,
              site: site,
            );
        choice = LocationChoice(site: site, set: set);
      }
    }
    if (!mounted) return;
    setState(() {
      _choice = choice;
      _loadingChoice = false;
    });
  }

  void _onWhere(LocationChoice? choice) {
    setState(() {
      _choice = choice;
      if (choice == null) return;
      _siteCtrl.text = choice.site.name;
      _setCtrl.text = choice.set.locationName;
      // Una escena nueva toma el nombre del lugar; una detectada conserva
      // el que tiene en el guion.
      if (_locationCtrl.text.trim().isEmpty) {
        _locationCtrl.text = choice.placeName;
      }
    });
  }

  Future<void> _onColorChanged(String hex) async {
    if (!_colorCustomizationConfirmed &&
        widget.setsInSite > 1 &&
        _colorScope != ColorEditScope.scene) {
      final palette = context.palette;
      final setName = _setCtrl.text.trim().isEmpty
          ? _locationCtrl.text.trim()
          : _setCtrl.text.trim();
      final siteName = _siteCtrl.text.trim().isEmpty
          ? setName
          : _siteCtrl.text.trim();
      final result = await showSetColorCustomizationDialog(
        context,
        palette: palette,
        setName: setName,
        locationSiteName: siteName,
        initialHex: hex,
        scenesInSet: widget.scenesInSet,
        setsInSite: widget.setsInSite,
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

  @override
  void dispose() {
    _numberCtrl.dispose();
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    _siteCtrl.dispose();
    _setCtrl.dispose();
    _charactersCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final number = int.tryParse(_numberCtrl.text.trim());
    final location = _locationCtrl.text.trim();
    if (number == null || location.isEmpty) return;

    final shootSet = _setCtrl.text.trim().isEmpty
        ? location
        : _setCtrl.text.trim();
    final locationSite = _siteCtrl.text.trim().isEmpty
        ? shootSet
        : _siteCtrl.text.trim();
    final sceneName = _nameCtrl.text.trim();
    final description = _descriptionCtrl.text.trim();
    final characters = parseCharactersInput(_charactersCtrl.text);
    final colorHex = sceneColorForPicker(_pickedHex);

    String? sceneOverride;
    if (_colorScope == ColorEditScope.scene) {
      sceneOverride = persistSceneColor(colorHex);
    }

    Navigator.pop(
      context,
      ImportSceneEditResult(
        colorScope: _colorScope,
        setColor: colorHex,
        scene: NormalizedScene(
          number: number,
          intExt: _intExt,
          dayNight: _dayNight,
          location: location,
          shootSet: shootSet,
          locationSite: locationSite,
          name: sceneName.isEmpty ? null : sceneName,
          description: description.isEmpty ? null : description,
          locationColor: sceneOverride,
          characters: characters,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final canSave =
        int.tryParse(_numberCtrl.text.trim()) != null &&
        _locationCtrl.text.trim().isNotEmpty;

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
                _isEditing ? 'Editar escena' : 'Añadir escena',
                style: AppTypography.titleLarge(palette),
              ),
              if (_locationCtrl.text.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'En el guion: ${_locationCtrl.text.trim()}',
                  style: AppTypography.caption(palette),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              if (_loadingChoice)
                const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                WhereField(
                  projectId: widget.projectId,
                  initial: _choice,
                  listHeight: 180,
                  onChanged: _onWhere,
                ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 84,
                    child: _field(
                      'Escena',
                      _numberCtrl,
                      palette,
                      keyboard: TextInputType.number,
                      onChanged: (_) => setState(() {}),
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
              const SizedBox(height: AppSpacing.md),
              _field(
                'Personajes',
                _charactersCtrl,
                palette,
                hint: 'Separados por comas. Ej. GALA, KARIM, ADIL',
                onChanged: (value) =>
                    setState(() => _characters = parseCharactersInput(value)),
              ),
              if (_characters.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                SceneCharacterChips(characters: _characters, palette: palette),
              ],
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
                    'Color, nombre, descripción y cómo se llama en el guion',
                    style: AppTypography.caption(palette),
                  ),
                  children: [
                    SceneColorEditor(
                      palette: palette,
                      effectiveColor: _effectiveColor,
                      selectedHex: _pickedHex,
                      scope: _colorScope,
                      scenesInSet: widget.scenesInSet,
                      setsInSite: widget.setsInSite,
                      onColorChanged: _onColorChanged,
                      onScopeChanged: (scope) => setState(() {
                        _colorScope = scope;
                        _colorCustomizationConfirmed = true;
                      }),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _field(
                      'Nombre de la escena',
                      _nameCtrl,
                      palette,
                      hint: 'Ej. La huida de Gala (opcional)',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _field(
                      'Lugar tal como lo escribe el guion',
                      _locationCtrl,
                      palette,
                      hint: 'Como aparece en la cabecera de la escena',
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _field(
                      'Descripción',
                      _descriptionCtrl,
                      palette,
                      hint: 'Resumen de la escena, tono, acción…',
                      minLines: 3,
                    ),
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
                    onPressed: canSave ? _save : null,
                    icon: const Icon(Icons.check, size: 18),
                    label: Text(_isEditing ? 'Guardar' : 'Añadir'),
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
    TextInputType? keyboard,
    int minLines = 1,
    ValueChanged<String>? onChanged,
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
          onChanged: onChanged,
        ),
      ],
    );
  }
}

Future<ImportSceneEditResult?> showImportSceneSheet(
  BuildContext context, {
  required int projectId,
  NormalizedScene? scene,
  required int nextNumber,
  required ProjectSceneColors colorContext,
  int scenesInSet = 1,
  int setsInSite = 1,
}) {
  return showDialog<ImportSceneEditResult>(
    context: context,
    builder: (_) => ImportSceneSheet(
      projectId: projectId,
      scene: scene,
      nextNumber: nextNumber,
      colorContext: colorContext,
      scenesInSet: scenesInSet,
      setsInSite: setsInSite,
    ),
  );
}
