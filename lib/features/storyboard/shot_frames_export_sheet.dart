import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/share_origin.dart';
import '../../core/utils/user_error.dart';
import '../../core/widgets/app_snackbar.dart';
import 'shot_export_layout.dart';
import 'storyboard_shot_export_service.dart';

/// Exportar el plano con sus imágenes. Antes se elige cómo: un encuadre, un
/// movimiento (antes y después) o una secuencia (partes), y qué imagen es
/// encuadre, refuerzo o se queda fuera. La elección se guarda en el plano.
Future<void> showShotFramesExportSheet(
  BuildContext context, {
  required Scene scene,
  required Shot shot,
}) => showDialog<void>(
  context: context,
  builder: (_) => _ShotFramesExportDialog(scene: scene, shot: shot),
);

class _ShotFramesExportDialog extends ConsumerStatefulWidget {
  final Scene scene;
  final Shot shot;

  const _ShotFramesExportDialog({required this.scene, required this.shot});

  @override
  ConsumerState<_ShotFramesExportDialog> createState() =>
      _ShotFramesExportDialogState();
}

class _ShotFramesExportDialogState
    extends ConsumerState<_ShotFramesExportDialog> {
  List<ShotLayoutImage>? _images;
  late ShotExportLayout _layout;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final shot = await db.getShotById(widget.shot.id) ?? widget.shot;
    final refs = await db.watchReferencesForShot(shot.id).first;
    final images = shotLayoutImages(shot, refs);
    final saved = ShotExportLayout.decode(shot.exportLayoutJson);
    if (!mounted) return;
    setState(() {
      _images = images;
      _layout =
          saved?.reconciled(images) ?? ShotExportLayout.suggested(shot, images);
    });
  }

  Future<void> _export() async {
    final images = _images;
    if (images == null || _busy) return;
    setState(() => _busy = true);
    final db = ref.read(databaseProvider);
    final origin = shareOrigin(context);
    try {
      await db.updateShotFields(
        widget.shot.id,
        ShotsCompanion(exportLayoutJson: Value(_layout.encode())),
      );
      final project = await db.getProject(widget.scene.projectId);
      final shot = await db.getShotById(widget.shot.id);
      if (project == null || shot == null) return;
      final path = await StoryboardShotExportService.exportWithImages(
        db: db,
        project: project,
        scene: widget.scene,
        shot: shot,
        layout: _layout,
        images: images,
        shareOrigin: origin,
      );
      if (!mounted) return;
      Navigator.pop(context);
      if (path != null) AppSnackBar.show(context, 'Plano exportado en $path');
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, userFriendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final images = _images;
    return AlertDialog(
      title: Text('Exportar plano ${widget.shot.number} con sus imágenes'),
      content: SizedBox(
        width: 620,
        child: images == null
            ? const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              )
            : images.isEmpty
            ? const Text(
                'Este plano no tiene imágenes todavía: añade un storyboard o '
                'referencias para exportarlo así.',
              )
            : _editor(palette, images),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _busy || images == null || images.isEmpty ? null : _export,
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.picture_as_pdf_outlined, size: 18),
          label: const Text('Exportar PDF'),
        ),
      ],
    );
  }

  Widget _editor(AppPalette palette, List<ShotLayoutImage> images) {
    final byId = {for (final i in images) i.id: i};
    // Primero los encuadres en su orden; luego refuerzos y las de fuera.
    final ordered = [
      for (final id in _layout.frames)
        if (byId[id] != null) byId[id]!,
      for (final image in images)
        if (!_layout.frames.contains(image.id)) image,
    ];
    final frameCount = _layout.frames.where(byId.containsKey).length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('¿Cómo es el plano?', style: AppTypography.caption(palette)),
        const SizedBox(height: AppSpacing.xs),
        SegmentedButton<ShotLayoutKind>(
          segments: [
            for (final kind in ShotLayoutKind.values)
              ButtonSegment(value: kind, label: Text(kind.label)),
          ],
          selected: {_layout.kind},
          showSelectedIcon: false,
          onSelectionChanged: (s) =>
              setState(() => _layout = _layout.copyWith(kind: s.first)),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(switch (_layout.kind) {
          ShotLayoutKind.single =>
            'El encuadre grande y, debajo y más pequeñas, las de refuerzo.',
          ShotLayoutKind.move =>
            'Pon de encuadre el de antes del movimiento y el de después, '
                'en ese orden: salen del mismo tamaño con una flecha.',
          ShotLayoutKind.sequence =>
            'Cada encuadre es una parte de la secuencia, en orden y del '
                'mismo tamaño.',
        }, style: AppTypography.caption(palette)),
        const SizedBox(height: AppSpacing.md),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final image in ordered) _row(palette, image, frameCount),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(AppPalette palette, ShotLayoutImage image, int frameCount) {
    final role = _layout.roleOf(image.id);
    final index = _layout.frames.indexOf(image.id);
    final label = role == ShotImageRole.frame
        ? _layout.frameLabel(index, frameCount)
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Opacity(
            opacity: role == ShotImageRole.excluded ? 0.35 : 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.file(
                File(image.path),
                width: role == ShotImageRole.frame ? 112 : 80,
                height: role == ShotImageRole.frame ? 63 : 45,
                fit: BoxFit.cover,
                cacheWidth: 240,
                errorBuilder: (_, _, _) =>
                    const SizedBox(width: 80, height: 45),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(image.name, style: AppTypography.bodyMedium(palette)),
                if (label != null && label.isNotEmpty)
                  Text(
                    '${index + 1}. $label',
                    style: AppTypography.caption(palette),
                  ),
              ],
            ),
          ),
          if (role == ShotImageRole.frame) ...[
            IconButton(
              tooltip: 'Antes',
              visualDensity: VisualDensity.compact,
              onPressed: index > 0
                  ? () => setState(
                      () => _layout = _layout.moveFrame(image.id, -1),
                    )
                  : null,
              icon: const Icon(Icons.arrow_upward, size: 18),
            ),
            IconButton(
              tooltip: 'Después',
              visualDensity: VisualDensity.compact,
              onPressed: index < frameCount - 1
                  ? () =>
                        setState(() => _layout = _layout.moveFrame(image.id, 1))
                  : null,
              icon: const Icon(Icons.arrow_downward, size: 18),
            ),
          ],
          SegmentedButton<ShotImageRole>(
            segments: [
              for (final r in ShotImageRole.values)
                ButtonSegment(
                  value: r,
                  label: Text(r.label, style: const TextStyle(fontSize: 11)),
                ),
            ],
            selected: {role},
            showSelectedIcon: false,
            onSelectionChanged: (s) =>
                setState(() => _layout = _layout.place(image.id, s.first)),
          ),
        ],
      ),
    );
  }
}
