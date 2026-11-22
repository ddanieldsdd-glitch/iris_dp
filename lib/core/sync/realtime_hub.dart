import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../cloud/cloud_providers.dart';
import '../database/database_provider.dart';
import '../update/device_update_messages.dart';
import 'device_label.dart';
import 'live_drawing.dart';
import 'live_editing.dart';
import 'live_key_projects.dart';

/// Id al azar de esta instalación: distingue dos equipos iguales (dos Mac)
/// en los avisos y, más adelante, en quién edita qué.
abstract final class InstallId {
  static const _key = 'iris_install_id';
  static String? _cached;

  static Future<String> get() async {
    if (_cached != null) return _cached!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_key);
    if (id == null) {
      final r = Random.secure();
      id = List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join();
      await prefs.setString(_key, id);
    }
    return _cached = id;
  }
}

/// Un equipo que construye escaneos (el PC con RealityScan) y sus
/// direcciones en la red local.
class ScanBuilderPeer {
  final String installId;
  final String? device;
  final List<String> lanIps;
  final int port;
  final String token;

  const ScanBuilderPeer({
    required this.installId,
    required this.lanIps,
    required this.port,
    required this.token,
    this.device,
  });

  static ScanBuilderPeer? fromPayload(Map<String, dynamic> p) {
    final installId = p['installId'];
    final b = p['scanBuilder'];
    if (installId is! String || b is! Map) return null;
    final ips = b['lanIps'];
    final port = b['port'];
    final token = b['token'];
    if (ips is! List || port is! int || token is! String) return null;
    return ScanBuilderPeer(
      installId: installId,
      device: p['device'] as String?,
      lanIps: [
        for (final ip in ips)
          if (ip is String) ip,
      ],
      port: port,
      token: token,
    );
  }
}

/// Otro equipo acaba de subir una versión de un proyecto.
class SnapshotNotice {
  final String projectCloudId;
  final String hash;
  final String? device;

  const SnapshotNotice({
    required this.projectCloudId,
    required this.hash,
    this.device,
  });
}

/// Un canal abierto: el del espacio de trabajo propio o el de un proyecto
/// compartido.
class _Joined {
  _Joined(this.channel, {this.project, this.role});

  final RealtimeChannel channel;

  /// El `cloudId` del proyecto; nulo en el canal del espacio propio.
  final String? project;

  /// Qué hace esta cuenta en ese proyecto (se enseña a los demás).
  String? role;
  bool subscribed = false;
  bool joining = true;

  bool get live => subscribed || joining;
}

/// Canales en vivo (Supabase Realtime, sin tablas): quien sube un proyecto
/// lo avisa y los demás lo bajan en segundos, sin esperar a la pasada de
/// cada minuto; y cada equipo dice qué edita, para que los demás no lo
/// toquen a la vez. Es un aviso, no el contenido: si se pierde, la pasada
/// de cada minuto lo recoge igual.
///
/// Hay un canal por espacio de trabajo (los equipos de una misma cuenta y
/// las versiones anteriores) y, desde la fase 0 de colaboración, uno por
/// proyecto en la nube: ahí coinciden las personas invitadas a él, que no
/// comparten espacio. Lo de un proyecto va a su canal y al del espacio; un
/// mismo mensaje puede llegar por los dos y se aplica una vez.
class RealtimeHub {
  final SupabaseClient _client;

  RealtimeHub(this._client);

  static const _snapshotEvent = 'snapshot';
  static const _mediaEvent = 'media';
  static const _typingEvent = 'typing';
  static const _drawingEvent = 'drawing';
  static const _updateRequestEvent = 'device-update-request';
  static const _updateStatusEvent = 'device-update-status';

  /// Quién edita qué en los demás equipos (presencia de los canales).
  void Function(List<PeerEditing> peers)? onPeers;

  /// Lo que otro equipo escribe (`text == null`: terminó).
  void Function(String shotUid, String column, String? text)? onTyping;

  /// A qué proyecto pertenece una clave en vivo ([LiveKey]). Sin él, todo
  /// va solo al canal del espacio propio.
  Future<String?> Function(String key)? projectOfKey;

