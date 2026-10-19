import 'dart:async';

import 'package:flutter/foundation.dart';

/// Qué se edita, como clave del canal en vivo. Un plano va con su uid tal
/// cual (así lo entienden también las versiones anteriores); lo demás, con
/// su tipo delante.
abstract final class LiveKey {
  static String shot(String uid) => uid;
  static String site(String uid) => 'site:$uid';
  static String set(String uid) => 'set:$uid';
  static String lightSetup(String uid) => 'lightSetup:$uid';
  static String scene(String uid) => 'scene:$uid';
}

/// Lo que otro equipo está editando ahora (por el canal en vivo).
class PeerEditing {
  final String installId;
  final String device;
  final String shotUid;
  final DateTime since;

  const PeerEditing({
    required this.installId,
    required this.device,
    required this.shotUid,
    required this.since,
  });

  static PeerEditing? fromPayload(Map<String, dynamic> p) {
    final installId = p['installId'];
    final shotUid = p['shotUid'];
    final since = DateTime.tryParse(p['since'] as String? ?? '');
    if (installId is! String || shotUid is! String || since == null) {
      return null;
    }
    return PeerEditing(
      installId: installId,
      device: p['device'] as String? ?? 'otro equipo',
      shotUid: shotUid,
      since: since,
    );
  }
}

/// Quién edita [shotUid] y lo tiene, si no es este equipo. Si los dos lo
/// tomaron a la vez, lo tiene quien lo tomó antes (y, si coinciden, el id de
/// instalación menor), igual en los dos equipos.
PeerEditing? lockHolder(
  String shotUid, {
  required String myInstallId,
  String? myShotUid,
  DateTime? mySince,
  required Iterable<PeerEditing> peers,
}) {
  PeerEditing? holder;
  for (final p in peers) {
    if (p.shotUid != shotUid || p.installId == myInstallId) continue;
    if (holder == null || _before(p.since, p.installId, holder.since, holder.installId)) {
      holder = p;
    }
  }
  if (holder == null) return null;
  if (myShotUid == shotUid && mySince != null &&
      _before(mySince, myInstallId, holder.since, holder.installId)) {
    return null;
  }
  return holder;
}

bool _before(DateTime a, String aId, DateTime b, String bId) =>
    a.isBefore(b) || (a.isAtSameMomentAs(b) && aId.compareTo(bId) < 0);

/// Envía como mucho cada [interval] lo último que se ha escrito: el otro
/// equipo lo ve casi a la vez sin una ráfaga por cada tecla.
class TypingThrottle {
  final Duration interval;
  final void Function(String text) send;

  TypingThrottle({
    required this.send,
    this.interval = const Duration(milliseconds: 300),
  });

  Timer? _timer;
  String? _pending;
  String? _sent;

  void add(String text) {
    if (_timer != null) {
      _pending = text;
      return;
    }
    _emit(text);
    _timer = Timer(interval, _flush);
  }

  void _flush() {
    _timer = null;
    final pending = _pending;
    _pending = null;
    if (pending != null && pending != _sent) add(pending);
  }

  void _emit(String text) {
    _sent = text;
    send(text);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _pending = null;
  }
}

/// Estado en vivo de la edición compartida: qué plano edita cada equipo
/// (para bloquearlo en los demás) y lo que se está escribiendo en él.
///
/// Sin canal (sin nube o sin red) funciona igual pero no ve a nadie.
class LiveEditing extends ChangeNotifier {
  LiveEditing({
    required this.installId,
    required this.publishEditing,
    required this.publishTyping,
    this.releaseDelay = const Duration(seconds: 20),
  });

  /// Id de esta instalación; se completa en cuanto se lee de preferencias.
  String installId;

  /// Anuncia el plano que edita este equipo (`null`: ninguno).
  final void Function(String? shotUid, DateTime? since) publishEditing;

  /// Envía lo que se escribe (`text == null`: se dejó de escribir).
  final void Function(String shotUid, String column, String? text)
      publishTyping;

  /// Perder el foco no es haber terminado: se esconde el teclado del iPad,
  /// se abre un menú o se pulsa la barra de formato. Se suelta tras este
  /// rato sin volver; antes, si se pasa a otro plano, se sale de la
  /// pantalla ([leave]) o la app se va a segundo plano ([releaseAll]).
  final Duration releaseDelay;

