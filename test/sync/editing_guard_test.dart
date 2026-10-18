import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/sync/editing_guard.dart';
import 'package:iris_dp/features/technical_script/table/editable_cell.dart';

void main() {
  test('soltar dos veces no descuenta dos', () {
    final a = EditingGuard.hold();
    final b = EditingGuard.hold();
    expect(EditingGuard.active.value, 2);
    a();
    a();
    expect(EditingGuard.active.value, 1);
    b();
    expect(EditingGuard.isEditing, isFalse);
  });

  testWidgets('una celda lo sujeta mientras se escribe y lo suelta al salir',
      (tester) async {
    String? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              EditableCell(
                value: '35mm',
                hint: 'Óptica',
                style: const TextStyle(fontSize: 14),
                hintStyle: const TextStyle(fontSize: 14),
                onChanged: (v) => saved = v,
              ),
              const TextField(key: Key('otro')),
            ],
          ),
        ),
      ),
    );
    expect(EditingGuard.isEditing, isFalse);

    await tester.tap(find.text('35mm'));
    await tester.pump();
    expect(EditingGuard.isEditing, isTrue);

    await tester.enterText(find.byType(TextField).first, '50mm');
    await tester.tap(find.byKey(const Key('otro')));
    await tester.pump();
    await tester.pump();
    expect(saved, '50mm');
    expect(EditingGuard.isEditing, isFalse);
  });
}
