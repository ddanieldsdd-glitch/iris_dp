import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../shared/equipment/light_kind.dart';
import '../../../shared/equipment/light_quick_add.dart';
import '../../camera_plan/camera_plan_constants.dart';
import '../../camera_plan/light/exposure.dart';
import '../../camera_plan/light/photometry.dart';
import '../../camera_plan/light_symbols.dart';

/// Símbolo de planta con el que se dibuja cada formato.
LightType symbolForFormat(LightFormat format) => switch (format) {
  LightFormat.fresnel => LightType.fresnelMedium,
  LightFormat.panel => LightType.lightPanel,
  LightFormat.flex => LightType.led1x1,
  LightFormat.tube => LightType.floSingle,
  LightFormat.cob => LightType.led,
  LightFormat.balloon => LightType.chimera,
  LightFormat.practical => LightType.practical,
  LightFormat.open => LightType.par,
  LightFormat.profile => LightType.ellipsoidal,
};

/// Da de alta una luz que no está en el catálogo. Devuelve la luz creada
/// (o la que ya había con esa marca y modelo), o `null` si se cancela.
Future<Light?> showLightQuickAdd(
  BuildContext context, {
  String initialModel = '',
  String confirmLabel = 'Añadir',
}) => showDialog<Light>(
  context: context,
  builder: (_) => LightQuickAddSheet(
    initialModel: initialModel,
    confirmLabel: confirmLabel,
  ),
);

class LightQuickAddSheet extends ConsumerStatefulWidget {
  final String initialModel;
  final String confirmLabel;

  const LightQuickAddSheet({
    super.key,
    this.initialModel = '',
    this.confirmLabel = 'Añadir',
  });

  @override
  ConsumerState<LightQuickAddSheet> createState() => _LightQuickAddSheetState();
}

