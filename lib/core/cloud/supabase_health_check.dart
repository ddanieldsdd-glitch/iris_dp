import 'dart:convert';
import 'dart:io';

import 'cloud_runtime_config.dart';

/// Comprueba que la URL de Supabase responde y que la API key es aceptada.
Future<SupabaseHealthResult> checkSupabaseReachability() async {
  if (!CloudRuntimeConfig.isActive) {
    return const SupabaseHealthResult(
      ok: false,
      message: 'Supabase no configurado en esta compilación de la app.',
    );
  }

  final uri = Uri.tryParse(CloudRuntimeConfig.url);
  if (uri == null || uri.host.isEmpty) {
    return SupabaseHealthResult(
      ok: false,
      message: 'SUPABASE_URL no es válida: ${CloudRuntimeConfig.url}',
    );
  }

  final host = uri.host;
  final key = CloudRuntimeConfig.anonKey;
  if (key.isEmpty) {
    return SupabaseHealthResult(
      ok: false,
      message: 'Falta SUPABASE_ANON_KEY para $host',
      host: host,
    );
  }

  // Auth settings exige API key válida; mejor señal que un GET genérico.
  final authSettings = await _probe(
    uri.replace(path: '/auth/v1/settings'),
    host,
    key,
    requireValidKey: true,
  );
  if (authSettings.ok) return authSettings;
  if (authSettings.invalidApiKey) return authSettings;

  final paths = ['/auth/v1/health', '/rest/v1/', '/'];
  for (final path in paths) {
    final result = await _probe(uri.replace(path: path), host, key);
    if (result.ok) return result;
    if (result.invalidApiKey) return result;
    if (result.reachable) {
      return SupabaseHealthResult(
        ok: true,
        message: 'Conexión correcta con $host',
        host: host,
        reachable: true,
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

Future<SupabaseHealthResult> _probe(
  Uri uri,
  String host,
  String apiKey, {
  bool requireValidKey = false,
}) async {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 12)
    ..idleTimeout = const Duration(seconds: 12);

  try {
    final request =
        await client.getUrl(uri).timeout(const Duration(seconds: 12));
    request.headers.set('apikey', apiKey);
    request.headers.set('Authorization', 'Bearer $apiKey');
    final response = await request.close().timeout(const Duration(seconds: 12));
    final body = await response.transform(utf8.decoder).join();
    final lower = body.toLowerCase();

    final invalidKey = response.statusCode == 401 &&
        (lower.contains('invalid api key') ||
            lower.contains('invalid jwt') ||
            lower.contains('malformed'));

    if (invalidKey) {
      return SupabaseHealthResult(
        ok: false,
        message:
            'API key inválida para $host.\n\n'
            'Copia la clave «anon public» (JWT eyJ…) de supabase.com → '
            'Settings → API, actualiza .env y reinicia con '
            './scripts/run_cloud.sh (cierra la app por completo).',
        host: host,
        reachable: true,
        invalidApiKey: true,
      );
    }

    if (requireValidKey) {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return SupabaseHealthResult(
          ok: true,
          message: 'Conexión correcta con $host',
          host: host,
          reachable: true,
        );
      }
      return SupabaseHealthResult(
        ok: false,
        message: 'Supabase respondió ${response.statusCode}',
        host: host,
        reachable: true,
      );
    }

    // Cualquier respuesta HTTP = DNS y red OK (salvo 401 de API key, arriba).
    if (response.statusCode >= 200 && response.statusCode < 600) {
      final looksLikeSupabase = lower.contains('gotrue') ||
          lower.contains('swagger') ||
          response.statusCode == 200;
      if (looksLikeSupabase || response.statusCode < 500) {
        return SupabaseHealthResult(
          ok: true,
          message: 'Conexión correcta con $host',
          host: host,
          reachable: true,
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

  /// true si el host responde pero rechaza la API key (401).
  final bool invalidApiKey;

  const SupabaseHealthResult({
    required this.ok,
    required this.message,
    this.host,
    this.isDnsError = false,
    this.reachable = false,
    this.invalidApiKey = false,
  });
}
