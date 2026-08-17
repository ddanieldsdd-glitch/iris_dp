abstract final class FormatRatioFormat {
  FormatRatioFormat._();

  static const _known = <(double, String)>[
    (2.39, '2.39:1'),
    (2.40, '2.40:1'),
    (2.35, '2.35:1'),
    (1.85, '1.85:1'),
    (1.78, '1.78:1'),
    (1.66, '1.66:1'),
    (1.33, '1.33:1'),
    (1.0, '1:1'),
  ];

  static String format(double r) {
    for (final e in _known) {
      if ((r - e.$1).abs() < 0.02) return e.$2;
    }
    return '${r.toStringAsFixed(2)}:1';
  }
}
