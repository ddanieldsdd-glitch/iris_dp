import 'dart:convert';
import 'dart:io';

import 'supabase_config.dart';
import 'cloud_runtime_config.dart';

/// Comprueba que la URL de Supabase responde (DNS + red).
Future<SupabaseHealthResult> checkSupabaseReachability() async {
  if (!CloudRuntimeConfig.isActive) {
    return const SupabaseHealthResult(
      ok: false,
      message: 'Supabase no configurado en esta compilación de la app.',
    );
  }

  final uri = Uri.tryParse(SupabaseConfig.url);
  if (uri == null || uri.host.isEmpty) {
    return const SupabaseHealthResult(
      ok: false,
      message: 'SUPABASE_URL no es válida: ${SupabaseConfig.url}',
    );
  }

  final host = uri.host;
  final paths = ['/auth/v1/health', '/rest/v1/', '/'];

  for (final path in paths) {
    final result = await _probe(uri.replace(path: path), host);
    if (result.ok) return result;
    // Si no es error DNS, el servidor existe pero ese path falló — aún OK.
    if (result.reachable) {
      return SupabaseHealthResult(
        ok: true,
        message: 'Conexión correcta con $host',
        host: host,
      );
    }
  }

  return SupabaseHealthResult(
    ok: false,
    message:
        'No se pudo conectar a «$host».\n\n'
        'Comprueba internet y que la URL en .env sea exactamente la del '
        'dashboard de Supabase.\n'
        'Si el navegador abre esa URL, pulsa «Crear cuenta» igualmente.',
    host: host,
    isDnsError: true,
  );
}

Future<SupabaseHealthResult> _probe(Uri uri, String host) async {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 12)
    ..idleTimeout = const Duration(seconds: 12);

  try {
    final request = await client.getUrl(uri).timeout(const Duration(seconds: 12));
    request.headers.set('apikey', SupabaseConfig.anonKey);
    request.headers.set('Authorization', 'Bearer ${SupabaseConfig.anonKey}');
    final response = await request.close().timeout(const Duration(seconds: 12));
    final body = await response.transform(utf8.decoder).join();

    // Cualquier respuesta HTTP = DNS y red OK.
    if (response.statusCode >= 200 && response.statusCode < 600) {
      final looksLikeSupabase = body.contains('invalid') ||
          body.contains('API key') ||
          body.contains('GoTrue') ||
          response.statusCode == 200;
      if (looksLikeSupabase || response.statusCode < 500) {
        return SupabaseHealthResult(
          ok: true,
          message: 'Conexión correcta con $host',
          host: host,
        );
      }
    }

    return SupabaseHealthResult(
      ok: false,
      message: 'Supabase respondió ${response.statusCode}',
      host: host,
      reachable: true,
    );
  } catch (e) {
    final msg = e.toString().toLowerCase();
    final isDns = msg.contains('failed host lookup') ||
        msg.contains('nxdomain') ||
        msg.contains('nodename nor servname') ||
        msg.contains('name or service not known');

    return SupabaseHealthResult(
      ok: false,
      message: isDns
          ? 'No se encuentra el servidor «$host».'
          : 'Error de red: $e',
      host: host,
      isDnsError: isDns,
      reachable: !isDns,
    );
  } finally {
    client.close(force: true);
  }
}

class SupabaseHealthResult {
  final bool ok;
  final String message;
  final String? host;
  final bool isDnsError;

  /// true si hubo respuesta de red aunque el check estricto falle.
  final bool reachable;

  const SupabaseHealthResult({
    required this.ok,
    required this.message,
    this.host,
    this.isDnsError = false,
    this.reachable = false,
  });
}
