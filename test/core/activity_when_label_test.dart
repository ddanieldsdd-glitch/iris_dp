import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/widgets/activity/activity_providers.dart';

void main() {
  test('cuándo, en palabras', () {
    final now = DateTime(2026, 11, 22, 18, 0);
    expect(whenLabel(now, now: now), 'ahora');
    expect(
      whenLabel(now.subtract(const Duration(minutes: 5)), now: now),
      'hace 5 min',
    );
    expect(whenLabel(DateTime(2026, 11, 22, 9, 5), now: now), 'hoy 09:05');
    expect(whenLabel(DateTime(2026, 11, 21, 23, 0), now: now), 'ayer 23:00');
    expect(whenLabel(DateTime(2026, 11, 2, 7, 30), now: now), '02-11 07:30');
  });
}
