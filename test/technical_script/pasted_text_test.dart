import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/technical_script/table/editable_cell.dart';

void main() {
  const cleaner = PastedTextCleaner();

  TextEditingValue value(String text, int cursor) => TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: cursor),
  );

  /// Pega [pasted] en [text] donde está el cursor.
  String paste(String text, int cursor, String pasted) => cleaner
      .formatEditUpdate(
        value(text, cursor),
        value(
          text.substring(0, cursor) + pasted + text.substring(cursor),
          cursor + pasted.length,
        ),
      )
      .text;

  test('lo pegado en una celda vacía entra sin espacios de más', () {
    expect(paste('', 0, '  hola \t mundo\n\n\n'), 'hola mundo');
    expect(
      paste('', 0, 'ALI entra  \r\ny se sienta '),
      'ALI entra\ny se sienta',
    );
    expect(paste('', 0, 'uno\n\n\n\ndos'), 'uno\n\ndos');
  });

  test('pegar en mitad de una frase no pega las palabras entre sí', () {
    expect(paste('Entra sale', 6, ' corre  y '), 'Entra corre y sale');
    expect(paste('Entra sale', 6, 'corre\n'), 'Entra corre sale');
    expect(paste('Entra', 5, ' y corre  '), 'Entra y corre');
  });

  test('lo que se teclea no se toca', () {
    expect(paste('hola', 4, ' '), 'hola ');
    expect(paste('hola ', 5, ' '), 'hola  ');
    expect(paste('hola', 4, '\n'), 'hola\n');
  });
}
