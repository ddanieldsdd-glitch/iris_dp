import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/settings/app_prefs.dart';
import 'unreal_return.dart';
import 'unreal_stage_payload.dart';

export 'unreal_return.dart' show UnrealEdit;

enum UnrealLinkState { off, connecting, on, error }

/// IRIS Stage Link: la conexión en vivo con Unreal (F6.19.3).
///
/// Habla con la Remote Control API de Unreal (HTTP, puerto 30010) y llama a
/// la clase `IrisStageLink` de `tools/unreal/iris_stage`. Solo red local: la
/// dirección es la del PC con Unreal (o 127.0.0.1 si es el mismo).
///
/// Cada escena que llega por [offer] se manda como mucho una vez a la vez:
/// mientras va una, se queda la última y se manda al volver, solo con lo que
/// ha cambiado.
class UnrealLink extends ChangeNotifier {
  UnrealLink({http.Client? client}) : _client = client ?? http.Client();

  static final instance = UnrealLink();

  static const hostKey = PrefKey<String>('unrealLink.host', '127.0.0.1');
  static const portKey = PrefKey<int>('unrealLink.port', 30010);

  /// Puerto del reproductor de Pixel Streaming (servidor de señalización
  /// que lanza el editor de Unreal).
  static const viewerPortKey = PrefKey<int>('unrealLink.viewerPort', 80);

  /// Cada cuánto se mira si en Unreal han cambiado las piezas de IRIS.
  static const pollEvery = Duration(milliseconds: 500);

  /// Dónde registra la clase `init_unreal.py` al abrir el proyecto.
  static const objectPath =
      '/Game/Python/iris_stage_link_PY.Default__IrisStageLink';

  static const _timeout = Duration(seconds: 3);

  final http.Client _client;

  UnrealLinkState state = UnrealLinkState.off;
  String? error;
  String? engine;
  String host = '127.0.0.1';
  int port = 30010;

  /// Contraseña de Remote Control, si el proyecto la pide fuera de este
  /// equipo. No se guarda.
  String? passphrase;

  /// Lo que tardó el último cambio, de IRIS a Unreal y vuelta.
  Duration? lastRoundTrip;
  int sent = 0;

  int viewerPort = 80;

  Map<String, dynamic>? _applied;
  Map<String, dynamic>? _pending;
  bool _busy = false;

  /// Sube con cada envío: una consulta que empezó antes ya no vale.
  int _revision = 0;
  bool _polling = false;
  Timer? _poll;
  final _edits = StreamController<List<UnrealEdit>>.broadcast();

  /// Cambios hechos en Unreal a piezas de IRIS (paso 2: de Unreal a IRIS).
  Stream<List<UnrealEdit>> get edits => _edits.stream;

  bool get isOn => state == UnrealLinkState.on;

  /// El reproductor de Pixel Streaming, sin su interfaz, para verlo dentro
  /// de IRIS.
  Uri get streamUrl => Uri(
    scheme: 'http',
    host: host,
    port: viewerPort,
    path: '/',
    queryParameters: const {
      'AutoConnect': 'true',
      'AutoPlayVideo': 'true',
      'StartVideoMuted': 'true',
      'HoveringMouse': 'true',
      'HideUI': 'true',
    },
  );

  void loadPrefs() {
    final prefs = AppPrefs.instance;
    host = prefs.get(hostKey);
    port = prefs.get(portKey);
    viewerPort = prefs.get(viewerPortKey);
  }

  Future<void> setViewerPort(int value) async {
    viewerPort = value;
    notifyListeners();
    await AppPrefs.instance.setIn(
      viewerPortKey,
      const SettingsScope.global(),
      value,
    );
  }

  /// Pone el visor del editor de Unreal (lo que emite Pixel Streaming) en
  /// la cámara [id] de la planta.
  Future<void> viewThrough(String id) => call('ViewThrough', {'id': id});

  /// Conecta con Unreal: prueba que IRIS Stage Link responde y, si hay una
  /// escena esperando, la manda entera.
  Future<bool> connect({String? host, int? port, String? passphrase}) async {
    if (host != null) this.host = host.trim();
    if (port != null) this.port = port;
    this.passphrase = passphrase?.trim().isEmpty ?? true ? null : passphrase;
    _set(UnrealLinkState.connecting);
    try {
      final pong = await call('Ping');
      engine = pong['engine'] as String?;
      _applied = null;
      _set(UnrealLinkState.on);
      _poll?.cancel();
      _poll = Timer.periodic(pollEvery, (_) => checkUnreal());
      unawaited(
        AppPrefs.instance.setIn(
          hostKey,
          const SettingsScope.global(),
          this.host,
        ),
      );
      unawaited(
        AppPrefs.instance.setIn(
          portKey,
          const SettingsScope.global(),
          this.port,
        ),
      );
      _pump();
      return true;
    } catch (e) {
      _set(UnrealLinkState.error, describe(e));
      return false;
    }
  }

