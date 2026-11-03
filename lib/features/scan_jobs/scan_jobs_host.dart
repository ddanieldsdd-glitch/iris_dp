import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/sync/realtime_hub.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_snackbar.dart';
import '../camera_plan/rig/scan_builder.dart';
import 'capture_lan.dart';
import 'capture_store.dart';
import 'scan_build_queue.dart';

/// Lo que mueve las capturas del iPhone sin que nadie pulse nada (IC.6):
/// - en el PC con RealityScan: recibe por la red local, lo anuncia al
///   espacio de trabajo y construye en cola, con un indicador abajo;
/// - en el iPhone: al abrir, al volver y cada minuto, envía lo pendiente al
///   PC si están en la misma Wi‑Fi, y avisa cuando un escaneo está listo.
class ScanJobsHost extends ConsumerStatefulWidget {
  final Widget child;

  const ScanJobsHost({super.key, required this.child});

  static const tick = Duration(seconds: 60);

  @override
  ConsumerState<ScanJobsHost> createState() => _ScanJobsHostState();
}

class _ScanJobsHostState extends ConsumerState<ScanJobsHost>
    with WidgetsBindingObserver {
  Timer? _ticker;
  Timer? _debounce;
  StreamSubscription<List<LocationCapture>>? _watch;
  CaptureReceiver? _receiver;
  ScanBuildQueue? _queue;
  Map<String, dynamic>? _announce;
  RealtimeHub? _hub;

  /// Estado anterior de cada captura, para avisar al pasar a «listo».
  final _lastStatus = <String, String>{};

  /// Capturas sin escaneo todavía, de cualquier proyecto: el aviso de abajo
  /// en el iPhone, el Mac y el PC.
  List<LocationCapture> _pending = const [];
  bool _firstLoad = true;

  bool get _isPhone => Platform.isIOS;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (Platform.isWindows) {
      unawaited(_startBuilder());
    } else if (_isPhone) {
      _ticker = Timer.periodic(ScanJobsHost.tick, (_) => _send());
      ref.listenManual(realtimeHubProvider, (_, _) => _send());
      Timer(const Duration(seconds: 5), _send);
    }
    final db = ref.read(databaseProvider);
    _watch = (db.select(db.locationCaptures)).watch().listen(_onCaptures);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _debounce?.cancel();
    _watch?.cancel();
    unawaited(_receiver?.stop());
    if (_announce != null) unawaited(_hub?.setScanBuilder(null));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isPhone) _send();
  }

  // ── PC ──

  Future<void> _startBuilder() async {
    final install = RealityScanInstall.located();
    if (install == null) return;
    final db = ref.read(databaseProvider);
    final queue = _queue = ScanBuildQueue(
      db,
      build: ScanBuildQueue.realityScan(install),
      notify: windowsToast,
    );
    queue.state.addListener(() => mounted ? setState(() {}) : null);
    final token = await CaptureLan.token();
    final me = await InstallId.get();
    final receiver = CaptureReceiver(
      token: token,
      onReceived: (uid) async {
        await db.updateCapture(
          uid,
          LocationCapturesCompanion(
            status: const Value(CaptureStatus.onPc),
            builderInstallId: Value(me),
          ),
        );
        final c = await db.getCaptureByUid(uid);
        windowsToast(
          'Captura recibida del iPhone',
          c == null ? 'Se construye en cuanto llegue su proyecto.' : c.name,
        );
        unawaited(queue.runPending());
      },
    );
    try {
      await receiver.start();
      _receiver = receiver;
    } on SocketException catch (e) {
      // Puerto ocupado (otra IRIS abierta): este equipo no recibe.
      debugPrint('Receptor de capturas: $e');
    }
    if (_receiver != null) {
      _announce = {
        'lanIps': await CaptureLan.lanIps(),
        'port': CaptureLan.port,
        'token': token,
      };
      _publish();
      ref.listenManual(realtimeHubProvider, (_, _) => _publish());
      // Las direcciones cambian si el PC cambia de red.
      _ticker = Timer.periodic(ScanJobsHost.tick, (_) async {
        _announce = {..._announce!, 'lanIps': await CaptureLan.lanIps()};
        _publish();
        unawaited(queue.runPending());
      });
    }
    unawaited(queue.runPending());
  }

  void _publish() {
    _hub = ref.read(realtimeHubProvider);
    unawaited(_hub?.setScanBuilder(_announce));
  }

  // ── iPhone ──

  void _send() {
    final hub = ref.read(realtimeHubProvider);
    if (hub == null) return;
    unawaited(
      CaptureSender(
        ref.read(databaseProvider),
      ).sendPending(hub.scanBuilders).then((sent) {
        if (sent > 0 && mounted) {
          AppSnackBar.show(
            context,
            sent == 1
                ? 'Captura enviada al PC: se construye allí.'
                : '$sent capturas enviadas al PC: se construyen allí.',
          );
        }
      }),
    );
  }

  void _onCaptures(List<LocationCapture> all) {
    final pending = [
      for (final c in all)
        if (c.status != CaptureStatus.done) c,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    // Una captura nueva de otro equipo (llegó con la sincronización).
    if (!_isPhone && !_firstLoad && mounted) {
      for (final c in pending) {
        if (c.uid == null || _lastStatus.containsKey(c.uid)) continue;
        AppSnackBar.show(
          context,
          Platform.isWindows
              ? 'Nueva captura del iPhone: ${c.name}. Llega a este PC cuando '
                    'el iPhone esté en la misma Wi‑Fi.'
              : 'Nueva captura del iPhone: ${c.name}. Se construye en el PC '
                    'con RealityScan.',
        );
      }
    }
    _firstLoad = false;
    if (mounted) setState(() => _pending = pending);
    if (!_isPhone) {
      for (final c in all) {
        final uid = c.uid;
        if (uid == null) continue;
        final before = _lastStatus[uid];
        _lastStatus[uid] = c.status;
        if (before != null &&
            before != CaptureStatus.done &&
            c.status == CaptureStatus.done &&
            mounted) {
          AppSnackBar.show(context, 'Escaneo listo: ${c.name}.');
        }
      }
      if (!Platform.isWindows) return;
    }
    if (_isPhone) {
      for (final c in all) {
        final uid = c.uid;
        if (uid == null) continue;
        final before = _lastStatus[uid];
        _lastStatus[uid] = c.status;
        if (before != null &&
            before != CaptureStatus.done &&
            c.status == CaptureStatus.done &&
            mounted) {
          AppSnackBar.show(context, 'Escaneo listo: ${c.name}.');
          // El zip ya no hace falta aquí.
          unawaited(CaptureStore.deleteLocal(uid));
        }
      }
      return;
    }
    // PC: una fila nueva o cambiada puede ser una captura cuyo zip ya está.
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(seconds: 2),
      () => unawaited(_queue?.runPending()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final queue = _queue?.state.value;
    final building = queue != null && !queue.idle;
    final compact = MediaQuery.sizeOf(context).width < 600;
    // Siempre el mismo árbol: si el aviso cambiara la forma, se rehará la
    // app entera debajo.
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (building || _pending.isNotEmpty)
          Positioned(
            left: AppSpacing.md,
            // En el iPhone, encima de la barra de pestañas.
            bottom:
                (compact ? MediaQuery.paddingOf(context).bottom + 76 : 0) +
                AppSpacing.md,
            child: CaptureStatusChip(
              pending: _pending,
              queue: building ? queue : null,
              onTap: () => showPendingCaptures(
                context,
                ref.read(databaseProvider),
                _pending,
              ),
            ),
          ),
      ],
    );
  }
}