  Map<String, dynamic>? _editing;

  /// El proyecto de lo que se edita: su canal es el único, además del del
  /// espacio, que lo sabe.
  String? _editingProject;

  /// Quién usa este equipo (nombre de su perfil).
  String? _person;

  /// Este equipo construye escaneos: dónde recibe las capturas en la red
  /// local (ver `CaptureReceiver`).
  Map<String, dynamic>? _scanBuilder;
  String? _installId;

  /// Este equipo es el Mac que instala en el iPad y el iPhone.
  bool _updateHost = false;

  /// ¿Hay otro equipo conectado que pueda instalar en este dispositivo?
  final updateHostAvailable = ValueNotifier<bool>(false);

  final _updateRequests = StreamController<DeviceUpdateRequest>.broadcast();
  final _updateStatuses = StreamController<DeviceUpdateStatus>.broadcast();

  /// Un iPad o iPhone pide que lo actualicen (lo escucha el Mac).
  Stream<DeviceUpdateRequest> get deviceUpdateRequests =>
      _updateRequests.stream;

  /// Cómo va una petición (lo escucha el iPad o iPhone).
  Stream<DeviceUpdateStatus> get deviceUpdateStatuses => _updateStatuses.stream;

  _Joined? _workspace;
  String? _workspaceId;
  final Map<String, _Joined> _projects = {};
  final _notices = StreamController<SnapshotNotice>.broadcast();

  Stream<SnapshotNotice> get snapshotNotices => _notices.stream;

  final _mediaNotices = StreamController<String>.broadcast();

  /// Otro equipo terminó de subir imágenes de un proyecto (su `cloudId`).
  /// Las imágenes suben después del contenido, así que el aviso del
  /// contenido no basta para bajarlas enseguida.
  Stream<String> get mediaNotices => _mediaNotices.stream;

  final _drawings = StreamController<Map<String, dynamic>>.broadcast();
  final _drawingParts = DrawingWireAssembler();

  /// Lo que llega de un folio compartido de otro equipo.
  Stream<Map<String, dynamic>> get drawingMessages => _drawings.stream;

  /// ¿Está dentro del canal del espacio (o entrando)?
  bool get isLive => _workspace?.live ?? false;

  /// Los proyectos con canal abierto ahora.
  @visibleForTesting
  Set<String> get joinedProjects => {..._projects.keys};

  /// Mensajes ya aplicados: el mismo puede llegar por dos canales.
  final _seen = <String>{};
  final _seenOrder = <String>[];

  /// ¿Es la primera vez que llega? Los de versiones anteriores no llevan
  /// marca y solo llegan por un canal.
  bool _firstTime(Map<String, dynamic> payload) {
    final mid = payload['mid'];
    if (mid is! String) return true;
    if (!_seen.add(mid)) return false;
    _seenOrder.add(mid);
    if (_seenOrder.length > 300) _seen.remove(_seenOrder.removeAt(0));
    return true;
  }

  static final _random = Random();
  static String _newMid() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
      '${_random.nextInt(1 << 30).toRadixString(36)}';

  /// Se une al canal del espacio de trabajo; si ya está dentro, no hace
  /// nada. Si el canal se cerró o falló (el iPad en segundo plano, una red
  /// que se cayó), vuelve a entrar.
  Future<void> connect(String workspaceId) async {
    if (_workspaceId == workspaceId && isLive) return;
    await _leaveWorkspace();
    _workspaceId = workspaceId;
    _installId = await InstallId.get();
    _workspace = _join('iris-ws-$workspaceId');
  }

  /// Los proyectos en la nube de este equipo, con lo que hace en cada uno:
  /// entra en el canal de los nuevos y sale del de los que ya no están.
  /// Como [connect], vuelve a entrar en los que se cerraron.
  Future<void> joinProjects(Map<String, String?> roles) async {
    _installId ??= await InstallId.get();
    for (final gone in [
      for (final id in _projects.keys)
        if (!roles.containsKey(id)) id,
    ]) {
      await _remove(_projects.remove(gone)!);
    }
    for (final MapEntry(key: id, value: role) in roles.entries) {
      final joined = _projects[id];
      if (joined != null && joined.live) {
        if (joined.role != role) {
          joined.role = role;
          unawaited(_trackOn(joined));
        }
        continue;
      }
      if (joined != null) await _remove(joined);
      _projects[id] = _join('iris-proj-$id', project: id, role: role);
    }
  }