  void disconnect() {
    _poll?.cancel();
    _applied = null;
    _set(UnrealLinkState.off);
  }

  /// Mira si en Unreal han cambiado las piezas de IRIS y, si es así, lo
  /// avisa por [edits]. Lo que se avisa pasa a ser lo «mandado», para no
  /// avisarlo otra vez.
  @visibleForTesting
  Future<void> checkUnreal() async {
    final applied = _applied;
    if (!isOn || _busy || _polling || applied == null) return;
    _polling = true;
    final revision = _revision;
    try {
      final snap = await call('Snapshot');
      if (revision != _revision || !identical(applied, _applied)) return;
      final actors = snap['actors'] as Map? ?? const {};
      final found = UnrealReturn.detect(applied, actors);
      if (found.isEmpty) return;
      _applied = _withSnapshot(applied, found);
      _edits.add(found);
    } catch (e) {
      // Una consulta perdida no corta la conexión: si Unreal se ha cerrado,
      // el próximo envío lo dirá.
      debugPrint('[unreal] Snapshot: $e');
    } finally {
      _polling = false;
    }
  }

  static Map<String, dynamic> _withSnapshot(
    Map<String, dynamic> applied,
    List<UnrealEdit> edits,
  ) {
    final byId = {for (final e in edits) e.id: e};
    Map patched(Map item) {
      final e = byId['${item['id']}'];
      if (e == null) return item;
      return {
        ...item,
        'loc': ?e.loc,
        'rot': ?e.rot,
        if (e.cd != null) ...{'cd': e.cd, 'on': e.cd! > 0.5},
        'cct': ?e.cct,
      };
    }

    return {
      ...applied,
      for (final kind in const ['lights', 'cameras'])
        kind: [
          for (final item in (applied[kind] as List? ?? const []).cast<Map>())
            patched(item),
        ],
    };
  }

  /// La escena 3D de la planta ha cambiado.
  void offer(Map<String, dynamic> scene3d) {
    _pending = UnrealStagePayload.build(scene3d);
    if (isOn) _pump();
  }

  Future<void> _pump() async {
    if (_busy || !isOn) return;
    _busy = true;
    try {
      while (isOn && _pending != null) {
        final now = _pending!;
        _pending = null;
        final patch = UnrealStagePayload.diff(_applied, now);
        if (patch == null) continue;
        final watch = Stopwatch()..start();
        _revision++;
        await call('ApplyScene', {'payload': jsonEncode(patch)});
        lastRoundTrip = watch.elapsed;
        sent++;
        _applied = now;
        notifyListeners();
      }
    } catch (e) {
      // Lo que no llegó se manda entero al reconectar.
      _applied = null;
      _set(UnrealLinkState.error, describe(e));
    } finally {
      _busy = false;
    }
  }

  /// Llama a una función de IrisStageLink y devuelve su respuesta.
  @visibleForTesting
  Future<Map<String, dynamic>> call(
    String function, [
    Map<String, Object?>? parameters,
  ]) async {
    final body = {
      'objectPath': objectPath,
      'functionName': function,
      'generateTransaction': false,
      'parameters': ?parameters,
    };
    final response = await _client
        .put(
          Uri(scheme: 'http', host: host, port: port, path: '/remote/object/call'),
          // Remote Control rechaza «application/json; charset=utf-8»: el
          // cuerpo va en bytes para que no se añada.
          headers: {
            'Content-Type': 'application/json',
            'Passphrase': ?passphrase,
          },
          body: utf8.encode(jsonEncode(body)),
        )
        .timeout(_timeout);
    final text = utf8.decode(response.bodyBytes);
    if (response.statusCode != 200) {
      throw UnrealLinkException(_serverError(text) ?? 'HTTP ${response.statusCode}');
    }
    final raw = (jsonDecode(text) as Map)['ReturnValue'];
    final result = raw is String
        ? jsonDecode(raw) as Map<String, dynamic>
        : <String, dynamic>{};
    if (result['ok'] != true) {
      throw UnrealLinkException(result['error'] as String? ?? 'sin respuesta');
    }
    return result;
  }

  static String? _serverError(String text) {
    try {
      return (jsonDecode(text) as Map)['errorMessage'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// El error en palabras de quien lo va a leer.
  static String describe(Object e) {
    if (e is UnrealLinkException) {
      if (e.message.contains('does not exist')) {
        return 'Unreal responde, pero no tiene IRIS Stage Link. Copia '
            'tools/unreal/iris_stage/Content/Python en el proyecto y '
            'vuelve a abrirlo.';
      }
      return e.message;
    }
    if (e is TimeoutException) {
      return 'Unreal no contesta. ¿Está abierto con el plugin Remote '
          'Control activado?';
    }
    return 'No se puede conectar con Unreal ($e).';
  }

  void _set(UnrealLinkState s, [String? message]) {
    state = s;
    error = message;
    notifyListeners();
  }
}

class UnrealLinkException implements Exception {
  final String message;
  UnrealLinkException(this.message);

  @override
  String toString() => message;
}
