import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../cloud/cloud_providers.dart';
import 'device_label.dart';
import 'live_drawing.dart';
import 'live_editing.dart';

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

/// Canal en vivo del espacio de trabajo (Supabase Realtime, sin tablas):
/// quien sube un proyecto lo avisa y los demás lo bajan en segundos, sin
/// esperar a la pasada de cada minuto. Es un aviso, no el contenido: si se
/// pierde, la pasada de cada minuto lo recoge igual.
class RealtimeHub {
  final SupabaseClient _client;

  RealtimeHub(this._client);

  static const _snapshotEvent = 'snapshot';
  static const _mediaEvent = 'media';
  static const _typingEvent = 'typing';
  static const _drawingEvent = 'drawing';

  /// Quién edita qué en los demás equipos (presencia del canal).
  void Function(List<PeerEditing> peers)? onPeers;

  /// Lo que otro equipo escribe (`text == null`: terminó).
  void Function(String shotUid, String column, String? text)? onTyping;

  bool _subscribed = false;
  Map<String, dynamic>? _editing;
  String? _installId;

  RealtimeChannel? _channel;
  String? _workspaceId;
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

  /// ¿Está dentro del canal (o entrando)?
  bool get isLive => _channel != null && (_subscribed || _joining);

  /// Entrando en el canal, aún sin respuesta.
  bool _joining = false;

  /// Se une al canal del espacio de trabajo; si ya está dentro, no hace
  /// nada. Si el canal se cerró o falló (el iPad en segundo plano, una red
  /// que se cayó), vuelve a entrar.
  Future<void> connect(String workspaceId) async {
    if (_workspaceId == workspaceId && isLive) return;
    await _leave();
    _workspaceId = workspaceId;
    final installId = _installId = await InstallId.get();
    _joining = true;
    _channel = _client
        .channel(
          'iris-ws-$workspaceId',
          opts: RealtimeChannelConfig(key: installId),
        )
        .onPresenceSync((_) => _emitPeers())
        .onPresenceLeave((_) => _emitPeers())
        .onBroadcast(
          event: _typingEvent,
          callback: (payload) {
            final shot = payload['shotUid'];
            final column = payload['column'];
            if (shot is! String || column is! String) return;
            if (payload['installId'] == installId) return;
            onTyping?.call(shot, column, payload['text'] as String?);
          },
        )
        .onBroadcast(
          event: _drawingEvent,
          callback: (payload) {
            if (payload['installId'] == installId) return;
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
            _notices.add(SnapshotNotice(
              projectCloudId: project,
              hash: hash,
              device: payload['device'] as String?,
            ));
          },
        )
        .onBroadcast(
          event: _mediaEvent,
          callback: (payload) {
            final project = payload['projectCloudId'];
            if (project is! String) return;
            if (payload['installId'] == installId) return;
            _mediaNotices.add(project);
          },
        )
        .subscribe((status, error) {
          _joining = false;
          _subscribed = status == RealtimeSubscribeStatus.subscribed;
          // Al conectarse (o reconectarse) se vuelve a decir qué se edita.
          if (_subscribed) unawaited(_track());
        });
  }

  void _emitPeers() {
    final channel = _channel;
    if (channel == null) return;
    final peers = <PeerEditing>[];
    for (final state in channel.presenceState()) {
      if (state.key == _installId) continue;
      for (final presence in state.presences) {
        final peer = PeerEditing.fromPayload(presence.payload);
        if (peer != null) peers.add(peer);
      }
    }
    onPeers?.call(peers);
  }

  /// Dice a los demás qué plano edita este equipo (`null`: ninguno).
  Future<void> setEditing(String? shotUid, DateTime? since) async {
    _editing = shotUid == null
        ? null
        : {
            'installId': await InstallId.get(),
            'device': deviceLabel(),
            'shotUid': shotUid,
            'since': since?.toIso8601String(),
          };
    await _track();
  }

  Future<void> _track() async {
    final channel = _channel;
    if (channel == null || !_subscribed) return;
    try {
      final editing = _editing;
      if (editing == null) {
        await channel.untrack();
      } else {
        await channel.track(editing);
      }
    } catch (e) {
      debugPrint('Presencia no enviada: $e');
    }
  }

  /// Lo que se escribe en una celda (`text == null`: se dejó de escribir).
  Future<void> sendTyping(String shotUid, String column, String? text) async {
    final channel = _channel;
    if (channel == null || !_subscribed) return;
    try {
      await channel.sendBroadcastMessage(
        event: _typingEvent,
        payload: {
          'installId': await InstallId.get(),
          'shotUid': shotUid,
          'column': column,
          'text': text,
        },
      );
    } catch (e) {
      debugPrint('Texto en vivo no enviado: $e');
    }
  }

  /// Envía un mensaje del folio compartido (comprimido y, si es grande, en
  /// partes: el canal no admite mensajes muy largos).
  Future<void> sendDrawing(Map<String, dynamic> message) async {
    final channel = _channel;
    if (channel == null || !_subscribed) return;
    try {
      final installId = await InstallId.get();
      for (final part in DrawingWire.pack(message)) {
        await channel.sendBroadcastMessage(
          event: _drawingEvent,
          payload: {...part, 'installId': installId},
        );
      }
    } catch (e) {
      debugPrint('Dibujo en vivo no enviado: $e');
    }
  }

  /// Avisa de que este equipo acaba de subir [hash] de [projectCloudId].
  Future<void> announceSnapshot(String projectCloudId, String hash) async {
    final channel = _channel;
    if (channel == null) return;
    try {
      await channel.sendBroadcastMessage(
        event: _snapshotEvent,
        payload: {
          'projectCloudId': projectCloudId,
          'hash': hash,
          'device': deviceLabel(),
          'installId': await InstallId.get(),
        },
      );
    } catch (e) {
      // Sin aviso, el otro equipo lo baja en su pasada de cada minuto.
      debugPrint('Aviso en vivo no enviado: $e');
    }
  }

  /// Avisa de que este equipo acaba de subir imágenes de [projectCloudId].
  Future<void> announceMedia(String projectCloudId) async {
    final channel = _channel;
    if (channel == null) return;
    try {
      await channel.sendBroadcastMessage(
        event: _mediaEvent,
        payload: {
          'projectCloudId': projectCloudId,
          'installId': await InstallId.get(),
        },
      );
    } catch (e) {
      debugPrint('Aviso de imágenes no enviado: $e');
    }
  }

  Future<void> _leave() async {
    final channel = _channel;
    _channel = null;
    _workspaceId = null;
    _subscribed = false;
    _joining = false;
    if (channel != null) {
      try {
        await _client.removeChannel(channel);
      } catch (_) {}
    }
  }

  Future<void> dispose() async {
    await _leave();
    await _notices.close();
    await _mediaNotices.close();
    await _drawings.close();
  }
}

final realtimeHubProvider = Provider<RealtimeHub?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return null;
  final hub = RealtimeHub(client);
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