/// El aviso de abajo: lo que construye el PC ahora o cuántas capturas
/// esperan escaneo.
class CaptureStatusChip extends StatelessWidget {
  final List<LocationCapture> pending;
  final ScanQueueState? queue;
  final VoidCallback onTap;

  const CaptureStatusChip({
    super.key,
    required this.pending,
    required this.onTap,
    this.queue,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final q = queue;
    final failed = pending.where((c) => c.status == CaptureStatus.failed);
    final String text;
    if (q != null) {
      final pct = q.fraction == null
          ? ''
          : ' · ${(q.fraction! * 100).round()} %';
      final queued = q.waiting > 0 ? ' · ${q.waiting} en cola' : '';
      text = 'Escaneo: ${q.building}$pct$queued';
    } else if (pending.length == 1) {
      text =
          '${pending.single.name}: '
          '${CaptureStatus.short(pending.single.status)}';
    } else {
      text = '${pending.length} capturas sin escaneo';
    }
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width - AppSpacing.md * 2,
      ),
      child: Material(
        color: palette.surface,
        elevation: 6,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (q != null)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      value: q.fraction,
                    ),
                  )
                else
                  Icon(
                    failed.isNotEmpty
                        ? Icons.error_outline
                        : Icons.photo_library_outlined,
                    size: 16,
                    color: failed.isNotEmpty ? palette.error : palette.accent,
                  ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption(palette),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Las capturas sin escaneo de todos los proyectos, con su estado.
Future<void> showPendingCaptures(
  BuildContext context,
  AppDatabase db,
  List<LocationCapture> pending,
) async {
  final projects = {
    for (final p in await db.watchProjects().first) p.id: p.name,
  };
  if (!context.mounted) return;
  final palette = context.palette;
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: palette.surface,
    builder: (ctx) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(ctx).height * 0.7,
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text(
              'Capturas del iPhone sin escaneo',
              style: AppTypography.titleMedium(palette),
            ),
          ),
          for (final c in pending)
            ListTile(
              leading: Icon(
                c.status == CaptureStatus.failed
                    ? Icons.error_outline
                    : Icons.photo_library_outlined,
                color: c.status == CaptureStatus.failed
                    ? palette.error
                    : palette.accent,
              ),
              title: Text(
                '${c.name} · ${projects[c.projectId] ?? 'Proyecto'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                c.status == CaptureStatus.failed && c.error != null
                    ? 'Error: ${c.error}'
                    : '${CaptureStatus.label(c.status)} · '
                          '${c.photoCount} fotos',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              0,
            ),
            child: Text(
              'Se construyen en el PC con RealityScan cuando el iPhone y el '
              'PC están en la misma Wi‑Fi con IRIS abierta. El detalle de '
              'cada una, en el panel de escaneo de su set.',
              style: AppTypography.caption(palette),
            ),
          ),
        ],
      ),
    ),
  );
}
