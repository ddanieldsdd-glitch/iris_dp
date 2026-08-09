import 'dart:convert';

import 'format_sensor_mode_resolve.dart';

/// Cascada mínima cámara → modo Format: re-resuelve `sensorModeName` si
/// el nombre guardado no existe en `sensorModesJson` de la nueva A-CAM.
abstract final class SensorModeCascade {
  SensorModeCascade._();

  /// Devuelve el patch de blob si hay que cambiar el modo; `null` si ya es válido
  /// o no hay modos de catálogo (deja el blob intacto).
  static Map<String, dynamic>? reconcileFormatBlob({
    required Map<String, dynamic> formatBlob,
    required String? sensorModesJson,
    double? fallbackWidthMm,
    double? fallbackHeightMm,
  }) {
    final modes = _parseModes(sensorModesJson);
    if (modes.isEmpty) {
      // Sin catálogo PHFX: no inventamos modo; Format puede seguir con texto libre.
      return null;
    }

    final current = FormatSensorModeResolve.modeName(formatBlob);
    _ModePick? pick;
    if (current != null) {
      for (final m in modes) {
        if (m.name == current) {
          pick = m;
          break;
        }
      }
    }
    pick ??= modes.first;

    // Mismo nombre y dims ya coherentes → no reescribir.
    if (current == pick.name) {
      final detail = formatBlob[FormatSensorModeResolve.detailKey]?.toString();
      if (detail != null && detail.isNotEmpty) return null;
    }

    return FormatSensorModeResolve.blobUpdateForMode(
      name: pick.name,
      widthPx: pick.widthPx,
      heightPx: pick.heightPx,
      widthMm: pick.widthMm ?? fallbackWidthMm,
      heightMm: pick.heightMm ?? fallbackHeightMm,
    );
  }

  static List<_ModePick> _parseModes(String? jsonStr) {
    if (jsonStr == null || jsonStr.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! List) return const [];
      final out = <_ModePick>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final name = map['name']?.toString().trim();
        if (name == null || name.isEmpty) continue;
        out.add(
          _ModePick(
            name: name,
            widthMm: (map['widthMm'] as num?)?.toDouble(),
            heightMm: (map['heightMm'] as num?)?.toDouble(),
            widthPx: (map['maxWidthPx'] as num?)?.toInt(),
            heightPx: (map['maxHeightPx'] as num?)?.toInt(),
          ),
        );
      }
      return out;
    } catch (_) {
      return const [];
    }
  }
}

class _ModePick {
  final String name;
  final double? widthMm;
  final double? heightMm;
  final int? widthPx;
  final int? heightPx;

  const _ModePick({
    required this.name,
    this.widthMm,
    this.heightMm,
    this.widthPx,
    this.heightPx,
  });
}
