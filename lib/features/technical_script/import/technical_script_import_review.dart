import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/shot_reference_import.dart';
import 'docx_technical_script_reader.dart';
import 'technical_script_import_plan.dart';

/// Revisión antes de importar un guion técnico: qué escenas y planos son
/// nuevos, cuáles cambian y qué hacer con textos, referencias y plantas, en
/// general, por escena o por plano.
///
/// [replan] vuelve a comparar con un emparejamiento corregido a mano
/// (etiqueta de la escena del documento → id de la escena del proyecto).
/// Devuelve el plan y las decisiones, o nulo si se cancela.
Future<(TechnicalScriptImportPlan, ImportDecisions)?>
showTechnicalScriptImportReview(
  BuildContext context, {
  required String fileName,
  required TechnicalScriptImportPlan plan,
  required Future<TechnicalScriptImportPlan> Function(Map<String, int?>) replan,
}) {
  return showDialog<(TechnicalScriptImportPlan, ImportDecisions)>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        _ImportReview(fileName: fileName, initialPlan: plan, replan: replan),
  );
}

class _ImportReview extends ConsumerStatefulWidget {
  final String fileName;
  final TechnicalScriptImportPlan initialPlan;
  final Future<TechnicalScriptImportPlan> Function(Map<String, int?>) replan;

  const _ImportReview({
    required this.fileName,
    required this.initialPlan,
    required this.replan,
  });

  @override
  ConsumerState<_ImportReview> createState() => _ImportReviewState();
}

class _ImportReviewState extends ConsumerState<_ImportReview> {
  late TechnicalScriptImportPlan _plan = widget.initialPlan;
  final _decisions = ImportDecisions();
  final _pairing = <String, int?>{};
  late String? _selected = _firstInteresting();
  bool _replanning = false;

  String? _firstInteresting() {
    final scenes = _plan.scenes;
    return (scenes
                .where((s) => s.status != MatchStatus.unchanged)
                .firstOrNull ??
            scenes.firstOrNull)
        ?.key;
  }

  SceneMatch? get _scene =>
      _plan.scenes.where((s) => s.key == _selected).firstOrNull;

  bool get _fresh => _plan.isFresh;

