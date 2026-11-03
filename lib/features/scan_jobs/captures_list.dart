import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/sync/realtime_hub.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_snackbar.dart';
import 'capture_store.dart';

/// Las capturas del iPhone de un set (o de una localización) con su estado:
/// en el iPhone, enviándose, en la cola del PC, construyéndose, listas.
class CapturesList extends ConsumerStatefulWidget {
  final int projectId;
  final int? setId;
  final int? siteId;

  const CapturesList({
    super.key,
    required this.projectId,
    this.setId,
    this.siteId,
  });

  @override
  ConsumerState<CapturesList> createState() => _CapturesListState();
}

class _CapturesListState extends ConsumerState<CapturesList> {
  StreamSubscription<List<LocationCapture>>? _sub;
  List<LocationCapture> _captures = const [];

  /// Capturas sueltas de este iPhone (no llegaron a registrarse).
  List<OrphanCapture> _orphans = const [];
  bool _adopting = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadOrphans());
    _sub = ref
        .read(databaseProvider)
        .watchCapturesForProject(widget.projectId)
        .listen((all) {
          if (!mounted) return;
          setState(
            () => _captures = [
              for (final c in all)
                if (widget.setId != null
                    ? c.setId == widget.setId
                    : c.siteId == widget.siteId)
                  c,
            ],
          );
        });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _loadOrphans() async {
    if (!Platform.isIOS) return;
    final found = await CaptureStore.orphans(ref.read(databaseProvider));
    if (mounted) setState(() => _orphans = found);
  }

  Future<void> _adopt(OrphanCapture o) async {
    if (_adopting) return;
    setState(() => _adopting = true);
    try {
      await CaptureStore.register(
        ref.read(databaseProvider),
        projectId: widget.projectId,
        path: o.path,
        name: o.name,
        setId: widget.setId,
        siteId: widget.siteId,
      );
    } finally {
      if (mounted) setState(() => _adopting = false);
      await _loadOrphans();
    }
  }

  Future<void> _deleteOrphan(OrphanCapture o) async {
    final ok = await _confirm(
      'Borrar «${o.name}»',
      'Se borran sus fotos de este iPhone. No se puede deshacer.',
    );
    if (!ok) return;
    await CaptureStore.deleteOrphan(o);
    await _loadOrphans();
  }

  /// La hoja de compartir del iPad y del iPhone necesita un punto de origen.
  Rect? _origin() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _share(LocationCapture c) async {
    final zip = await CaptureStore.zipFor(c.uid!);
    if (!await zip.exists()) {
      if (mounted) {
        AppSnackBar.show(context, 'El .zip de esta captura no está aquí.');
      }
      return;
    }
    await Share.shareXFiles(
      [XFile(zip.path)],
      subject: 'Captura ${c.name}',
      sharePositionOrigin: _origin(),
    );
  }

  Future<bool> _confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Borrar'),
            ),
          ],
        ),
      ) ==
      true;

  Future<void> _retry(LocationCapture c) async {
    final zip = await CaptureStore.zipFor(c.uid!);
    // En el PC que la construía (con el zip aquí) vuelve a la cola; en el
    // iPhone, a enviarse.
    final here = c.builderInstallId == await InstallId.get();
    final status = here && await zip.exists()
        ? CaptureStatus.onPc
        : CaptureStatus.onPhone;
    await ref
        .read(databaseProvider)
        .updateCapture(
          c.uid!,
          LocationCapturesCompanion(
            status: Value(status),
            progress: const Value(0),
            error: const Value(null),
          ),
        );
  }

  Future<void> _delete(LocationCapture c) async {
    final ok = await _confirm(
      'Borrar «${c.name}»',
      'Se borra la captura y sus fotos de este equipo. El escaneo ya hecho, '
          'si lo hay, se queda en el set.',
    );
    if (!ok) return;
    await CaptureStore.deleteLocal(c.uid!);
    await ref.read(databaseProvider).deleteCapture(c);
  }

  @override
  Widget build(BuildContext context) {
    if (_captures.isEmpty && _orphans.isEmpty) return const SizedBox.shrink();
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_orphans.isNotEmpty) ...[
          Text('Capturas sin asignar', style: AppTypography.label(palette)),
          Text(
            'Fotos de este iPhone que no llegaron a guardarse en ningún set.',
            style: AppTypography.caption(palette),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [for (final o in _orphans) _orphanRow(palette, o)],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (_captures.isNotEmpty) ...[
          Text('Capturas del iPhone', style: AppTypography.label(palette)),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [for (final c in _captures) _row(palette, c)],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }

  Widget _orphanRow(AppPalette palette, OrphanCapture o) {
    final d = o.modified;
    String two(int v) => v.toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(Icons.photo_library_outlined, color: palette.warning, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  o.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium(palette),
                ),
                Text(
                  '${two(d.day)}/${two(d.month)} '
                  '${two(d.hour)}:${two(d.minute)}',
                  style: AppTypography.caption(palette),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _adopting ? null : () => _adopt(o),
            child: Text(_adopting ? 'Guardando…' : 'Añadir aquí'),
          ),
          IconButton(
            tooltip: 'Borrar',
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: _adopting ? null : () => _deleteOrphan(o),
          ),
        ],
      ),
    );
  }

  Widget _row(AppPalette palette, LocationCapture c) {
    final moving =
        c.status == CaptureStatus.sending || c.status == CaptureStatus.building;
    final color = switch (c.status) {
      CaptureStatus.done => palette.success,
      CaptureStatus.failed => palette.error,
      _ => palette.accent,
    };
    final mb = (c.bytes / 1048576).round();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(
            c.status == CaptureStatus.done
                ? Icons.view_in_ar_outlined
                : Icons.photo_library_outlined,
            color: color,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium(palette),
                ),
                Text(
                  '${c.photoCount} fotos · $mb MB',
                  style: AppTypography.caption(palette),
                ),
                Text(
                  c.status == CaptureStatus.failed && c.error != null
                      ? 'Error: ${c.error}'
                      : moving
                      ? '${CaptureStatus.label(c.status)} · '
                            '${(c.progress * 100).round()} %'
                      : CaptureStatus.label(c.status),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption(palette).copyWith(color: color),
                ),
                if (moving) ...[
                  const SizedBox(height: AppSpacing.xs),
                  LinearProgressIndicator(
                    value: c.progress > 0 ? c.progress : null,
                    minHeight: 3,
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Opciones de la captura',
            onSelected: (v) => switch (v) {
              'share' => _share(c),
              'retry' => _retry(c),
              _ => _delete(c),
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'share',
                child: Text('Compartir el .zip'),
              ),
              if (c.status == CaptureStatus.failed)
                const PopupMenuItem(value: 'retry', child: Text('Reintentar')),
              const PopupMenuItem(value: 'delete', child: Text('Borrar')),
            ],
          ),
        ],
      ),
    );
  }
}
