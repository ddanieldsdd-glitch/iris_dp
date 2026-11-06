import 'dart:convert';
import 'dart:ui';

/// Sección de la planta guardada en un plano.
Rect? decodeShotPlanView(String? json) {
  if (json == null || json.isEmpty) return null;
  try {
    final map = jsonDecode(json) as Map<String, dynamic>;
    final rect = Rect.fromLTWH(
      (map['x'] as num).toDouble(),
      (map['y'] as num).toDouble(),
      (map['w'] as num).toDouble(),
      (map['h'] as num).toDouble(),
    );
    return rect.width > 0 && rect.height > 0 ? rect : null;
  } catch (_) {
    return null;
  }
}

String? encodeShotPlanView(Rect? rect) => rect == null
    ? null
    : jsonEncode({
        'x': rect.left.round(),
        'y': rect.top.round(),
        'w': rect.width.round(),
        'h': rect.height.round(),
      });
