/// Parseo tolerante de números desde JSON (int, double o string).
int? bibleJsonInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

double? bibleJsonDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

int bibleJsonIntOr(dynamic value, int fallback) =>
    bibleJsonInt(value) ?? fallback;

double bibleJsonDoubleOr(dynamic value, double fallback) =>
    bibleJsonDouble(value) ?? fallback;
