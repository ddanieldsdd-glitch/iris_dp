import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/app_database.dart';
import '../../core/sync/realtime_hub.dart';
import 'capture_store.dart';

/// Paso de las capturas del iPhone al PC por la red local (≈1 GB cada una:
/// la nube no da para eso). El PC escucha en [port] mientras IRIS está
/// abierta y lo anuncia en la presencia del espacio de trabajo
/// (`RealtimeHub.setScanBuilder`); el iPhone, al verlo, prueba sus
/// direcciones: solo contestan si están en la misma Wi‑Fi.
abstract final class CaptureLan {
  static const port = 47820;

  /// Clave por instalación: solo la ven los miembros del espacio (en la
  /// presencia), así que nadie más de la red puede mandar archivos.
  static Future<String> token() async {
    const key = 'iris_capture_token';
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString(key);
    if (token == null) {
      final r = Random.secure();
      token = base64Url.encode(List.generate(18, (_) => r.nextInt(256)));
      await prefs.setString(key, token);
    }
    return token;
  }

  /// Las IPv4 de este equipo en la red local.
  static Future<List<String>> lanIps() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      return [
        for (final i in interfaces)
          for (final a in i.addresses)
            if (!a.isLoopback && !a.isLinkLocal) a.address,
      ];
    } on SocketException {
      return const [];
    }
  }
}

/// El PC: recibe las capturas y las deja en `IRIS Capturas/<uid>.iriscapture
/// .zip`, comprobando tamaño y SHA‑256.
class CaptureReceiver {
  final String token;

  /// Una captura llegó entera (su uid).
  final Future<void> Function(String uid) onReceived;

  /// Dónde deja los zips; si no, en [CaptureStore] (pruebas).
  final Directory? root;

  CaptureReceiver({required this.token, required this.onReceived, this.root});

  HttpServer? _server;

  int? get port => _server?.port;

  /// [port] 0: uno libre (pruebas).
  Future<void> start({int port = CaptureLan.port}) async {
    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _server!.listen(
      _handle,
      onError: (Object e) {
        debugPrint('Receptor de capturas: $e');
      },
    );
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  static final _uidPattern = RegExp(r'^[A-Za-z0-9_-]{6,64}$');

  Future<void> _handle(HttpRequest request) async {
    final res = request.response;
    try {
      if (request.uri.queryParameters['token'] != token) {
        await _drain(request);
        res.statusCode = HttpStatus.unauthorized;
        return;
      }
      final segments = request.uri.pathSegments;
      if (request.method == 'GET' && segments.join('/') == 'ping') {
        res.headers.contentType = ContentType.json;
        res.write(jsonEncode({'ok': true}));
        return;
      }
      if (request.method == 'PUT' &&
          segments.length == 2 &&
          segments[0] == 'capture' &&
          _uidPattern.hasMatch(segments[1])) {
        res.statusCode = await _receive(request, segments[1]);
        return;
      }
      await _drain(request);
      res.statusCode = HttpStatus.notFound;
    } catch (e) {
      debugPrint('Receptor de capturas: $e');
      res.statusCode = HttpStatus.internalServerError;
    } finally {
      await res.close();
    }
  }

  Future<int> _receive(HttpRequest request, String uid) async {
    final size = int.tryParse(request.uri.queryParameters['size'] ?? '');
    final expected = request.uri.queryParameters['sha256'];
    if (size == null || expected == null) {
      await _drain(request);
      return HttpStatus.badRequest;
    }
    final dir = root;
    final dest = dir == null
        ? await CaptureStore.zipFor(uid)
        : File('${dir.path}/$uid.iriscapture.zip');
    final part = File('${dest.path}.part');
    final sink = part.openWrite();
    final hashOut = _DigestSink();
    final hasher = sha256.startChunkedConversion(hashOut);
    var received = 0;
    try {
      await for (final chunk in request) {
        received += chunk.length;
        hasher.add(chunk);
        sink.add(chunk);
      }
    } finally {
      hasher.close();
      await sink.close();
    }
    if (received != size || hashOut.value.toString() != expected) {
      await part.delete();
      return HttpStatus.badRequest;
    }
    if (await dest.exists()) await dest.delete();
    await part.rename(dest.path);
    await onReceived(uid);
    return HttpStatus.ok;
  }

  static Future<void> _drain(HttpRequest request) async {
    await request.drain<void>();
  }
}

class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}

