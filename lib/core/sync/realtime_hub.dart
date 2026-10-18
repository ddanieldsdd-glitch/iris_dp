import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../cloud/cloud_providers.dart';
import 'device_label.dart';

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

  RealtimeChannel? _channel;
  String? _workspaceId;
  final _notices = StreamController<SnapshotNotice>.broadcast();

  Stream<SnapshotNotice> get snapshotNotices => _notices.stream;

  /// Se une al canal del espacio de trabajo; si ya está, no hace nada.
  Future<void> connect(String workspaceId) async {
    if (_workspaceId == workspaceId && _channel != null) return;
    await _leave();
    _workspaceId = workspaceId;
    final installId = await InstallId.get();
    _channel = _client
        .channel('iris-ws-$workspaceId')
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
        .subscribe();
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

  Future<void> _leave() async {
    final channel = _channel;
    _channel = null;
    _workspaceId = null;
    if (channel != null) {
      try {
        await _client.removeChannel(channel);
      } catch (_) {}
    }
  }

  Future<void> dispose() async {
    await _leave();
    await _notices.close();
  }
}

final realtimeHubProvider = Provider<RealtimeHub?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return null;
  final hub = RealtimeHub(client);
  ref.onDispose(hub.dispose);
  return hub;
});