  Map<String, PeerEditing> _peers = const {};
  final Map<String, Map<String, String>> _typing = {};
  final Map<(String, String), TypingThrottle> _throttles = {};
  String? _myShot;
  DateTime? _mySince;
  Timer? _release;

  String? get myShotUid => _myShot;

  /// Quién tiene [shotUid], si es otro equipo (ver [lockHolder]).
  PeerEditing? holderOf(String? shotUid) => shotUid == null
      ? null
      : lockHolder(
          shotUid,
          myInstallId: installId,
          myShotUid: _myShot,
          mySince: _mySince,
          peers: _peers.values,
        );

  /// El primer otro equipo que edita [key] desde antes de [mine]: lo que
  /// impide tocarlo aquí aunque este equipo anuncie otra cosa (en la planta,
  /// el esquema o el set que se ven desde un plano).
  PeerEditing? holderBefore(String key, DateTime? mine) {
    PeerEditing? first;
    for (final p in _peers.values) {
      if (p.shotUid != key || p.installId == installId) continue;
      if (first == null ||
          _before(p.since, p.installId, first.since, first.installId)) {
        first = p;
      }
    }
    if (first == null) return null;
    if (mine != null && !first.since.isBefore(mine)) return null;
    return first;
  }

  /// Desde cuándo edita este equipo lo que tiene.
  DateTime? get mySince => _mySince;

  /// Lo que otro equipo está escribiendo en esa celda, mientras lo escribe.
  String? typingIn(String? shotUid, String column) =>
      shotUid == null ? null : _typing[shotUid]?[column];

  /// Este equipo entra a editar [shotUid].
  void focusShot(String? shotUid) {
    _release?.cancel();
    _release = null;
    if (shotUid == null || shotUid == _myShot) return;
    _myShot = shotUid;
    _mySince = DateTime.now().toUtc();
    publishEditing(_myShot, _mySince);
    notifyListeners();
  }

  /// Este equipo sale de [shotUid] (se suelta tras [releaseDelay]).
  void blurShot(String? shotUid) {
    if (shotUid == null || shotUid != _myShot) return;
    _release?.cancel();
    _release = Timer(releaseDelay, () {
      _release = null;
      if (_myShot != shotUid) return;
      _myShot = null;
      _mySince = null;
      publishEditing(null, null);
      notifyListeners();
    });
  }

  /// Este equipo deja [shotUid] del todo (sale de la pantalla): se suelta
  /// ya, sin esperar.
  void leave(String? shotUid) {
    if (shotUid == null || shotUid != _myShot) return;
    _release?.cancel();
    _release = null;
    _myShot = null;
    _mySince = null;
    publishEditing(null, null);
    notifyListeners();
  }

  /// Suelta lo que tenga (la app se va a segundo plano).
  void releaseAll() => leave(_myShot);

  void typing(String? shotUid, String column, String text) {
    if (shotUid == null || shotUid != _myShot) return;
    _throttles
        .putIfAbsent(
          (shotUid, column),
          () => TypingThrottle(
            send: (t) => publishTyping(shotUid, column, t),
          ),
        )
        .add(text);
  }

  void typingEnd(String? shotUid, String column) {
    if (shotUid == null) return;
    _throttles.remove((shotUid, column))?.cancel();
    publishTyping(shotUid, column, null);
  }

  /// Llega del canal: quién edita qué en los demás equipos.
  void setPeers(Iterable<PeerEditing> peers) {
    _peers = {for (final p in peers) p.installId: p};
    // Lo escrito por quien ya no está en ese plano deja de verse.
    final editing = {for (final p in _peers.values) p.shotUid};
    _typing.removeWhere((shot, _) => !editing.contains(shot));
    notifyListeners();
  }

  /// Llega del canal: lo que otro equipo escribe (`null`: terminó).
  void receiveTyping(String shotUid, String column, String? text) {
    if (text == null) {
      _typing[shotUid]?.remove(column);
      if (_typing[shotUid]?.isEmpty ?? false) _typing.remove(shotUid);
    } else {
      (_typing[shotUid] ??= {})[column] = text;
    }
    notifyListeners();
  }

  bool _disposed = false;

  @override
  void notifyListeners() {
    // Un aviso que llega tarde (al salir de una pantalla) no hace nada.
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _release?.cancel();
    for (final t in _throttles.values) {
      t.cancel();
    }
    super.dispose();
  }
}
