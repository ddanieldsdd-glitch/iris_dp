import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cloud_providers.dart';
import 'profile_providers.dart';

/// Límites del plan gratuito de cada nube (para las barras de Ajustes).
abstract final class CloudQuota {
  /// Supabase Free: 500 MB de base de datos.
  static const supabaseDatabaseBytes = 500 * 1024 * 1024;

  /// Supabase Free: 1 GB de archivos (Storage).
  static const supabaseStorageBytes = 1024 * 1024 * 1024;

  /// Cloudinary Free: 25 créditos al mes; 1 crédito ≈ 1 GB guardado
  /// (los créditos también se gastan en transformaciones y tráfico).
  static const cloudinaryBytes = 25 * 1024 * 1024 * 1024;
}

/// Espacio usado en Supabase y Cloudinary (RPC `iris_storage_usage`, 012).
class CloudUsage {
  const CloudUsage({
    required this.databaseBytes,
    required this.storageBytes,
    required this.storageBuckets,
    required this.cloudinaryBytes,
    required this.cloudinaryAssets,
    this.measuredAt,
  });

  final int databaseBytes;
  final int storageBytes;
  final Map<String, int> storageBuckets;

  /// Suma de los registros de imágenes de IRIS (estimación).
  final int cloudinaryBytes;
  final int cloudinaryAssets;
  final DateTime? measuredAt;

  factory CloudUsage.fromJson(Map<String, dynamic> json) {
    int asInt(Object? v) => switch (v) {
      int i => i,
      num n => n.toInt(),
      String s => int.tryParse(s) ?? 0,
      _ => 0,
    };
    final buckets = (json['storage_buckets'] as Map?) ?? const {};
    return CloudUsage(
      databaseBytes: asInt(json['database_bytes']),
      storageBytes: asInt(json['storage_bytes']),
      storageBuckets: {
        for (final e in buckets.entries) e.key as String: asInt(e.value),
      },
      cloudinaryBytes: asInt(json['cloudinary_bytes']),
      cloudinaryAssets: asInt(json['cloudinary_assets']),
      measuredAt: DateTime.tryParse(json['measured_at'] as String? ?? ''),
    );
  }
}

/// Falta ejecutar la migración 012 en Supabase.
class CloudUsageUnavailable implements Exception {
  const CloudUsageUnavailable();
}

class CloudUsageService {
  CloudUsageService(this._client);

  final SupabaseClient _client;

  Future<CloudUsage> fetch() async {
    try {
      final raw = await _client.rpc('iris_storage_usage');
      return CloudUsage.fromJson(Map<String, dynamic>.from(raw as Map));
    } on PostgrestException catch (e) {
      // PGRST202: la función no existe todavía.
      if (e.code == 'PGRST202' || e.code == '42883') {
        throw const CloudUsageUnavailable();
      }
      rethrow;
    }
  }
}

final cloudUsageProvider = FutureProvider<CloudUsage?>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  if (client == null || ref.watch(signedInAccountProvider) == null) {
    return null;
  }
  return CloudUsageService(client).fetch();
});

/// 1536 → «1,5 KB»; 0 → «0 B».
String formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final text = unit == 0 || value >= 100
      ? value.round().toString()
      : value.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
  return '${text.replaceAll('.', ',')} ${units[unit]}';
}