  Future<void> _pair(String docLabel, int? sceneId) async {
    setState(() {
      _pairing[docLabel] = sceneId;
      _replanning = true;
    });
    final next = await widget.replan(Map.of(_pairing));
    if (!mounted) return;
    setState(() {
      _plan = next;
      _replanning = false;
      _selected = 'doc:$docLabel';
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final size = MediaQuery.sizeOf(context);
    final narrow = size.width < 820;
    return Dialog(
      backgroundColor: palette.surfaceElevated,
      insetPadding: EdgeInsets.all(narrow ? AppSpacing.sm : AppSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180, maxHeight: 900),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(palette),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: Stack(
                  children: [
                    narrow
                        ? Column(
                            children: [
                              SizedBox(height: 150, child: _index(palette)),
                              const SizedBox(height: AppSpacing.sm),
                              Expanded(child: _detail(palette)),
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(width: 240, child: _index(palette)),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(child: _detail(palette)),
                            ],
                          ),
                    if (_replanning)
                      const Positioned.fill(
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _footer(palette),
            ],
          ),
        ),
      ),
    );
  }

  // ── Cabecera: resumen y atajos para todo ─────

  Widget _header(AppPalette palette) {
    final p = _plan;
    final general = _decisions.general.over(_decisions.modeDefaults);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Importar guion técnico',
                    style: AppTypography.titleLarge(palette),
                  ),
                  Text(
                    widget.fileName,
                    style: AppTypography.caption(palette),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!_fresh)
              _Choice<ImportMode>(
                values: ImportMode.values,
                selected: _decisions.mode,
                label: (m) => m.label,
                onChanged: (m) => setState(() => _decisions.mode = m),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (!_fresh) _whatHappens(palette, general),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            if (_fresh)
              _chip(
                palette,
                '${p.document.scenes.length} escenas · '
                '${p.document.shotCount} planos',
                palette.accent,
              ),
            if (!_fresh && p.newScenes > 0)
              _chip(palette, '${p.newScenes} escenas nuevas', palette.success),
            if (!_fresh && p.newShots > 0)
              _chip(palette, '${p.newShots} planos nuevos', palette.success),
            if (p.changedShots > 0)
              _chip(
                palette,
                '${p.changedShots} planos con cambios',
                palette.warning,
              ),
            _chip(
              palette,
              '${p.newReferences} referencias · ${p.newPlans} plantas',
              palette.accent,
            ),
            if (p.onlyInAppScenes + p.onlyInAppShots > 0)
              _chip(
                palette,
                '${p.onlyInAppScenes + p.onlyInAppShots} solo en la app',
                palette.error,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (!_fresh)
              _labeled(
                palette,
                'Cambios',
                _Choice<TextChoice>(
                  values: TextChoice.values,
                  selected: general.text!,
                  label: (c) => c.label,
                  onChanged: (c) => setState(
                    () => _decisions.setGeneral((g) => g.copyWith(text: c)),
                  ),
                ),
              ),
            if (!_fresh)
              _labeled(
                palette,
                'Referencias',
                _Choice<ReferenceMode>(
                  values: ReferenceMode.values,
                  selected: general.references!,
                  label: (c) => c.label,
                  onChanged: (c) => setState(
                    () =>
                        _decisions.setGeneral((g) => g.copyWith(references: c)),
                  ),
                ),
              ),
            _labeled(
              palette,
              'Planta',
              _Choice<PlanDestination>(
                values: PlanDestination.values,
                selected: general.planDestination!,
                label: (c) => c.label,
                onChanged: (c) => setState(
                  () => _decisions.setGeneral(
                    (g) => g.copyWith(planDestination: c),
                  ),
                ),
              ),
            ),
            _labeled(
              palette,
              'Ver',
              _Choice<PlanView>(
                values: PlanView.values,
                selected: general.planView!,
                label: (c) => c.label,
                onChanged: (c) => setState(
                  () => _decisions.setGeneral((g) => g.copyWith(planView: c)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  bool? _summaryOpen;

  /// «Qué va a pasar», en frases: lo que hará la importación con lo que
  /// está elegido ahora (cada escena o plano puede cambiarlo en su ficha).
  Widget _whatHappens(AppPalette palette, ImportChoices general) {
    final p = _plan;
    final lines = <(IconData, String)>[
      if (general.addNew!)
        (
          Icons.add_circle_outline,
          p.newScenes + p.newShots == 0
              ? 'No hay escenas ni planos nuevos en el Word.'
              : 'Se añaden ${p.newScenes} escenas y ${p.newShots} planos '
                    'nuevos del Word.',
        )
      else
        (Icons.block, 'No se añade nada nuevo del Word.'),
      (
        Icons.edit_note,
        general.text == TextChoice.ours
            ? 'En los planos que ya tienes se quedan tus textos (encuadre, '
                  'acción, notas…); lo que tengas vacío se rellena con el Word.'
            : 'En los planos que ya tienes, los textos se cambian por los '
                  'del Word.',
      ),
      (Icons.photo_library_outlined, switch (general.references!) {
        ReferenceMode.front =>
          'Imágenes de referencia: las del Word pasan a ser las principales y '
              'las tuyas quedan detrás.',
        ReferenceMode.back =>
          'Imágenes de referencia: las del Word se añaden detrás de las tuyas.',
        ReferenceMode.replace =>
          'Imágenes de referencia: se quitan las tuyas y quedan solo las del '
              'Word.',
        ReferenceMode.skip => 'Las imágenes de referencia del Word no se '
            'importan.',
      }),
      if (general.references != ReferenceMode.skip)
        (
          Icons.filter_none,
          'Una imagen que ya tienes no se copia otra vez, aunque el Word la '
              'traiga más pequeña.',
        ),
      if (p.onlyInAppScenes + p.onlyInAppShots > 0)
        general.deleteOnlyInApp!
            ? (
                Icons.delete_outline,
                'Se borran ${p.onlyInAppScenes + p.onlyInAppShots} escenas o '
                    'planos que solo están en la app (en su ficha puedes '
                    'conservarlos).',
              )
            : (
                Icons.check_circle_outline,
                'Se conservan ${p.onlyInAppScenes + p.onlyInAppShots} escenas '
                    'o planos que solo están en la app.',
              ),
      (Icons.backup_outlined, 'Antes de aplicar se guarda una copia: podrás '
          'volver atrás desde Importar › Volver al guion anterior.'),
    ];
    // En pantallas estrechas empieza plegado: si no, no cabe la lista.
    final open = _summaryOpen ??= MediaQuery.sizeOf(context).width >= 1000;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: palette.surfaceOverlay.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _summaryOpen = !open),
            child: Row(
              children: [
                Text('Qué va a pasar', style: AppTypography.label(palette)),
                Icon(
                  open ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: palette.textSecondary,
                ),
              ],
            ),
          ),
          if (open) const SizedBox(height: 4),
          if (open)
          for (final (icon, text) in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 14, color: palette.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(text, style: AppTypography.caption(palette)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Índice de escenas ────────────────────────

  Widget _index(AppPalette palette) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListView(
        padding: const EdgeInsets.all(6),
        children: [
          for (final scene in _plan.scenes)
            _IndexTile(
              scene: scene,
              selected: scene.key == _selected,
              deleted:
                  scene.imported == null &&
                  _decisions.forScene(scene.key).deleteOnlyInApp == true,
              fresh: _fresh,
              onTap: () => setState(() => _selected = scene.key),
            ),
        ],
      ),
    );
  }

  // ── Detalle de la escena elegida ─────────────

  Widget _detail(AppPalette palette) {
    final scene = _scene;
    if (scene == null) return const SizedBox.shrink();
    final choices = _decisions.forScene(scene.key);
    final body = AppTypography.bodyMedium(
      palette,
    ).copyWith(color: palette.textPrimary);
    final unpairedApp = [
      for (final s in _plan.scenes)
        if (s.imported == null && s.existing != null) s.existing!,
    ];

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  scene.heading,
                  style: AppTypography.titleMedium(palette),
                ),
              ),
              if (!_fresh) _statusChip(palette, scene.status),
            ],
          ),
          if (scene.imported != null &&
              scene.existing != null &&
              scene.existing!.label != scene.imported!.label)
            Text(
              'Unida a la escena ${scene.existing!.label}. '
              '${scene.existing!.locationCanonical} del proyecto',
              style: AppTypography.caption(palette),
            ),
          if (scene.existing?.scriptLinked == true && scene.imported != null)
            Text(
              'Vinculada al guion literario: su número y su cabecera no '
              'cambian.',
              style: AppTypography.caption(palette),
            ),
          const SizedBox(height: AppSpacing.sm),

          // Emparejamiento a mano.
          if (scene.imported != null && !_fresh)
            Wrap(
              spacing: 8,
              children: [
                if (scene.existing != null)
                  TextButton(
                    onPressed: () => _pair(scene.imported!.label, null),
                    child: const Text('No es la misma escena'),
                  ),
                if (scene.existing == null && unpairedApp.isNotEmpty)
                  PopupMenuButton<int>(
                    tooltip: 'Unirla a una escena que ya tienes',
                    color: palette.surfaceElevated,
                    onSelected: (id) => _pair(scene.imported!.label, id),
                    itemBuilder: (_) => [
                      for (final s in unpairedApp)
                        PopupMenuItem(
                          value: s.id,
                          child: Text('${s.label}. ${s.locationCanonical}'),
                        ),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        'Es en realidad…',
                        style: body.copyWith(color: palette.accent),
                      ),
                    ),
                  ),
              ],
            ),

          // Escena solo en la app.
          if (scene.imported == null)
            _labeled(
              palette,
              'No está en el documento',
              _Choice<bool>(
                values: const [false, true],
                selected: choices.deleteOnlyInApp == true,
                label: (d) => d ? 'Borrar' : 'Conservar',
                onChanged: (d) => setState(
                  () => _decisions.setScene(
                    scene.key,
                    (c) => c.copyWith(deleteOnlyInApp: d),
                  ),
                ),
              ),
            )
          else ...[
            // Atajos de la escena.
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (scene.existing == null && !_fresh)
                  _labeled(
                    palette,
                    'Escena nueva',
                    _Choice<bool>(
                      values: const [true, false],
                      selected: choices.addNew != false,
                      label: (a) => a ? 'Incorporar' : 'Omitir',
                      onChanged: (a) => setState(
                        () => _decisions.setScene(
                          scene.key,
                          (c) => c.copyWith(addNew: a),
                        ),
                      ),
                    ),
                  ),
                if (scene.existing != null)
                  _labeled(
                    palette,
                    'Esta escena',
                    _Choice<TextChoice>(
                      values: TextChoice.values,
                      selected: choices.text!,
                      label: (c) => c.label,
                      onChanged: (t) => setState(
                        () => _decisions.setScene(
                          scene.key,
                          (c) => c.copyWith(text: t),
                        ),
                      ),
                    ),
                  ),
                if (scene.existing != null &&
                    scene.shots.any((s) => s.newReferences.isNotEmpty))
                  _labeled(
                    palette,
                    'Referencias',
                    _Choice<ReferenceMode>(
                      values: ReferenceMode.values,
                      selected: choices.references!,
                      label: (c) => c.label,
                      onChanged: (r) => setState(
                        () => _decisions.setScene(
                          scene.key,
                          (c) => c.copyWith(references: r),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            for (final diff in scene.headingDiffs)
              _DiffLine(
                diff: diff,
                struck: choices.text == TextChoice.document,
              ),

            // Planta de la escena.
            if (scene.documentPlans.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              _PlanBlock(
                images: scene.documentPlans,
                ourSketches: {
                  for (final s in scene.shots)
                    if (s.existing != null) ...planSketchesOf(s.existing!),
                }.toList(),
                destination: choices.planDestination!,
                view: choices.planView!,
                onDestination: (d) => setState(
                  () => _decisions.setScene(
                    scene.key,
                    (c) => c.copyWith(planDestination: d),
                  ),
                ),
                onView: (v) => setState(
                  () => _decisions.setScene(
                    scene.key,
                    (c) => c.copyWith(planView: v),
                  ),
                ),
              ),
            ],
          ],
          const SizedBox(height: AppSpacing.md),
          for (final shot in scene.shots) _shotCard(palette, scene, shot),
        ],
      ),
    );
  }

  Widget _shotCard(AppPalette palette, SceneMatch scene, ShotMatch shot) {
    final c = _decisions.forShot(scene.key, shot.key);
    final sceneOnlyInApp = scene.imported == null;
    void set(ImportChoices Function(ImportChoices) edit) =>
        setState(() => _decisions.setShot(shot.key, edit));
    final deleted =
        (sceneOnlyInApp && _decisions.forScene(scene.key).deleteOnlyInApp!) ||
        (shot.imported == null && c.deleteOnlyInApp);
    final skipped = shot.existing == null && !c.addNew;
    final doc = shot.imported;

    return Opacity(
      opacity: deleted || skipped ? 0.45 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: palette.border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Plano ${shot.number}',
                  style: AppTypography.titleMedium(palette),
                ),
                if (!_fresh) _statusChip(palette, shot.status),
                if (shot.imported == null && !sceneOnlyInApp)
                  _Choice<bool>(
                    values: const [false, true],
                    selected: c.deleteOnlyInApp,
                    label: (d) => d ? 'Borrar' : 'Conservar',
                    onChanged: (d) =>
                        set((x) => x.copyWith(deleteOnlyInApp: d)),
                  )
                else if (shot.existing == null && !_fresh)
                  _Choice<bool>(
                    values: const [true, false],
                    selected: c.addNew,
                    label: (a) => a ? 'Incorporar' : 'Omitir',
                    onChanged: (a) => set((x) => x.copyWith(addNew: a)),
                  )
                else if (shot.diffs.isNotEmpty)
                  _Choice<TextChoice>(
                    values: TextChoice.values,
                    selected: c.text,
                    label: (t) => t.label,
                    onChanged: (t) => set((x) => x.copyWith(text: t)),
                  ),
              ],
            ),
            if (doc != null && shot.existing == null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  [
                    doc.framing,
                    [
                      doc.lens,
                      doc.angle,
                      doc.movement,
                    ].whereType<String>().join(' '),
                    if (doc.characters.isNotEmpty) doc.characters.join(', '),
                    doc.action,
                  ].whereType<String>().where((t) => t.isNotEmpty).join(' · '),
                  style: AppTypography.caption(palette),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (shot.imported == null && shot.existing != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  [
                    shot.existing!.framing,
                    shot.existing!.lens,
                  ].whereType<String>().join(' · '),
                  style: AppTypography.caption(palette),
                ),
              ),
            for (final diff in shot.diffs)
              _DiffLine(
                diff: diff,
                struck: c.text == TextChoice.document || diff.fillsEmpty,
              ),
            if (doc != null) _references(palette, scene, shot, c),
            if (doc != null &&
                (shot.existing == null
                    ? doc.plans.isNotEmpty
                    : shot.newPlan != null))
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _labeled(
                      palette,
                      'Planta',
                      _Choice<PlanDestination>(
                        values: PlanDestination.values,
                        selected: c.planDestination,
                        label: (d) => d.label,
                        onChanged: (d) =>
                            set((x) => x.copyWith(planDestination: d)),
                      ),
                    ),
                    _labeled(
                      palette,
                      'Ver',
                      _Choice<PlanView>(
                        values: PlanView.values,
                        selected: c.planView,
                        label: (v) => v.label,
                        onChanged: (v) => set((x) => x.copyWith(planView: v)),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _references(
    AppPalette palette,
    SceneMatch scene,
    ShotMatch shot,
    ResolvedChoices c,
  ) {
    final incoming = shot.existing == null
        ? shot.imported!.references
        : shot.newReferences;
    if (incoming.isEmpty) return const SizedBox.shrink();
    final mode = shot.existing == null ? ReferenceMode.back : c.references;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 4,
            children: [
              for (final image in incoming)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: _DocThumb(
                    image: image,
                    included:
                        mode != ReferenceMode.skip &&
                        _decisions.includesReference(shot.key, image),
                    onTap: () => setState(
                      () => _decisions.toggleReference(shot.key, image),
                    ),
                  ),
                ),
              if (shot.existing case final existing?)
                _OurReferences(
                  shot: existing,
                  dimmed: mode == ReferenceMode.replace,
                ),
            ],
          ),
          if (shot.existing != null)
            _Choice<ReferenceMode>(
              values: ReferenceMode.values,
              selected: c.references,
              label: (r) => r.label,
              onChanged: (r) => setState(
                () => _decisions.setShot(
                  shot.key,
                  (x) => x.copyWith(references: r),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Pie ──────────────────────────────────────

  Widget _footer(AppPalette palette) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Antes de aplicar se guarda una copia de la base.',
            style: AppTypography.caption(palette),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar', style: AppTypography.bodyMedium(palette)),
        ),
        const SizedBox(width: AppSpacing.sm),
        FilledButton(
          onPressed: _replanning
              ? null
              : () => Navigator.pop(context, (_plan, _decisions)),
          child: const Text('Aplicar'),
        ),
      ],
    );
  }

  // ── Piezas ───────────────────────────────────

  Widget _chip(AppPalette palette, String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: AppTypography.caption(palette).copyWith(color: color),
    ),
  );

