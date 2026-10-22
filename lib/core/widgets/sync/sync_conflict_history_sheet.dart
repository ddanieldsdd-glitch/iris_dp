import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../database/database_provider.dart';
import '../../sync/sync_engine.dart';
import '../../sync/sync_merge_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../app_snackbar.dart';

const _seenKey = 'iris_conflict_log_seen_at';

/// Entradas del historial que aún no se han mirado (para el contador del
/// icono de la nube). Se recalcula cada vez que la mezcla descarta algo.
final unseenConflictCountProvider = FutureProvider<int>((ref) async {
  ref.watch(mergeDiscardsProvider);
  final db = ref.watch(databaseProvider);
  final prefs = await SharedPreferences.getInstance();
  final seen = prefs.getInt(_seenKey) ?? 0;
  final entries = await SyncConflictLog.list(db, limit: 500);
  return entries.where((e) => e.createdAt.millisecondsSinceEpoch > seen).length;
});

/// Lo que la mezcla descartó, por proyecto: qué se quedó, qué se descartó,
/// de qué equipo y cuándo, con el valor descartado para copiarlo.
class SyncConflictHistorySheet extends ConsumerStatefulWidget {
  const SyncConflictHistorySheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SyncConflictHistorySheet(),
    );
  }

  @override
  ConsumerState<SyncConflictHistorySheet> createState() =>
      _SyncConflictHistorySheetState();
}

class _SyncConflictHistorySheetState
    extends ConsumerState<SyncConflictHistorySheet> {
  late final Future<(List<SyncConflictEntry>, Map<int, String>)> _load;

  @override
  void initState() {
    super.initState();
    _load = _fetch();
    _markSeen();
  }

  Future<(List<SyncConflictEntry>, Map<int, String>)> _fetch() async {
    final db = ref.read(databaseProvider);
    final entries = await SyncConflictLog.list(db);
    final projects = await db.select(db.projects).get();
    return (entries, {for (final p in projects) p.id: p.name});
  }

  Future<void> _markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_seenKey, DateTime.now().millisecondsSinceEpoch);
    ref.invalidate(unseenConflictCountProvider);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      decoration: BoxDecoration(
        color: palette.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                Icon(Icons.history, size: 20, color: palette.textSecondary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Historial de conflictos',
                    style: AppTypography.titleMedium(palette),
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text(
              'Cuando el mismo dato cambió en los dos equipos se quedó la '
              'edición más reciente. Aquí está la otra, por si la quieres.',
              style: AppTypography.caption(palette),
            ),
          ),
          Flexible(
            child: FutureBuilder(
              future: _load,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final (entries, names) = snap.data!;
                if (entries.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Text(
                      'No se ha descartado nada: todo lo editado en cada '
                      'equipo está en los dos.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium(palette).copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  );
                }
                final byProject = <int, List<SyncConflictEntry>>{};
                for (final e in entries) {
                  byProject.putIfAbsent(e.projectId, () => []).add(e);
                }
                return ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  children: [
                    for (final group in byProject.entries) ...[
                      Padding(
                        padding: const EdgeInsets.only(
                          top: AppSpacing.md,
                          bottom: AppSpacing.xs,
                        ),
                        child: Text(
                          names[group.key] ?? 'Proyecto borrado',
                          style: AppTypography.label(palette),
                        ),
                      ),
                      for (final e in group.value) _EntryRow(entry: e),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  final SyncConflictEntry entry;

  const _EntryRow({required this.entry});

  static const _fieldNames = {
    'lens': 'óptica',
    'framing': 'encuadre',
    'angle': 'ángulo',
    'movement': 'movimiento',
    'fStop': 'diafragma',
    'action': 'acción',
    'notes': 'notas',
    'description': 'descripción',
    'name': 'nombre',
    'number': 'número',
    'durationSeconds': 'duración',
    'durationMinutes': 'duración',
    'charactersJson': 'personajes',
    'intExt': 'INT/EXT',
    'dayNight': 'día/noche',
    'locationName': 'nombre',
    'planJson': 'planta',
    'floorPlanJson': 'planta',
    'cardColor': 'color de la tarjeta',
    'cardSize': 'tamaño de la tarjeta',
  };

  String get _title {
    final what = entry.elementLabel ?? entry.collection;
    final field = entry.field;
    if (field != null) return '$what · ${_fieldNames[field] ?? field}';
    if (entry.discardedSide == 'cascada') return '$what · se fue con su padre';
    if (entry.elementUid == null) return '$what (bloque entero)';
    return what;
  }

  static String _short(String? v) {
    if (v == null || v.isEmpty) return '(vacío)';
    final flat = v.replaceAll('\n', ' ');
    if (flat.startsWith('{') || flat.startsWith('[')) {
      final kb = (v.length / 1024).toStringAsFixed(1);
      return v.length < 1024 ? 'contenido (${v.length} car.)' : 'contenido ($kb KB)';
    }
    return flat.length > 60 ? '«${flat.substring(0, 60)}…»' : '«$flat»';
  }

  String get _detail {
    final device = entry.discardedDevice;
    final from = device == null ? '' : ' ($device)';
    final when = _when(entry.createdAt);
    if (entry.discardedSide == 'cascada') {
      return 'Se borró en el otro equipo junto con lo que contenía · $when';
    }
    if (entry.discardedValue == null) {
      return 'Se quedó; el borrado$from se descartó · $when';
    }
    if (entry.keptValue == null && entry.field == null) {
      return 'Se borró; descartada la edición$from · $when';
    }
    return 'Se quedó ${_short(entry.keptValue)} · descartado '
        '${_short(entry.discardedValue)}$from · $when';
  }

  static String _when(DateTime at) {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final time = '${two(at.hour)}:${two(at.minute)}';
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(at.year, at.month, at.day);
    final days = today.difference(day).inDays;
    if (days == 0) return 'hoy $time';
    if (days == 1) return 'ayer $time';
    return '${at.day}/${at.month} $time';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final copyable = entry.discardedValue;
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.divider)),
      ),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_title, style: AppTypography.bodyMedium(palette)),
                const SizedBox(height: 2),
                Text(_detail, style: AppTypography.caption(palette)),
              ],
            ),
          ),
          if (copyable != null)
            IconButton(
              tooltip: 'Copiar lo descartado',
              icon: const Icon(Icons.copy, size: 16),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: copyable));
                AppSnackBar.show(context, 'Copiado');
              },
            ),
        ],
      ),
    );
  }
}
