import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cuánto va adelantado el servidor respecto a este equipo. Sirve para
/// comparar una edición de aquí con una hora de la nube cuando el reloj del
/// equipo no está en hora.
abstract final class ServerClock {
  static const _refresh = Duration(minutes: 10);

  static Duration? _offset;
  static DateTime? _measuredAt;

  /// El desfase respecto a [server], leída entre [sent] y [received].
  @visibleForTesting
  static Duration offsetFrom(
    DateTime sent,
    DateTime received,
    DateTime server,
  ) {
    final middle = sent.add(received.difference(sent) ~/ 2);
    return server.difference(middle);
  }

  /// Sin la migración 013 o sin red no hay medida: se comporta como antes.
  static Future<Duration> offset(SupabaseClient client) async {
    final known = _offset;
    final at = _measuredAt;
    if (known != null &&
        at != null &&
        DateTime.now().difference(at) < _refresh) {
      return known;
    }
    try {
      final sent = DateTime.now();
      final raw = await client.rpc('iris_server_now');
      final received = DateTime.now();
      final server = DateTime.tryParse('$raw');
      if (server == null) return known ?? Duration.zero;
      _measuredAt = received;
      return _offset = offsetFrom(sent, received, server);
    } catch (e) {
      debugPrint('Hora del servidor no disponible: $e');
      return known ?? Duration.zero;
    }
  }

  @visibleForTesting
  static void reset() {
    _offset = null;
    _measuredAt = null;
  }
}