  Widget _statusChip(AppPalette palette, MatchStatus status) =>
      _chip(palette, status.label, switch (status) {
        MatchStatus.added => palette.success,
        MatchStatus.changed => palette.warning,
        MatchStatus.unchanged => palette.textTertiary,
        MatchStatus.onlyInApp => palette.error,
      });

  Widget _labeled(AppPalette palette, String label, Widget child) => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text(label, style: AppTypography.caption(palette)),
      const SizedBox(width: 6),
      child,
    ],
  );
}

/// Selector compacto de una opción entre pocas.
class _Choice<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  const _Choice({
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: _segmented(),
  );

  Widget _segmented() => SegmentedButton<T>(
    showSelectedIcon: false,
    style: const ButtonStyle(
      visualDensity: VisualDensity(horizontal: -3, vertical: -3),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    segments: [
      for (final v in values)
        ButtonSegment(
          value: v,
          label: Text(label(v), style: const TextStyle(fontSize: 12)),
        ),
    ],
    selected: {selected},
    onSelectionChanged: (s) => onChanged(s.first),
  );
}

class _IndexTile extends StatelessWidget {
  final SceneMatch scene;
  final bool selected;
  final bool deleted;
  final bool fresh;
  final VoidCallback onTap;

  const _IndexTile({
    required this.scene,
    required this.selected,
    required this.deleted,
    required this.fresh,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final changes = scene.shots
        .where(
          (s) =>
              s.status != MatchStatus.unchanged &&
              s.status != MatchStatus.onlyInApp,
        )
        .length;
    final location =
        scene.imported?.location ?? scene.existing!.locationPureName;
    final status = scene.status;
    final color = switch (status) {
      MatchStatus.added => palette.success,
      MatchStatus.changed => palette.warning,
      MatchStatus.unchanged => palette.textTertiary,
      MatchStatus.onlyInApp => palette.error,
    };
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? palette.accent.withValues(alpha: 0.14) : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${scene.label} · $location',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMedium(palette).copyWith(
                color: palette.textPrimary,
                decoration: deleted ? TextDecoration.lineThrough : null,
              ),
            ),
            Text(
              fresh
                  ? '${scene.shots.length} planos'
                  : switch (status) {
                      MatchStatus.changed =>
                        changes == 1 ? '1 cambio' : '$changes cambios',
                      _ => status.label,
                    },
              style: AppTypography.caption(palette).copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lo nuestro → lo del documento. Tachado lo que se va a perder.
class _DiffLine extends StatelessWidget {
  final FieldDiff diff;

  /// Gana el documento en este campo.
  final bool struck;

  const _DiffLine({required this.diff, required this.struck});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final caption = AppTypography.caption(palette);
    final text = AppTypography.bodyMedium(
      palette,
    ).copyWith(color: palette.textPrimary, fontSize: 13);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(diff.label, style: caption)),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: diff.ours ?? '—',
                    style: struck
                        ? caption.copyWith(
                            decoration: TextDecoration.lineThrough,
                          )
                        : text,
                  ),
                  TextSpan(text: '  →  ', style: caption),
                  TextSpan(
                    text: diff.document ?? '—',
                    style: struck
                        ? text
                        : caption.copyWith(
                            decoration: TextDecoration.lineThrough,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Miniatura de una imagen del documento; tocarla la quita o la vuelve a
/// poner.
class _DocThumb extends StatelessWidget {
  final ImportedImage image;
  final bool included;
  final VoidCallback? onTap;

  const _DocThumb({required this.image, required this.included, this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Tooltip(
      message: onTap == null
          ? 'Del documento'
          : included
          ? 'Del documento · tocar para no importarla'
          : 'No se importa · tocar para importarla',
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Opacity(
              opacity: included ? 1 : 0.3,
              child: Container(
                width: 72,
                height: 48,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: included ? palette.accent : palette.border,
                    width: included ? 1.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.memory(
                  image.bytes,
                  fit: BoxFit.cover,
                  cacheWidth: 160,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.broken_image_outlined, size: 18),
                ),
              ),
            ),
            if (onTap != null)
              Positioned(
                right: 2,
                top: 2,
                child: Icon(
                  included ? Icons.check_circle : Icons.circle_outlined,
                  size: 14,
                  color: included ? palette.accent : palette.textTertiary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FileThumb extends StatelessWidget {
  final String path;
  final bool dimmed;
  final String tooltip;

  const _FileThumb({
    required this.path,
    this.dimmed = false,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Tooltip(
      message: tooltip,
      child: Opacity(
        opacity: dimmed ? 0.3 : 1,
        child: Container(
          width: 72,
          height: 48,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            border: Border.all(color: palette.border),
            borderRadius: BorderRadius.circular(4),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.file(
            File(path),
            fit: BoxFit.cover,
            cacheWidth: 160,
            errorBuilder: (_, _, _) =>
                const Icon(Icons.broken_image_outlined, size: 18),
          ),
        ),
      ),
    );
  }
}

/// Las referencias que el plano ya tiene, detrás de las del documento.
class _OurReferences extends ConsumerWidget {
  final Shot shot;
  final bool dimmed;

  const _OurReferences({required this.shot, required this.dimmed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    return FutureBuilder<List<ShotReference>>(
      future: db.watchReferencesForShot(shot.id).first,
      builder: (context, snap) {
        final paths = referenceImagesOf(shot, snap.data ?? const []);
        if (paths.isEmpty) return const SizedBox.shrink();
        return Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                'nuestras',
                style: AppTypography.caption(context.palette),
              ),
            ),
            for (final path in paths.take(4))
              _FileThumb(
                path: path,
                dimmed: dimmed,
                tooltip: dimmed ? 'Nuestra · se quita' : 'Nuestra',
              ),
          ],
        );
      },
    );
  }
}

/// La planta del documento junto a la nuestra, con dónde entra y qué se ve.
class _PlanBlock extends StatelessWidget {
  final List<ImportedImage> images;
  final List<String> ourSketches;
  final PlanDestination destination;
  final PlanView view;
  final ValueChanged<PlanDestination> onDestination;
  final ValueChanged<PlanView> onView;

  const _PlanBlock({
    required this.images,
    required this.ourSketches,
    required this.destination,
    required this.view,
    required this.onDestination,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final caption = AppTypography.caption(palette);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Planta de la escena', style: AppTypography.label(palette)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('documento', style: caption),
              for (final image in images)
                _DocThumb(
                  image: image,
                  included: destination != PlanDestination.skip,
                ),
              const SizedBox(width: 8),
              Text(
                ourSketches.isEmpty ? 'nuestra: la planta de la app' : 'nuestra',
                style: caption,
              ),
              for (final path in ourSketches.take(3))
                _FileThumb(path: path, tooltip: 'Nuestro boceto'),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Entra como', style: caption),
                  const SizedBox(width: 6),
                  _Choice<PlanDestination>(
                    values: PlanDestination.values,
                    selected: destination,
                    label: (d) => d.label,
                    onChanged: onDestination,
                  ),
                ],
              ),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Se ve', style: caption),
                  const SizedBox(width: 6),
                  _Choice<PlanView>(
                    values: PlanView.values,
                    selected: view,
                    label: (v) => v.label,
                    onChanged: onView,
                  ),
                ],
              ),
            ],
          ),
          Text(switch (destination) {
            PlanDestination.shotSketch =>
              'Se añade como boceto en la casilla Planta de cada plano que '
                  'la lleva. «Se ve» elige qué enseña la casilla: nuestra '
                  'planta dibujada, el boceto del documento o las dos.',
            PlanDestination.looseSketch =>
              'Se guarda como boceto suelto en Plantas de cámara y luz, '
                  'sin asociarlo a ningún plano.',
            PlanDestination.skip => 'La planta del documento no se importa.',
          }, style: caption),
        ],
      ),
    );
  }
}