  /// Quién usa este equipo: va en la presencia, para que los avisos digan
  /// «Ana» y no «iPad».
  set person(String? value) {
    if (value == _person) return;
    _person = value;
    unawaited(_track());
  }

  _Joined _join(String topic, {String? project, String? role}) {
    final installId = _installId!;
    final channel = _client.channel(
      topic,
      opts: RealtimeChannelConfig(key: installId),
    );
    final joined = _Joined(channel, project: project, role: role);
    channel
        .onPresenceSync((_) => _emitPeers())
        .onPresenceLeave((_) => _emitPeers())
        .onBroadcast(
          event: _typingEvent,
          callback: (payload) {
            final shot = payload['shotUid'];
            final column = payload['column'];
            if (shot is! String || column is! String) return;
            if (payload['installId'] == installId) return;
            if (!_firstTime(payload)) return;
            onTyping?.call(shot, column, payload['text'] as String?);
          },
        )
        .onBroadcast(
          event: _drawingEvent,
          callback: (payload) {
            if (payload['installId'] == installId) return;
            if (!_firstTime(payload)) return;
            final message = _drawingParts.add(payload);
            if (message != null) _drawings.add(message);
          },
        )
        .onBroadcast(
          event: _snapshotEvent,
          callback: (payload) {
            final project = payload['projectCloudId'];
            final hash = payload['hash'];
            if (project is! String || hash is! String) return;
            if (payload['installId'] == installId) return;
            if (!_firstTime(payload)) return;
            _notices.add(
              SnapshotNotice(
                projectCloudId: project,
                hash: hash,
                device: payload['device'] as String?,
              ),
            );
          },
        )
        .onBroadcast(
          event: _mediaEvent,
          callback: (payload) {
            final project = payload['projectCloudId'];
            if (project is! String) return;
            if (payload['installId'] == installId) return;
            if (!_firstTime(payload)) return;
            _mediaNotices.add(project);
          },
        );
    if (project == null) {
      // Actualizar el iPad desde el Mac es cosa de los equipos propios.
      channel
          .onBroadcast(
            event: _updateRequestEvent,
            callback: (payload) {
              if (payload['installId'] == installId) return;
              final request = DeviceUpdateRequest.fromPayload(payload);
              if (request != null) _updateRequests.add(request);
            },
          )
          .onBroadcast(
            event: _updateStatusEvent,
            callback: (payload) {
              if (payload['installId'] == installId) return;
              final status = DeviceUpdateStatus.fromPayload(payload);
              if (status != null) _updateStatuses.add(status);
            },
          );
    }
    channel.subscribe((status, error) {
      joined.joining = false;
      joined.subscribed = status == RealtimeSubscribeStatus.subscribed;
      // Al conectarse (o reconectarse) se vuelve a decir qué se edita.
      if (joined.subscribed) unawaited(_trackOn(joined));
    });
    return joined;
  }

  Iterable<_Joined> get _all => [?_workspace, ..._projects.values];

  void _emitPeers() {
    final byInstall = <String, PeerEditing>{};
    var updateHost = false;
    for (final joined in _all) {
      for (final state in joined.channel.presenceState()) {
        if (state.key == _installId) continue;
        for (final presence in state.presences) {
          if (joined.project == null &&
              presence.payload['updateHost'] == true) {
            updateHost = true;
          }
          final peer = PeerEditing.fromPayload(presence.payload);
          if (peer == null) continue;
          // Un mismo equipo puede estar en varios canales; si en uno dice
          // su persona y su rol, se queda ese.
          final known = byInstall[peer.installId];
          if (known == null || (known.role == null && peer.role != null)) {
            byInstall[peer.installId] = peer;
          }
        }
      }
    }
    updateHostAvailable.value = updateHost;
    onPeers?.call(byInstall.values.toList());
  }

