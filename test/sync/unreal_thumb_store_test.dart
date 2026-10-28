import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/sync/unreal_thumb_store.dart';

void main() {
  const sofa = '/Game/Fab/Sofa/SM_Sofa.SM_Sofa';

  test('la clave depende solo de la ruta del asset y de la vista', () {
    final top = UnrealThumbStore.keyFor(sofa, UnrealThumbView.top);
    final side = UnrealThumbStore.keyFor(sofa, UnrealThumbView.threeQuarter);
    expect(top, endsWith('_top'));
    expect(side, endsWith('_34'));
    expect(top.split('_').first, side.split('_').first);
    // Dos elementos con el mismo asset comparten miniatura.
    expect(UnrealThumbStore.keyFor(' $sofa ', UnrealThumbView.top), top);
    expect(
      UnrealThumbStore.keyFor('/Game/Fab/Chair/SM_Chair', UnrealThumbView.top),
      isNot(top),
    );
  });

  test('solo se aceptan claves bien formadas (el archivo sale de ella)', () {
    expect(
      UnrealThumbStore.isKey(UnrealThumbStore.keyFor(sofa, UnrealThumbView.top)),
      isTrue,
    );
    expect(UnrealThumbStore.isKey('../../etc_top'), isFalse);
    expect(UnrealThumbStore.isKey('abc_top'), isFalse);
    expect(UnrealThumbStore.fileName('0123456789abcdef0123_34'),
        '0123456789abcdef0123_34.png');
  });
}
