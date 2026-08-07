import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/color_edit_scope.dart';
import '../../core/utils/project_scene_colors.dart';
import '../../core/utils/scene_characters.dart';
import '../../core/utils/scene_color.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/color_scope_prompt_dialog.dart';
import '../../core/widgets/scene_character_chips.dart';
import '../../core/widgets/scene_color_editor.dart';
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

class ImportSceneSheet extends StatefulWidget {
  final NormalizedScene? scene;
  final int nextNumber;
  final ProjectSceneColors colorContext;
  final int scenesInSet;
  final int setsInSite;

  const ImportSceneSheet({
    super.key,
    this.scene,
    required this.nextNumber,
    required this.colorContext,
    this.scenesInSet = 1,
    this.setsInSite = 1,
  });

  @override
  State<ImportSceneSheet> createState() => _ImportSceneSheetState();
}

class _ImportSceneSheetState extends State<ImportSceneSheet> {
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

    final shootSet =
        _setCtrl.text.trim().isEmpty ? location : _setCtrl.text.trim();
    final locationSite =
        _siteCtrl.text.trim().isEmpty ? shootSet : _siteCtrl.text.trim();
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
            _field('Número', _numberCtrl, palette,
                keyboard: TextInputType.number),
            const SizedBox(height: AppSpacing.md),
            _field(
              'Nombre de la escena',
              _nameCtrl,
              palette,
              hint: 'Ej. La huida de Gala (opcional)',
            ),
            const SizedBox(height: AppSpacing.md),
            _dropdown('INT/EXT', _intExt, kIntExtOptions, palette, (v) {
              if (v != null) setState(() => _intExt = v);
            }),
            const SizedBox(height: AppSpacing.md),
            _dropdown('Día / Noche', _dayNight, kDayNightOptions, palette, (v) {
              if (v != null) setState(() => _dayNight = v);
            }),
            const SizedBox(height: AppSpacing.md),
            _field('Lugar en el guion', _locationCtrl, palette,
                hint: 'Como aparece en la slugline'),
            const SizedBox(height: AppSpacing.md),
            _field('Localización', _siteCtrl, palette,
                hint: 'Ej. BOSQUE'),
            const SizedBox(height: AppSpacing.md),
            _field('Set de rodaje', _setCtrl, palette,
                hint: 'Ej. RÍO, ENTRADA DEL BOSQUE'),
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
              SceneCharacterChips(
                characters: _characters,
                palette: palette,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            _field(
              'Descripción',
              _descriptionCtrl,
              palette,
              hint: 'Resumen de la escena, tono, acción…',
              minLines: 3,
            ),
            const SizedBox(height: AppSpacing.md),
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
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: _isEditing ? 'Guardar' : 'Añadir',
              icon: Icons.check,
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
          initialValue: options.contains(value) ? value : options.first,
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

Future<ImportSceneEditResult?> showImportSceneSheet(
  BuildContext context, {
  NormalizedScene? scene,
  required int nextNumber,
  required ProjectSceneColors colorContext,
  int scenesInSet = 1,
  int setsInSite = 1,
}) {
  return showModalBottomSheet<ImportSceneEditResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.palette.surfaceElevated,
    builder: (_) => ImportSceneSheet(
      scene: scene,
      nextNumber: nextNumber,
      colorContext: colorContext,
      scenesInSet: scenesInSet,
      setsInSite: setsInSite,
    ),
  );
}
