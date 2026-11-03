import 'dart:async';

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

  @override
  void initState() {
    super.initState();
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

  Future<void> _share(LocationCapture c) async {
    final zip = await CaptureStore.zipFor(c.uid!);
    if (!await zip.exists()) return;
    await Share.shareXFiles([XFile(zip.path)], subject: 'Captura ${c.name}');
  }

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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Borrar «${c.name}»'),
        content: const Text(
          'Se borra la captura y sus fotos de este equipo. El escaneo ya '
          'hecho, si lo hay, se queda en el set.',
        ),
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
    );
    if (ok != true) return;
    await CaptureStore.deleteLocal(c.uid!);
    await ref.read(databaseProvider).deleteCapture(c);
  }

  @override
  Widget build(BuildContext context) {
    if (_captures.isEmpty) return const SizedBox.shrink();
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
