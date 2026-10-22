import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/annotations/annotation_document.dart';
import '../../shared/annotations/live_drawing_link.dart';
import 'live_editing.dart';
import 'realtime_hub.dart';

/// Cómo viaja un mensaje del folio por el canal: JSON comprimido en base64
/// y troceado (el canal en vivo no admite mensajes muy largos).
abstract final class DrawingWire {
  /// Caracteres por parte (holgado bajo el límite del canal).
  static const partSize = 60000;

  static List<Map<String, dynamic>> pack(
    Map<String, dynamic> message, {
    int size = partSize,
  }) {
    final data = base64Encode(gzip.encode(utf8.encode(jsonEncode(message))));
    final id =
        '${DateTime.now().microsecondsSinceEpoch}'
        '${Random().nextInt(1 << 20)}';
    final n = max(1, (data.length / size).ceil());
    return [
      for (var i = 0; i < n; i++)
        {
          'id': id,
          'i': i,
          'n': n,
          'z': data.substring(i * size, min(data.length, (i + 1) * size)),
        },
    ];
  }

  static Map<String, dynamic>? unpack(String data) {
    try {
      final json = jsonDecode(utf8.decode(gzip.decode(base64Decode(data))));
      return json is Map ? Map<String, dynamic>.from(json) : null;
    } catch (_) {
      return null;
    }
  }
}

/// Junta las partes de [DrawingWire.pack] según llegan.
class DrawingWireAssembler {
  final Map<String, List<String?>> _pending = {};
  final List<String> _order = [];

  /// El mensaje entero en cuanto llega su última parte.
  Map<String, dynamic>? add(Map<String, dynamic> part) {
    final id = part['id'];
    final i = (part['i'] as num?)?.toInt();
    final n = (part['n'] as num?)?.toInt();
    final z = part['z'];
    if (id is! String || i == null || n == null || z is! String) return null;
    if (n < 1 || i < 0 || i >= n) return null;
    if (n == 1) return DrawingWire.unpack(z);
    final parts = _pending.putIfAbsent(id, () {
      _order.add(id);
      // Las que se quedaron a medias (se perdió una parte) se olvidan.
      while (_order.length > 8) {
        _pending.remove(_order.removeAt(0));
      }
      return List<String?>.filled(n, null);
    });
    if (parts.length != n) return null;
    parts[i] = z;
    if (parts.any((p) => p == null)) return null;
    _pending.remove(id);
    _order.remove(id);
    return DrawingWire.unpack(parts.join());
  }
}

/// Un folio compartido por turnos sobre el canal en vivo: el turno es el
/// mismo bloqueo que el resto de la edición compartida ([LiveEditing]) con
/// la clave del dibujo; el dibujo viaja por [send] / [incoming].
class LiveDrawingSession implements LiveDrawingLink {
  LiveDrawingSession({
    required this.key,
    required this.live,
    required this.send,
    required Stream<Map<String, dynamic>> incoming,
    this.docInterval = const Duration(milliseconds: 250),
    this.strokeInterval = const Duration(milliseconds: 70),
  }) {
    _previous = live.myShotUid == key ? null : live.myShotUid;
    _sub = incoming.listen(_receive);
    live.addListener(_onPeers);
    _onPeers();
  }

  final String key;
  final LiveEditing live;
  final void Function(Map<String, dynamic> message) send;
  final Duration docInterval;
  final Duration strokeInterval;

  final _other = ValueNotifier<String?>(null);
  final _mine = ValueNotifier<bool>(false);
  final _remoteDoc = ValueNotifier<AnnotationDocument?>(null);
  final _remoteStroke = ValueNotifier<AnnotationStroke?>(null);

  final _encoder = DrawingDeltaEncoder();
  final _decoder = DrawingDeltaDecoder();
  late final StreamSubscription<Map<String, dynamic>> _sub;

  /// Lo que este equipo editaba antes de abrir el folio: se recupera al
  /// salir.
  String? _previous;
  String? _holderId;
  AnnotationDocument? _lastDoc;
  AnnotationDocument? _pendingDoc;
  Timer? _docTimer;
  AnnotationStroke? _pendingStroke;
  Timer? _strokeTimer;
  DateTime? _askedAt;
  bool _disposed = false;