/// El iPhone: manda al PC las capturas hechas aquí que siguen pendientes.
class CaptureSender {
  final AppDatabase db;

  CaptureSender(this.db);

  static bool _running = false;

  /// Hay algo que enviar desde este equipo.
  Future<List<LocationCapture>> pending() async {
    final me = await InstallId.get();
    final out = <LocationCapture>[];
    for (final c in await db.getCapturesWithStatus([
      CaptureStatus.onPhone,
      // Si la app se cerró a mitad, se queda en «enviando»: se repite.
      CaptureStatus.sending,
    ])) {
      if (c.originInstallId != me || c.uid == null) continue;
      if (await (await CaptureStore.zipFor(c.uid!)).exists()) out.add(c);
    }
    return out;
  }

  /// Prueba los PC anunciados y envía lo pendiente al primero que conteste.
  /// Devuelve cuántas capturas llegaron.
  Future<int> sendPending(List<ScanBuilderPeer> builders) async {
    if (_running || builders.isEmpty) return 0;
    _running = true;
    try {
      final todo = await pending();
      if (todo.isEmpty) return 0;
      final target = await _reachable(builders);
      if (target == null) return 0;
      var sent = 0;
      for (final c in todo) {
        if (await _send(c, target.$1, target.$2)) sent++;
      }
      return sent;
    } finally {
      _running = false;
    }
  }

  /// El primer PC (y su dirección) que contesta en la red local.
  Future<(ScanBuilderPeer, Uri)?> _reachable(
    List<ScanBuilderPeer> builders,
  ) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    try {
      for (final peer in builders) {
        for (final ip in peer.lanIps) {
          final base = Uri(scheme: 'http', host: ip, port: peer.port);
          try {
            final req = await client
                .getUrl(
                  base.replace(
                    path: '/ping',
                    queryParameters: {'token': peer.token},
                  ),
                )
                .timeout(const Duration(seconds: 2));
            final res = await req.close().timeout(const Duration(seconds: 2));
            await res.drain<void>();
            if (res.statusCode == HttpStatus.ok) return (peer, base);
          } on Object {
            // Otra red: se prueba la siguiente dirección.
          }
        }
      }
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<bool> _send(LocationCapture c, ScanBuilderPeer peer, Uri base) async {
    final uid = c.uid!;
    final zip = await CaptureStore.zipFor(uid);
    final size = await zip.length();
    final digest = await sha256.bind(zip.openRead()).first;
    await db.updateCapture(
      uid,
      const LocationCapturesCompanion(
        status: Value(CaptureStatus.sending),
        progress: Value(0),
        error: Value(null),
      ),
    );
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final req = await client.putUrl(
        base.replace(
          path: '/capture/$uid',
          queryParameters: {
            'token': peer.token,
            'size': '$size',
            'sha256': digest.toString(),
          },
        ),
      );
      req.contentLength = size;
      req.headers.contentType = ContentType('application', 'zip');
      var sent = 0;
      var lastShown = 0.0;
      await req.addStream(
        zip.openRead().map((chunk) {
          sent += chunk.length;
          final f = sent / size;
          if (f - lastShown >= 0.02) {
            lastShown = f;
            unawaited(
              db.updateCapture(
                uid,
                LocationCapturesCompanion(progress: Value(f)),
                touch: false,
              ),
            );
          }
          return chunk;
        }),
      );
      final res = await req.close();
      await res.drain<void>();
      if (res.statusCode != HttpStatus.ok) {
        throw HttpException('el PC respondió ${res.statusCode}');
      }
      await db.updateCapture(
        uid,
        LocationCapturesCompanion(
          status: const Value(CaptureStatus.onPc),
          progress: const Value(0),
          builderInstallId: Value(peer.installId),
        ),
      );
      return true;
    } on Object catch (e) {
      debugPrint('Envío de la captura $uid: $e');
      // Se repite entera en la próxima pasada.
      await db.updateCapture(
        uid,
        const LocationCapturesCompanion(
          status: Value(CaptureStatus.onPhone),
          progress: Value(0),
        ),
      );
      return false;
    } finally {
      client.close(force: true);
    }
  }
}