class _LightQuickAddSheetState extends ConsumerState<LightQuickAddSheet> {
  LightFormat _format = LightFormat.fresnel;
  LightTechnology? _tech;
  bool _showTech = false;
  LightColorMode _color = LightColorMode.fixed;
  final _brand = TextEditingController();
  late final _model = TextEditingController(text: widget.initialModel);
  final _watts = TextEditingController();
  final _cctLow = TextEditingController();
  final _cctHigh = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_brand, _model, _watts, _cctLow, _cctHigh]) {
      c.dispose();
    }
    super.dispose();
  }

  int? _int(TextEditingController c) =>
      int.tryParse(c.text.trim().replaceAll(RegExp(r'[^\d]'), ''));

  LightQuickAddDraft get _draft => LightQuickAddDraft(
    format: _format,
    technology: _tech,
    brand: _brand.text,
    model: _model.text,
    color: _color,
    cctMin: _int(_cctLow),
    cctMax: _color == LightColorMode.fixed ? null : _int(_cctHigh),
    watts: _int(_watts) ?? 0,
  );

  Future<void> _save() async {
    final draft = _draft;
    if (draft.problems.isNotEmpty) return;
    setState(() => _saving = true);
    try {
      final result = await LightQuickAdd.add(ref.read(databaseProvider), draft);
      if (!mounted) return;
      if (!result.created) {
        AppSnackBar.show(
          context,
          '${result.light.brand} ${result.light.model} ya estaba en el '
          'catálogo: se usa esa.',
        );
      }
      Navigator.of(context).pop(result.light);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnackBar.showError(context, 'No se pudo guardar la luz: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final draft = _draft;
    final kind = draft.kind;
    final (low, high) = draft.cctRange;
    final source = LightSource.estimated(
      watts: draft.watts.toDouble(),
      tech: LightTech.values.byName(kind.technology.code),
      beamDeg: _format.beamDeg,
      sizeM: _format.sizeM,
    );
    final id = LightQuickAdd.externalIdFor(_brand.text, _model.text);

    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: AppTypography.caption(
          palette,
        ).copyWith(color: palette.textTertiary, letterSpacing: 1, fontSize: 11),
      ),
    );

    Widget field(
      TextEditingController c,
      String hint, {
      bool number = false,
      String? suffix,
      Key? key,
    }) => TextField(
      key: key,
      controller: c,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      style: AppTypography.bodyMedium(palette),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        suffixText: suffix,
      ),
      onChanged: (_) => setState(() {}),
    );

    Widget formatCard(LightFormat f) {
      final selected = f == _format;
      return Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          key: ValueKey('format-${f.code}'),
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() {
            _format = f;
            _tech = null;
          }),
          child: Container(
            width: 112,
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? palette.accent : palette.border,
              ),
              color: selected
                  ? palette.accent.withValues(alpha: 0.12)
                  : Colors.transparent,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LightSymbolPreview(type: symbolForFormat(f), size: 28),
                const SizedBox(height: 4),
                Text(
                  f.label,
                  style: AppTypography.caption(
                    palette,
                  ).copyWith(color: palette.textPrimary),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget fact(String title, String value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.caption(
            palette,
          ).copyWith(color: palette.textTertiary, fontSize: 11),
        ),
        Text(value, style: AppTypography.mono(palette)),
      ],
    );

    final problems = draft.problems;
    return Dialog(
      backgroundColor: palette.surface,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Nueva luz', style: AppTypography.titleMedium(palette)),
              const SizedBox(height: 4),
              Text(
                'El formato ya dice cómo emite. Lo demás queda pendiente de '
                'configurar hasta que el Excel de material traiga su ficha.',
                style: AppTypography.caption(
                  palette,
                ).copyWith(color: palette.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              label('Formato'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final f in LightFormat.values) formatCard(f)],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        label('Marca'),
                        field(_brand, 'ARRI', key: const Key('brand')),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        label('Modelo'),
                        field(_model, 'L7-C', key: const Key('model')),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              label('Color'),
              SegmentedButton<LightColorMode>(
                segments: [
                  for (final m in LightColorMode.values)
                    ButtonSegment(value: m, label: Text(m.label)),
                ],
                selected: {_color},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() {
                  _color = s.first;
                  _cctLow.clear();
                  _cctHigh.clear();
                }),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        label(
                          _color == LightColorMode.fixed ? 'Temperatura' : 'De',
                        ),
                        field(_cctLow, '$low', number: true, suffix: 'K'),
                      ],
                    ),
                  ),
                  if (_color != LightColorMode.fixed) ...[
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          label('A'),
                          field(_cctHigh, '$high', number: true, suffix: 'K'),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        label('Vatios'),
                        field(
                          _watts,
                          '650',
                          number: true,
                          suffix: 'W',
                          key: const Key('watts'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_showTech)
                DropdownButtonFormField<LightTechnology>(
                  initialValue: kind.technology,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Tecnología',
                  ),
                  items: [
                    for (final t in LightTechnology.values)
                      DropdownMenuItem(value: t, child: Text(t.label)),
                  ],
                  onChanged: (t) => setState(() => _tech = t),
                )
              else
                Row(
                  children: [
                    Text(
                      'Tecnología: ${kind.technology.label}'
                      '${_tech == null ? ' (la de su formato)' : ''}',
                      style: AppTypography.caption(
                        palette,
                      ).copyWith(color: palette.textSecondary),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _showTech = true),
                      child: const Text('Cambiar'),
                    ),
                  ],
                ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: palette.surfaceOverlay,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '● Pendiente de configurar',
                      style: AppTypography.caption(
                        palette,
                      ).copyWith(color: palette.accent),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.lg,
                      runSpacing: AppSpacing.sm,
                      children: [
                        fact(
                          'Cómo emite',
                          _format.isOmni
                              ? 'en todas direcciones'
                              : 'haz de ${_format.beamDeg.round()}°',
                        ),
                        fact(
                          'Tamaño',
                          '${_format.sizeM.toString().replaceAll('.', ',')} m',
                        ),
                        fact(
                          'Estimado a 3 m',
                          draft.watts > 0
                              ? formatLux(source.illuminance(3))
                              : '—',
                        ),
                        fact('Tipo', kind.code),
                        fact(
                          'Identificador para el Excel',
                          id.isEmpty ? '—' : id,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      problems.isEmpty ? '' : problems.join(' · '),
                      style: AppTypography.caption(
                        palette,
                      ).copyWith(color: palette.textTertiary),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    key: const Key('quick-add-save'),
                    onPressed: problems.isEmpty && !_saving ? _save : null,
                    child: Text(widget.confirmLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
