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
    } else {
      return;
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
    final state = _queue?.state.value;
    if (state == null || state.idle) return widget.child;
    final palette = context.palette;
    final pct = state.fraction == null
        ? ''
        : ' · ${(state.fraction! * 100).round()} %';
    final queued = state.waiting > 0 ? ' · ${state.waiting} en cola' : '';
    return Stack(
      children: [
        widget.child,
        Positioned(
          left: AppSpacing.md,
          bottom: AppSpacing.md,
          child: Material(
            color: palette.surface,
            elevation: 6,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      value: state.fraction,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Escaneo: ${state.building}$pct$queued',
                    style: AppTypography.caption(palette),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
