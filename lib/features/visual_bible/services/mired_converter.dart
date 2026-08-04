/// Resultado del conversor Mired/Kelvin/gelatinas.
class GelRecommendation {
  final String gelType;
  final double strength;
  final String description;

  const GelRecommendation({
    required this.gelType,
    required this.strength,
    required this.description,
  });
}

/// Conversor integrado Mired/Kelvin para guía de gelatinas.
class MiredConverter {
  MiredConverter._();

  static double kelvinToMired(int kelvin) => 1_000_000 / kelvin;

  static int miredToKelvin(double mired) => (1_000_000 / mired).round();

  /// Calcula la gelatina CTB/CTO aproximada necesaria.
  static GelRecommendation? recommendGel({
    required int sourceKelvin,
    required int targetKelvin,
  }) {
    if (sourceKelvin == targetKelvin) return null;

    final deltaMired = kelvinToMired(sourceKelvin) - kelvinToMired(targetKelvin);
    final absDelta = deltaMired.abs();

    if (absDelta < 5) return null;

    if (deltaMired > 0) {
      // Fuente más cálida → necesita CTB (enfriar)
      final strength = (absDelta / 130).clamp(0.125, 1.0);
      final label = _strengthLabel(strength);
      return GelRecommendation(
        gelType: 'CTB',
        strength: strength,
        description: '$label CTB (${sourceKelvin}K → ${targetKelvin}K)',
      );
    } else {
      // Fuente más fría → necesita CTO (calentar)
      final strength = (absDelta / 130).clamp(0.125, 1.0);
      final label = _strengthLabel(strength);
      return GelRecommendation(
        gelType: 'CTO',
        strength: strength,
        description: '$label CTO (${sourceKelvin}K → ${targetKelvin}K)',
      );
    }
  }

  static String _strengthLabel(double strength) {
    if (strength >= 0.9) return 'Full';
    if (strength >= 0.6) return '1/2';
    if (strength >= 0.35) return '1/4';
    return '1/8';
  }

  /// Plus Green / Minus Green para balance bajo fluorescente.
  static String? recommendGreenCorrection({
    required bool hasFluorescent,
    required bool tooGreen,
  }) {
    if (!hasFluorescent) return null;
    return tooGreen ? 'Minus Green (MG)' : 'Plus Green (FG)';
  }
}
