import 'dart:convert';

import '../../core/database/app_database.dart';

enum BibleLensKind { spherical, anamorphic }

/// Contexto óptico resuelto para Format / Optics.
class BibleOpticsContext {
  final BibleLensKind lensKind;
  final bool isAnamorphic;
  final double squeezeRatio;
  final String? aspectRatio;
  final Lense? primaryLens;

  const BibleOpticsContext({
    required this.lensKind,
    required this.isAnamorphic,
    required this.squeezeRatio,
    this.aspectRatio,
    this.primaryLens,
  });

  static BibleOpticsContext resolve({
    Lense? primaryLens,
    String? opticType,
    String? aspectRatio,
    Map<String, dynamic> opticsConfig = const {},
    Map<String, dynamic> formatData = const {},
    Map<String, dynamic>? activeLensSet,
  }) {
    if (activeLensSet != null && activeLensSet.isNotEmpty) {
      final isAnam = activeLensSet['isAnamorphic'] == true;
      final squeeze = (activeLensSet['squeezeRatio'] as num?)?.toDouble() ??
          (isAnam ? 2.0 : 1.0);
      return BibleOpticsContext(
        lensKind: isAnam ? BibleLensKind.anamorphic : BibleLensKind.spherical,
        isAnamorphic: isAnam,
        squeezeRatio: squeeze,
        aspectRatio: activeLensSet['aspectRatio'] as String? ?? aspectRatio,
        primaryLens: primaryLens,
      );
    }

    final lensAnam = primaryLens?.isAnamorphic == true;
    final lensSqueeze = primaryLens?.squeezeRatio;
    final configSqueeze = _parseSqueeze(
      formatData['squeezeFactor'] as String? ??
          opticsConfig['squeeze'] as String?,
    );
    final typeAnam =
        opticType?.toLowerCase().contains('anam') == true ||
        (opticsConfig['squeeze'] as String?)?.toLowerCase().contains('anam') ==
            true;

    final isAnamorphic = lensAnam ||
        (lensSqueeze != null && lensSqueeze > 1.05) ||
        (configSqueeze != null && configSqueeze > 1.05) ||
        typeAnam;

    final squeeze =
        lensSqueeze ?? configSqueeze ?? (isAnamorphic ? 2.0 : 1.0);

    return BibleOpticsContext(
      lensKind:
          isAnamorphic ? BibleLensKind.anamorphic : BibleLensKind.spherical,
      isAnamorphic: isAnamorphic,
      squeezeRatio: squeeze,
      aspectRatio: formatData['activeRatio'] as String? ?? aspectRatio,
      primaryLens: primaryLens,
    );
  }

  static List<Map<String, dynamic>> lensSetsFromJson(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return [];
      final sets = decoded['lensSets'];
      if (sets is! List) return [];
      return sets
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static double? _parseSqueeze(String? raw) {
    if (raw == null) return null;
    final m = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(raw.replaceAll(',', '.'));
    return m != null ? double.tryParse(m.group(1)!) : null;
  }
}