  /// Dice a los demás qué edita este equipo (`null`: nada).
  Future<void> setEditing(String? shotUid, DateTime? since) async {
    _editingProject = shotUid == null
        ? null
        : await projectOfKey?.call(shotUid);
    _editing = shotUid == null
        ? null
        : {'shotUid': shotUid, 'since': since?.toIso8601String()};
    await _track();
  }

  /// Anuncia (o retira, con `null`) que este equipo construye escaneos y
  /// cómo llegarle por la red local.
  Future<void> setScanBuilder(Map<String, dynamic>? info) async {
    _scanBuilder = info;
    await _track();
  }

  /// Anuncia (o retira) que este Mac instala en el iPad y el iPhone.
  Future<void> setUpdateHost(bool value) async {
    if (value == _updateHost) return;
    _updateHost = value;
    await _track();
  }

  /// Los otros equipos del espacio que construyen escaneos, ahora mismo.
  List<ScanBuilderPeer> get scanBuilders {
    final channel = _workspace?.channel;
    if (channel == null) return const [];
    return [
      for (final state in channel.presenceState())
        if (state.key != _installId)
          for (final presence in state.presences)
            if (ScanBuilderPeer.fromPayload(presence.payload) case final peer?)
              peer,
    ];
  }

  Future<void> _track() async {
    for (final joined in _all) {
      await _trackOn(joined);
    }
  }

  /// Lo que cada canal sabe de este equipo. En el de un proyecto: quién es,
  /// su papel ahí y, si es de ese proyecto, qué edita. En el del espacio,
  /// además, lo que solo interesa a los equipos propios.
  @visibleForTesting
  static Map<String, dynamic>? presenceFor({
    required String installId,
    required String device,
    required String? project,
    String? role,
    String? person,
    Map<String, dynamic>? editing,
    String? editingProject,
    Map<String, dynamic>? scanBuilder,
    bool updateHost = false,
  }) {
    final own = project == null;
    final showEditing =
        editing != null && (own || editingProject == project);
    if (own && !showEditing && scanBuilder == null && !updateHost) {
      return null;
    }
    return {
      'installId': installId,
      'device': device,
      if (person != null && person.trim().isNotEmpty) 'person': person,
      if (role != null) 'role': role,
      if (showEditing) ...editing,
      if (own && scanBuilder != null) 'scanBuilder': scanBuilder,
      if (own && updateHost) 'updateHost': true,
    };
  }

  Future<void> _trackOn(_Joined joined) async {
    if (!joined.subscribed) return;
    try {
      final payload = presenceFor(
        installId: await InstallId.get(),
        device: deviceLabel(),
        project: joined.project,
        role: joined.role,
        person: _person,
        editing: _editing,
        editingProject: _editingProject,
        scanBuilder: _scanBuilder,
        updateHost: _updateHost,
      );
      if (payload == null) {
        await joined.channel.untrack();
      } else {
        await joined.channel.track(payload);
      }
    } catch (e) {
      debugPrint('Presencia no enviada: $e');
    }
  }

  /// Manda [payload] al canal del espacio y al del proyecto [project], si
  /// está abierto, con la misma marca para que se aplique una vez.
  Future<void> _send(
    String event,
    Map<String, dynamic> payload, {
    String? project,
    bool onlySubscribed = true,
  }) async {
    final message = {
      ...payload,
      'installId': await InstallId.get(),
      'mid': _newMid(),
    };
    for (final joined in [?_workspace, ?_projects[project]]) {
      if (onlySubscribed && !joined.subscribed) continue;
      await joined.channel.sendBroadcastMessage(
        event: event,
        payload: message,
      );
    }
  }

  /// Lo que se escribe en una celda (`text == null`: se dejó de escribir).
  Future<void> sendTyping(String shotUid, String column, String? text) async {
    try {
      await _send(_typingEvent, {
        'shotUid': shotUid,
        'column': column,
        'text': text,
      }, project: await projectOfKey?.call(shotUid));
    } catch (e) {
      debugPrint('Texto en vivo no enviado: $e');
    }
  }

