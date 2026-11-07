import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';

void main() {
  test('las consultas de cada pantalla usan su índice', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();

    final indexes = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
        .get();
    final names = {for (final r in indexes) r.read<String>('name')};
    for (final (table, columns) in kQueryIndexes) {
      expect(names, contains('idx_${table}_${columns.replaceAll(', ', '_')}'));
    }

    Future<String> plan(String sql) async {
      final rows = await db.customSelect('EXPLAIN QUERY PLAN $sql').get();
      return rows.map((r) => r.read<String>('detail')).join(' | ');
    }

    expect(
      await plan(
        'SELECT * FROM shots WHERE project_id = 1 ORDER BY sort_order',
      ),
      allOf(
        contains('idx_shots_project_id_sort_order'),
        isNot(contains('TEMP')),
      ),
    );
    expect(
      await plan('SELECT * FROM shots WHERE scene_id = 1 ORDER BY sort_order'),
      contains('idx_shots_scene_id_sort_order'),
    );
  });
}
