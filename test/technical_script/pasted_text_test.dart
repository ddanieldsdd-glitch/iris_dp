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
    // Sin líneas en blanco entre párrafos (lo que llega de Word o un PDF).
    expect(paste('', 0, 'uno\n\n\n\ndos'), 'uno\ndos');
    expect(paste('', 0, 'uno\n  \ndos\r\n\r\ntres'), 'uno\ndos\ntres');
  });

  test('pegar antes de un espacio no deja espacios dobles', () {
    expect(paste('Entra sale', 5, ' corre\n'), 'Entra corre sale');
  });

  test('en una celda sin formato las marcas de otra celda se quitan', () {
    const plain = PastedTextCleaner(plain: true);
    final out = plain.formatEditUpdate(
      value('', 0),
      value('**50mm** ==g:x==', 16),
    );
    expect(out.text, '50mm x');
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