  /// Envía un mensaje del folio compartido (comprimido y, si es grande, en
  /// partes: el canal no admite mensajes muy largos).
  Future<void> sendDrawing(Map<String, dynamic> message) async {
    try {
      final key = message['key'];
      final project = key is String ? await projectOfKey?.call(key) : null;
      for (final part in DrawingWire.pack(message)) {
        await _send(_drawingEvent, part, project: project);
      }
    } catch (e) {
      debugPrint('Dibujo en vivo no enviado: $e');
    }
  }

  /// Avisa de que este equipo acaba de subir [hash] de [projectCloudId].
  Future<void> announceSnapshot(String projectCloudId, String hash) async {
    try {
      await _send(
        _snapshotEvent,
        {
          'projectCloudId': projectCloudId,
          'hash': hash,
          'device': deviceLabel(),
        },
        project: projectCloudId,
        onlySubscribed: false,
      );
    } catch (e) {
      // Sin aviso, el otro equipo lo baja en su pasada de cada minuto.
      debugPrint('Aviso en vivo no enviado: $e');
    }
  }

  /// Avisa de que este equipo acaba de subir imágenes de [projectCloudId].
  Future<void> announceMedia(String projectCloudId) async {
    try {
      await _send(
        _mediaEvent,
        {'projectCloudId': projectCloudId},
        project: projectCloudId,
        onlySubscribed: false,
      );
    } catch (e) {
      debugPrint('Aviso de imágenes no enviado: $e');
    }
  }

  /// Pide al Mac que actualice este dispositivo.
  Future<void> sendDeviceUpdateRequest(DeviceUpdateRequest request) =>
      _sendUpdateMessage(_updateRequestEvent, request.toPayload());

  /// Cuenta al dispositivo que lo pidió cómo va su actualización.
  Future<void> sendDeviceUpdateStatus(DeviceUpdateStatus status) =>
      _sendUpdateMessage(_updateStatusEvent, status.toPayload());

  Future<void> _sendUpdateMessage(
    String event,
    Map<String, dynamic> payload,
  ) async {
    final joined = _workspace;
    if (joined == null || !joined.subscribed) return;
    try {
      await joined.channel.sendBroadcastMessage(
        event: event,
        payload: {...payload, 'installId': await InstallId.get()},
      );
    } catch (e) {
      debugPrint('Mensaje de actualización no enviado: $e');
    }
  }

  Future<void> _remove(_Joined joined) async {
    joined.subscribed = false;
    joined.joining = false;
    try {
      await _client.removeChannel(joined.channel);
    } catch (_) {}
  }

  Future<void> _leaveWorkspace() async {
    final joined = _workspace;
    updateHostAvailable.value = false;
    _workspace = null;
    _workspaceId = null;
    if (joined != null) await _remove(joined);
  }

  Future<void> dispose() async {
    await _leaveWorkspace();
    for (final joined in _projects.values) {
      await _remove(joined);
    }
    _projects.clear();
    await _notices.close();
    await _mediaNotices.close();
    await _drawings.close();
    await _updateRequests.close();
    await _updateStatuses.close();
    updateHostAvailable.dispose();
  }
}

final realtimeHubProvider = Provider<RealtimeHub?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return null;
  final hub = RealtimeHub(client);
  final keys = LiveKeyProjects(ref.watch(databaseProvider));
  hub.projectOfKey = (key) async {
    try {
      return await keys.cloudIdOf(key);
    } catch (_) {
      // Sin saber de qué proyecto es, va solo al canal del espacio propio.
      return null;
    }
  };
  ref.onDispose(hub.dispose);
  return hub;
});

/// Quién edita qué, para bloquear planos y ver lo que se escribe en ellos.
final liveEditingProvider = ChangeNotifierProvider<LiveEditing>((ref) {
  final hub = ref.watch(realtimeHubProvider);
  final live = LiveEditing(
    installId: '',
    publishEditing: (shot, since) => unawaited(hub?.setEditing(shot, since)),
    publishTyping: (shot, column, text) =>
        unawaited(hub?.sendTyping(shot, column, text)),
  );
  unawaited(InstallId.get().then((id) => live.installId = id));
  hub
    ?..onPeers = live.setPeers
    ..onTyping = live.receiveTyping;
  return live;
});
