import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cloud/cloud_providers.dart';
import '../cloud/cloud_runtime_config.dart';
import '../cloud/connectivity_status_provider.dart';
import '../database/database_provider.dart';
import '../utils/error_log.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/sync/sync_conflict_history_sheet.dart';
import 'sync_engine.dart';
import 'sync_plan_applier.dart';

/// Sincroniza solo, sin que nadie pulse nada:
/// - al volver a la app, una pasada completa;
/// - cada minuto mientras está abierta, una ligera;
/// - unos segundos después de dejar de editar, sube lo editado.
class AutoSyncScheduler extends ConsumerStatefulWidget {
  final Widget child;

  const AutoSyncScheduler({super.key, required this.child});

  static const tick = Duration(seconds: 60);
  static const afterEdit = Duration(seconds: 5);

  /// Al volver muchas veces seguidas (en el Mac, cada vez que la ventana
  /// recupera el foco) no se repite la pasada completa.
  static const fullPassGap = Duration(seconds: 30);

  @override
  ConsumerState<AutoSyncScheduler> createState() => _AutoSyncSchedulerState();
}

class _AutoSyncSchedulerState extends ConsumerState<AutoSyncScheduler>
    with WidgetsBindingObserver {
  Timer? _ticker;
  Timer? _editDebounce;
  StreamSubscription<int>? _queueWatch;
  int _lastQueueCount = 0;
  DateTime? _lastFullPass;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTicker();
    final db = ref.read(databaseProvider);
    // Cada edición deja una entrada en la cola de contenido: cuando crece,
    // hay algo nuevo que subir.
    _queueWatch = (db.select(db.cloudSyncQueue)
          ..where((q) => q.processed.equals(false)))
        .watch()
        .map((rows) => rows.length)
        .listen(_onQueueCount);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _editDebounce?.cancel();
    _queueWatch?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        final wasAway = !_foreground;
        _foreground = true;
        _startTicker();
        final last = _lastFullPass;
        final full = wasAway ||
            last == null ||
            DateTime.now().difference(last) > AutoSyncScheduler.fullPassGap;
        _run(full: full);
      case AppLifecycleState.paused ||
            AppLifecycleState.hidden ||
            AppLifecycleState.detached:
        _foreground = false;
        _ticker?.cancel();
        _ticker = null;
        // Lo editado no espera a la próxima vez que se abra la app.
        _editDebounce?.cancel();
        _pushEdits();
      case AppLifecycleState.inactive:
        // En el Mac es solo perder el foco: la ventana sigue a la vista.
        break;
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(AutoSyncScheduler.tick, (_) => _run(full: false));
  }

  void _onQueueCount(int count) {
    final grew = count > _lastQueueCount;
    _lastQueueCount = count;
    if (!grew) return;
    _editDebounce?.cancel();
    _editDebounce = Timer(AutoSyncScheduler.afterEdit, _pushEdits);
  }

  bool get _canSync {
    if (!CloudRuntimeConfig.isActive) return false;
    if (ref.read(currentUserProvider) == null) return false;
    final network = ref.read(connectivityStatusProvider).value;
    return network != NetworkStatus.offline;
  }

  Future<void> _run({required bool full}) async {
    if (!_canSync) return;
    if (full) _lastFullPass = DateTime.now();
    try {
      await ref.read(syncEngineProvider).syncSilently(allMedia: full);
    } catch (e, st) {
      _report(e, st);
    }
  }

  Future<void> _pushEdits() async {
    if (!_canSync) return;
    try {
      await ref.read(syncEngineProvider).pushPendingEdits();
    } catch (e, st) {
      _report(e, st);
    }
  }

  /// Un fallo al aplicar un proyecto va al log; los de red (sin conexión a
  /// medias) no: se repetirían cada minuto y la siguiente pasada lo reintenta.
  void _report(Object e, StackTrace st) {
    if (e is SyncApplyException) {
      unawaited(ErrorLog.record(e, st, context: 'Sincronización automática'));
    } else {
      debugPrint('Sincronización automática: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // La mezcla descartó algo: se avisa una vez y «Ver» abre el historial.
    ref.listen<MergeNotice?>(mergeNoticeProvider, (_, notice) {
      if (notice == null) return;
      ref.read(mergeNoticeProvider.notifier).state = null;
      AppSnackBar.show(
        context,
        notice.message,
        duration: const Duration(seconds: 8),
        actionLabel: 'Ver',
        onAction: () => SyncConflictHistorySheet.show(context),
      );
    });
    return widget.child;
  }
}