  @override
  ValueListenable<String?> get otherDrawer => _other;
  @override
  ValueListenable<bool> get mine => _mine;
  @override
  ValueListenable<AnnotationDocument?> get remoteDocument => _remoteDoc;
  @override
  ValueListenable<AnnotationStroke?> get remoteStroke => _remoteStroke;

  void _onPeers() {
    if (_disposed) return;
    final holder = live.holderOf(key);
    final mine = holder == null && live.myShotUid == key;
    // Llega otro a dibujar: se le pide el dibujo entero.
    if (holder != null && holder.installId != _holderId) _ask(force: true);
    _holderId = holder?.installId;
    _other.value = holder?.device;
    if (mine && !_mine.value) _encoder.reset();
    _mine.value = mine;
  }

  @override
  void claim() {
    if (_disposed || _other.value != null) return;
    live.focusShot(key);
    _onPeers();
  }

  @override
  void publish(AnnotationDocument document) {
    if (_disposed || !_mine.value) return;
    _lastDoc = document;
    _pendingDoc = document;
    _docTimer ??= Timer(docInterval, _flushDoc);
  }

  void _flushDoc() {
    _docTimer?.cancel();
    _docTimer = null;
    final doc = _pendingDoc;
    _pendingDoc = null;
    if (doc == null || _disposed) return;
    send({'key': key, 'kind': 'doc', ..._encoder.encode(doc)});
  }

  @override
  void publishStroke(AnnotationStroke? stroke) {
    if (_disposed || !_mine.value) return;
    if (stroke == null) {
      // El trazo ya está en el dibujo: primero el dibujo, luego se quita.
      _strokeTimer?.cancel();
      _strokeTimer = null;
      _pendingStroke = null;
      _flushDoc();
      send({'key': key, 'kind': 'stroke'});
      return;
    }
    _pendingStroke = stroke;
    _strokeTimer ??= Timer(strokeInterval, _flushStroke);
  }

  void _flushStroke() {
    _strokeTimer = null;
    final stroke = _pendingStroke;
    _pendingStroke = null;
    if (stroke == null || _disposed) return;
    send({'key': key, 'kind': 'stroke', 's': stroke.toJson()});
  }

  void _ask({bool force = false}) {
    final now = DateTime.now();
    final last = _askedAt;
    if (!force &&
        last != null &&
        now.difference(last) < const Duration(milliseconds: 1500)) {
      return;
    }
    _askedAt = now;
    send({'key': key, 'kind': 'hello'});
  }

  void _receive(Map<String, dynamic> message) {
    if (_disposed || message['key'] != key) return;
    switch (message['kind']) {
      case 'hello':
        if (!_mine.value) return;
        _encoder.reset();
        final doc = _pendingDoc ?? _lastDoc;
        if (doc != null) {
          _pendingDoc = doc;
          _flushDoc();
        }
      case 'doc':
        if (_mine.value) return;
        final doc = _decoder.apply(message);
        if (doc == null) {
          _ask();
          return;
        }
        _remoteStroke.value = null;
        _remoteDoc.value = doc;
      case 'stroke':
        if (_mine.value) return;
        final raw = message['s'];
        _remoteStroke.value = raw is Map
            ? AnnotationStroke.fromJson(Map<String, dynamic>.from(raw))
            : null;
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    if (_mine.value) _flushDoc();
    _disposed = true;
    _docTimer?.cancel();
    _strokeTimer?.cancel();
    unawaited(_sub.cancel());
    live.removeListener(_onPeers);
    final previous = _previous;
    // Fuera del desmontaje del folio: avisar mientras se quita el árbol no
    // se puede.
    Future.microtask(() {
      if (live.myShotUid == key) {
        live.leave(key);
        if (previous != null) live.focusShot(previous);
      }
      _other.dispose();
      _mine.dispose();
      _remoteDoc.dispose();
      _remoteStroke.dispose();
    });
  }
}

/// El folio compartido de [key] ([LiveKey.drawing]); nulo sin nube (solo se
/// dibuja aquí).
LiveDrawingLink? liveDrawingLinkFor(BuildContext context, String key) {
  final ProviderContainer container;
  try {
    container = ProviderScope.containerOf(context, listen: false);
  } catch (_) {
    return null;
  }
  final hub = container.read(realtimeHubProvider);
  if (hub == null) return null;
  return LiveDrawingSession(
    key: key,
    live: container.read(liveEditingProvider),
    send: (message) => unawaited(hub.sendDrawing(message)),
    incoming: hub.drawingMessages,
  );
}
