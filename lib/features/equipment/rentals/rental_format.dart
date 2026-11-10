/// «jue 12 nov · 10:00», a partir de `yyyy-MM-ddTHH:mm`.
String formatRentalMoment(String? value) {
  if (value == null || value.isEmpty) return 'Sin fecha';
  final d = DateTime.tryParse(value);
  if (d == null) return value;
  const days = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${days[d.weekday - 1]} ${d.day} ${months[d.month - 1]} · $hh:$mm';
}

String formatRentalQuantity(double? quantity) {
  if (quantity == null) return '—';
  return quantity == quantity.roundToDouble()
      ? quantity.toInt().toString()
      : quantity.toString().replaceAll('.', ',');
}
