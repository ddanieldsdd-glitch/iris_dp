import '../../core/database/app_database.dart';

/// Utilidades para agrupar ópticas en sets (p. ej. Master Prime, S4/i).
class LensSetUtils {
  LensSetUtils._();

  /// Clave única de set dentro del catálogo.
  static String setKey(Lense lens) => '${lens.brand}|${setName(lens)}';

  /// Nombre del set: serie explícita o inferida del modelo.
  static String setName(Lense lens) {
    final series = lens.series?.trim();
    if (series != null && series.isNotEmpty) return series;
    return _inferSetFromModel(lens.model);
  }

  static String _inferSetFromModel(String model) {
    var name = model.trim();
    // Zoom: "Premista 28-100mm T2.9" → Premista
    final zoom = RegExp(r'^(.+?)\s+\d+[\-–]\d+mm', caseSensitive: false);
    final zoomMatch = zoom.firstMatch(name);
    if (zoomMatch != null) return zoomMatch.group(1)!.trim();

    // Prime: "Master Prime 12mm" → Master Prime
    final prime = RegExp(r'^(.+?)\s+\d+(\.\d+)?mm', caseSensitive: false);
    final primeMatch = prime.firstMatch(name);
    if (primeMatch != null) {
      final base = primeMatch.group(1)!.trim();
      if (base.length >= 3) return base;
    }

    // Quitar sufijos T-stop
    name = name.replaceAll(RegExp(r'\s+T[\d.]+.*$'), '').trim();
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0]} ${parts[1]}';
    return name.isEmpty ? 'General' : name;
  }

  static int _focalSortKey(Lense l) {
    if (l.focalLength > 0) return l.focalLength.round();
    if (l.focalMin != null) return l.focalMin!.round();
    return 9999;
  }

  static List<Lense> sortByFocal(Iterable<Lense> lenses) {
    final list = lenses.toList();
    list.sort((a, b) {
      final fc = _focalSortKey(a).compareTo(_focalSortKey(b));
      if (fc != 0) return fc;
      return a.model.compareTo(b.model);
    });
    return list;
  }

  static String focalLabel(Lense l) {
    if (l.focalLength > 0) return '${l.focalLength.toStringAsFixed(0)} mm';
    if (l.focalMin != null && l.focalMax != null) {
      return '${l.focalMin!.toStringAsFixed(0)}–${l.focalMax!.toStringAsFixed(0)} mm';
    }
    return l.model;
  }

  /// Resumen compacto del set para fila colapsable.
  static String setSummary(List<Lense> lenses) {
    if (lenses.isEmpty) return '';
    final sorted = sortByFocal(lenses);
    final parts = <String>[];

    final primes = sorted.where((l) => l.focalLength > 0).toList();
    final zooms = sorted.where((l) => l.focalLength <= 0 && l.focalMin != null).toList();

    if (primes.isNotEmpty) {
      final minF = primes.first.focalLength;
      final maxF = primes.last.focalLength;
      parts.add(minF == maxF
          ? '${minF.toStringAsFixed(0)} mm'
          : '${minF.toStringAsFixed(0)}–${maxF.toStringAsFixed(0)} mm');
    }
    if (zooms.isNotEmpty) {
      parts.addAll(zooms.map(focalLabel));
    }

    final tStops = sorted.map((l) => l.minTStop).toSet();
    if (tStops.length == 1) {
      parts.add('T${tStops.first.toStringAsFixed(1)}');
    } else if (tStops.isNotEmpty) {
      final minT = tStops.reduce((a, b) => a < b ? a : b);
      parts.add('T${minT.toStringAsFixed(1)}+');
    }

    final coverages = sorted.map((l) => l.formatCoverage).toSet();
    if (coverages.length == 1) {
      parts.add(coverages.first);
    }

    if (sorted.any((l) => l.isAnamorphic)) {
      final sq = sorted
          .where((l) => l.isAnamorphic && l.squeezeRatio != null)
          .map((l) => l.squeezeRatio!)
          .toSet();
      if (sq.length == 1) parts.add('${sq.first}x anam');
    }

    parts.add('${sorted.length} lentes');
    return parts.join(' · ');
  }

  static Map<String, List<Lense>> groupBySet(List<Lense> lenses) {
    final map = <String, List<Lense>>{};
    for (final l in lenses) {
      map.putIfAbsent(setKey(l), () => []).add(l);
    }
    for (final entry in map.entries) {
      entry.value.sort((a, b) {
        final fc = _focalSortKey(a).compareTo(_focalSortKey(b));
        if (fc != 0) return fc;
        return a.model.compareTo(b.model);
      });
    }
    return map;
  }

  static Map<String, Map<String, List<Lense>>> groupByBrandAndSet(
    List<Lense> lenses,
  ) {
    final byBrand = <String, Map<String, List<Lense>>>{};
    for (final l in lenses) {
      final brand = l.brand;
      final set = setName(l);
      byBrand.putIfAbsent(brand, () => {});
      byBrand[brand]!.putIfAbsent(set, () => []).add(l);
    }
    for (final sets in byBrand.values) {
      for (final entry in sets.entries) {
        entry.value.sort((a, b) {
          final fc = _focalSortKey(a).compareTo(_focalSortKey(b));
          if (fc != 0) return fc;
          return a.model.compareTo(b.model);
        });
      }
    }
    return byBrand;
  }
}
